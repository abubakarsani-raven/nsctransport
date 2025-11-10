import { Injectable, ForbiddenException, BadRequestException } from '@nestjs/common';
import { UsersService } from '../users/users.service';
import { UserRole } from '../users/schemas/user.schema';
import {
  VEHICLE_REQUEST_WORKFLOW,
  VehicleRequestStage,
  getWorkflowStage,
  getInitialStage,
  isTerminalStage,
} from './workflow-definition';
import { WorkflowAction } from './schemas/workflow-actions.enum';
import { WorkflowTransitionService } from './workflow-transition.service';
import { VehicleRequestDocument } from '../requests/vehicle/schemas/vehicle-request.schema';

@Injectable()
export class WorkflowService {
  constructor(
    private transitionService: WorkflowTransitionService,
    private usersService: UsersService,
  ) {}

  /**
   * Get current workflow stage from request
   */
  getCurrentStage(request: VehicleRequestDocument): string {
    // If request has currentStage, use it
    if ((request as any).currentStage) {
      return (request as any).currentStage;
    }

    // Fallback: derive from status for backward compatibility
    return this.mapStatusToStage(request.status);
  }

  /**
   * Map old status to new workflow stage (for backward compatibility)
   */
  private mapStatusToStage(status: string): string {
    const statusMap: Record<string, string> = {
      pending: VehicleRequestStage.SUPERVISOR_REVIEW, // Pending means waiting for supervisor
      submitted: VehicleRequestStage.SUPERVISOR_REVIEW, // Submitted also means supervisor review
      supervisor_approved: VehicleRequestStage.DGS_REVIEW, // Supervisor approved means now at DGS review
      dgs_approved: VehicleRequestStage.DDGS_REVIEW, // DGS approved means now at DDGS review
      ddgs_approved: VehicleRequestStage.AD_TRANSPORT_REVIEW, // DDGS approved means now at AD Transport review
      ad_transport_approved: VehicleRequestStage.TRANSPORT_OFFICER_ASSIGNMENT, // AD Transport approved means now at TO assignment
      transport_officer_assigned: VehicleRequestStage.ASSIGNED,
      driver_accepted: VehicleRequestStage.ASSIGNED,
      in_progress: VehicleRequestStage.IN_PROGRESS,
      completed: VehicleRequestStage.COMPLETED,
      returned: VehicleRequestStage.RETURNED,
      rejected: VehicleRequestStage.REJECTED,
      needs_correction: VehicleRequestStage.NEEDS_CORRECTION,
      cancelled: VehicleRequestStage.CANCELLED,
    };

    return statusMap[status.toLowerCase()] || VehicleRequestStage.SUPERVISOR_REVIEW;
  }

  /**
   * Check if user can perform action on request
   */
  async canPerformAction(
    user: any,
    request: VehicleRequestDocument,
    action: WorkflowAction,
  ): Promise<boolean> {
    const currentStage = this.getCurrentStage(request);

    // Check if action is allowed at current stage
    if (!this.transitionService.canPerformAction(currentStage, action)) {
      return false;
    }

    const workflowStage = getWorkflowStage(currentStage);
    if (!workflowStage) {
      return false;
    }

    const stageActions = workflowStage.actions;

    // Check role requirements
    if (stageActions.requiredRole) {
      const requiredRoles = Array.isArray(stageActions.requiredRole)
        ? stageActions.requiredRole
        : [stageActions.requiredRole];

      const userRoles = user.roles && user.roles.length > 0 
        ? user.roles 
        : [UserRole.STAFF];

      // Special handling for SUBMITTED stage
      if (currentStage === VehicleRequestStage.SUBMITTED) {
        // Check if user is supervisor or has DGS role
        const isSupervisor = user.isSupervisor === true;
        const hasDGSRole = userRoles.includes(UserRole.DGS);
        
        if (requiredRoles.includes('supervisor')) {
          // If action requires supervisor, check if user is the assigned supervisor
          if (isSupervisor && stageActions.requiresSupervisorMatch) {
            return this.isAssignedSupervisor(user, request);
          }
          return isSupervisor || hasDGSRole;
        }
        
        if (requiredRoles.includes(UserRole.DGS)) {
          return hasDGSRole || isSupervisor;
        }
      }

      // Special handling for SUPERVISOR_REVIEW stage
      if (currentStage === VehicleRequestStage.SUPERVISOR_REVIEW) {
        const isSupervisor = user.isSupervisor === true;
        const hasDGSRole = userRoles.includes(UserRole.DGS);
        
        // Check if role requirement includes supervisor or DGS
        if (requiredRoles.includes('supervisor') || requiredRoles.includes(UserRole.DGS)) {
          // If supervisor match is required, verify the user is the assigned supervisor
          if (stageActions.requiresSupervisorMatch && isSupervisor) {
            return this.isAssignedSupervisor(user, request);
          }
          // Otherwise, any supervisor or DGS can approve
          return isSupervisor || hasDGSRole;
        }
      }

      // Special handling for DGS_REVIEW stage
      if (currentStage === VehicleRequestStage.DGS_REVIEW) {
        const hasDGSRole = userRoles.includes(UserRole.DGS);
        
        // Only DGS can approve at DGS_REVIEW stage
        if (requiredRoles.includes(UserRole.DGS)) {
          return hasDGSRole;
        }
      }
      
      // For other stages, check role match
      const hasRequiredRole = requiredRoles.some((role) => {
        if (role === 'supervisor') {
          return user.isSupervisor === true;
        }
        return userRoles.includes(role as UserRole);
      });

      if (!hasRequiredRole) {
        return false;
      }
    }

    // Check supervisor match requirement
    if (stageActions.requiresSupervisorMatch) {
      return this.isAssignedSupervisor(user, request);
    }

    // Special checks for specific actions
    if (action === WorkflowAction.CANCEL) {
      // Only requester can cancel (and only at certain stages)
      return this.canCancel(request, user);
    }

    if (action === WorkflowAction.RESUBMIT) {
      // Only requester can resubmit
      return this.isRequester(user, request);
    }

    if (action === WorkflowAction.ASSIGN) {
      // Transport officer and DGS can assign
      const userRoles = user.roles && user.roles.length > 0 
        ? user.roles 
        : [];
      return userRoles.includes(UserRole.TRANSPORT_OFFICER) || 
             userRoles.includes(UserRole.DGS);
    }

    if (action === WorkflowAction.ACCEPT) {
      // Only assigned driver can accept
      return this.isAssignedDriver(user, request);
    }

    return true;
  }

  /**
   * Get available actions for user on request
   */
  async getAvailableActions(
    user: any,
    request: VehicleRequestDocument,
  ): Promise<WorkflowAction[]> {
    const currentStage = this.getCurrentStage(request);
    const workflowStage = getWorkflowStage(currentStage);

    if (!workflowStage) {
      return [];
    }

    const availableActions: WorkflowAction[] = [];

    for (const action of workflowStage.actions.allowedActions) {
      if (await this.canPerformAction(user, request, action)) {
        availableActions.push(action);
      }
    }

    return availableActions;
  }

  /**
   * Get next stage for action
   */
  async getNextStage(
    request: VehicleRequestDocument,
    action: WorkflowAction,
    user?: any,
  ): Promise<string | null> {
    const currentStage = this.getCurrentStage(request);

    // Get requester info for context (not the approver, but the original requester)
    const context: any = {};
    
    // Get the actual requester from the request
    const requesterId = this.extractId(request.requesterId);
    if (requesterId) {
      try {
        const requester = await this.usersService.findById(requesterId);
        if (requester) {
          context.requesterIsSupervisor = requester.isSupervisor === true;
        }
      } catch (error) {
        // If requester lookup fails, try to get from populated field
        const requester = request.requesterId as any;
        if (requester && typeof requester === 'object' && requester.isSupervisor !== undefined) {
          context.requesterIsSupervisor = requester.isSupervisor === true;
        }
      }
    }

    return this.transitionService.getNextStage(currentStage, action, context);
  }

  /**
   * Check if user can send back request for correction
   */
  async canSendBack(user: any, request: VehicleRequestDocument): Promise<boolean> {
    return this.canPerformAction(user, request, WorkflowAction.SEND_BACK);
  }

  /**
   * Check if user can cancel request
   */
  async canCancel(request: VehicleRequestDocument, user: any): Promise<boolean> {
    // Only requester can cancel
    if (!this.isRequester(user, request)) {
      return false;
    }

    const currentStage = this.getCurrentStage(request);

    // Can cancel at these stages
    const cancellableStages = [
      VehicleRequestStage.SUBMITTED,
      VehicleRequestStage.SUPERVISOR_REVIEW,
      VehicleRequestStage.DGS_REVIEW,
      VehicleRequestStage.DDGS_REVIEW,
      VehicleRequestStage.AD_TRANSPORT_REVIEW,
    ];

    return cancellableStages.includes(currentStage as VehicleRequestStage);
  }

  /**
   * Execute workflow transition
   */
  async executeTransition(
    request: VehicleRequestDocument,
    user: any,
    action: WorkflowAction,
    metadata?: any,
  ): Promise<{
    nextStage: string;
    transitionContext: any;
  }> {
    const currentStage = this.getCurrentStage(request);

    // Validate permission
    if (!(await this.canPerformAction(user, request, action))) {
      throw new ForbiddenException(
        `You do not have permission to perform action ${action} at stage ${currentStage}`,
      );
    }

    // Get next stage
    const nextStage = await this.getNextStage(request, action, user);

    if (!nextStage) {
      throw new BadRequestException(
        `No valid transition from ${currentStage} with action ${action}`,
      );
    }

    // Validate transition
    this.transitionService.validateTransition(currentStage, nextStage, action);

    return {
      nextStage,
      transitionContext: {
        fromStage: currentStage,
        toStage: nextStage,
        action,
        performedBy: (user._id as any).toString(),
        performedAt: new Date(),
        ...metadata,
      },
    };
  }

  /**
   * Helper: Check if user is the requester
   */
  private isRequester(user: any, request: VehicleRequestDocument): boolean {
    const requesterId = this.extractId(request.requesterId);
    const userId = (user._id as any).toString();
    return requesterId === userId;
  }

  /**
   * Helper: Check if user is the assigned supervisor
   */
  private isAssignedSupervisor(user: any, request: VehicleRequestDocument): boolean {
    if (!request.supervisorId) {
      return false;
    }

    const supervisorId = this.extractId(request.supervisorId);
    const userId = (user._id as any).toString();
    return supervisorId === userId;
  }

  /**
   * Helper: Check if user is the assigned driver
   */
  private isAssignedDriver(user: any, request: VehicleRequestDocument): boolean {
    if (!request.assignedDriverId) {
      return false;
    }

    const driverId = this.extractId(request.assignedDriverId);
    const userId = (user._id as any).toString();
    return driverId === userId;
  }

  /**
   * Helper: Extract ID from populated or non-populated reference
   */
  private extractId(ref: any): string {
    if (typeof ref === 'object' && ref !== null && !(ref instanceof Date)) {
      return ref._id?.toString() || ref.id?.toString() || String(ref);
    }
    return String(ref);
  }

  /**
   * Get workflow stage configuration
   */
  getStageConfig(stageId: string) {
    return getWorkflowStage(stageId);
  }

  /**
   * Get all workflow stages
   */
  getAllStages() {
    return VEHICLE_REQUEST_WORKFLOW;
  }

  /**
   * Check if stage is terminal
   */
  isTerminal(stageId: string): boolean {
    return isTerminalStage(stageId);
  }
}

