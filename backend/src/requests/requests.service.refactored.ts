import { Injectable, NotFoundException, BadRequestException, ForbiddenException } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model } from 'mongoose';
import { VehicleRequest, VehicleRequestDocument, RequestStatus } from './vehicle/schemas/vehicle-request.schema';
import { CorrectionHistory } from './vehicle/schemas/correction-history.schema';
import { CreateRequestDto } from './vehicle/dto/create-request.dto';
import { UpdateRequestDto } from './vehicle/dto/update-request.dto';
import { ApproveRequestDto } from './vehicle/dto/approve-request.dto';
import { RejectRequestDto } from './vehicle/dto/reject-request.dto';
import { SendBackForCorrectionDto } from './vehicle/dto/send-back-for-correction.dto';
import { UsersService } from '../users/users.service';
import { UserRole } from '../users/schemas/user.schema';
import { NotificationsService } from '../notifications/notifications.service';
import { NotificationType } from '../notifications/schemas/notification.schema';
import { MapsService } from '../maps/maps.service';
import { OfficesService } from '../offices/offices.service';
import { EventEmitter2 } from '@nestjs/event-emitter';
import { HistoryUpdatedEvent, RequestUpdatedEvent } from '../events/events';
import { WorkflowService } from '../workflow/workflow.service';
import { WorkflowAction } from '../workflow/schemas/workflow-actions.enum';
import { VehicleRequestStage } from '../workflow/workflow-definition';

@Injectable()
export class RequestsService {
  constructor(
    @InjectModel(VehicleRequest.name) private requestModel: Model<VehicleRequestDocument>,
    private usersService: UsersService,
    private notificationsService: NotificationsService,
    private mapsService: MapsService,
    private officesService: OfficesService,
    private eventEmitter: EventEmitter2,
    private workflowService: WorkflowService,
  ) {}

  /**
   * Map workflow stage to status for backward compatibility
   */
  private mapStageToStatus(stage: string): RequestStatus {
    const stageMap: Record<string, RequestStatus> = {
      [VehicleRequestStage.SUBMITTED]: RequestStatus.PENDING,
      [VehicleRequestStage.SUPERVISOR_REVIEW]: RequestStatus.SUPERVISOR_APPROVED,
      [VehicleRequestStage.DGS_REVIEW]: RequestStatus.DGS_APPROVED,
      [VehicleRequestStage.DDGS_REVIEW]: RequestStatus.DDGS_APPROVED,
      [VehicleRequestStage.AD_TRANSPORT_REVIEW]: RequestStatus.AD_TRANSPORT_APPROVED,
      [VehicleRequestStage.TRANSPORT_OFFICER_ASSIGNMENT]: RequestStatus.AD_TRANSPORT_APPROVED,
      [VehicleRequestStage.ASSIGNED]: RequestStatus.TRANSPORT_OFFICER_ASSIGNED,
      [VehicleRequestStage.IN_PROGRESS]: RequestStatus.IN_PROGRESS,
      [VehicleRequestStage.COMPLETED]: RequestStatus.COMPLETED,
      [VehicleRequestStage.RETURNED]: RequestStatus.RETURNED,
      [VehicleRequestStage.REJECTED]: RequestStatus.REJECTED,
      [VehicleRequestStage.NEEDS_CORRECTION]: RequestStatus.NEEDS_CORRECTION,
      [VehicleRequestStage.CANCELLED]: RequestStatus.CANCELLED,
    };
    return stageMap[stage] || RequestStatus.PENDING;
  }

  /**
   * Helper to extract ID from populated or non-populated reference
   */
  private extractId(ref: any): string {
    if (ref === undefined || ref === null) {
      return '';
    }
    if (typeof ref === 'object' && ref !== null && !(ref instanceof Date)) {
      return ref._id?.toString() || ref.id?.toString() || String(ref);
    }
    return String(ref);
  }

  /**
   * Add action to action history
   */
  private addActionHistory(
    request: VehicleRequestDocument,
    action: WorkflowAction,
    performedBy: string,
    stage: string,
    notes?: string,
    metadata?: any,
  ): void {
    request.actionHistory.push({
      action,
      performedBy,
      performedAt: new Date(),
      stage,
      notes,
      metadata,
    } as any);

    // Also add to approval chain for backward compatibility
    request.approvalChain.push({
      approverId: performedBy,
      status: stage,
      timestamp: new Date(),
      comments: notes,
    } as any);

    if ((request as any)._id) {
      this.eventEmitter.emit(
        'history.updated',
        new HistoryUpdatedEvent(((request as any)._id).toString()),
      );
    }
  }

  async create(createRequestDto: CreateRequestDto, requesterId: string): Promise<VehicleRequestDocument> {
    // Validate dates
    const startDate = new Date(createRequestDto.startDate);
    const endDate = new Date(createRequestDto.endDate);
    const now = new Date();
    const oneHourFromNow = new Date(now.getTime() + 60 * 60 * 1000);

    if (startDate < oneHourFromNow) {
      throw new BadRequestException('Start date must be at least 1 hour in the future');
    }

    if (endDate <= startDate) {
      throw new BadRequestException('End date must be after start date');
    }

    // Get origin office coordinates
    const originOffice = await this.officesService.findById(createRequestDto.originOffice);
    if (!originOffice) {
      throw new NotFoundException('Origin office not found');
    }

    // Calculate estimated distance if destination coordinates are provided
    let estimatedDistance: number | undefined;
    if (createRequestDto.destinationCoordinates) {
      try {
        const distanceResult = await this.mapsService.calculateDistance(
          originOffice.coordinates,
          createRequestDto.destinationCoordinates,
        );
        estimatedDistance = distanceResult.distance;
      } catch (error) {
        console.error('Failed to calculate distance:', error);
      }
    }

    // Get requester info
    const requester = await this.usersService.findById(requesterId);
    if (!requester) {
      throw new NotFoundException('Requester not found');
    }

    // Get requester roles (default to STAFF if empty)
    const requesterRoles = requester.roles && requester.roles.length > 0 
      ? requester.roles 
      : [UserRole.STAFF];
    
    // Check if requester has STAFF role
    if (!requesterRoles.includes(UserRole.STAFF)) {
      throw new BadRequestException('Only staff members can create requests');
    }

    // Determine supervisorId to store
    let supervisorIdToStore: string | undefined;
    if (!requester.isSupervisor) {
      supervisorIdToStore = createRequestDto.supervisorId || requester.supervisorId;
      if (!supervisorIdToStore) {
        throw new BadRequestException('Supervisor must be selected or assigned for non-supervisor staff members');
      }
      
      // Validate supervisor
      const supervisor = await this.usersService.findById(supervisorIdToStore);
      if (!supervisor) {
        throw new NotFoundException('Selected supervisor not found');
      }
      if (supervisor.department !== requester.department) {
        throw new BadRequestException('Selected supervisor must be from the same department');
      }
      if (!supervisor.isSupervisor) {
        throw new BadRequestException('Selected user is not a supervisor');
      }
    }

    // Build request object with workflow stage
    const requestData: any = {
      originOffice: createRequestDto.originOffice,
      destination: createRequestDto.destination,
      startDate,
      endDate,
      purpose: createRequestDto.purpose,
      passengerCount: createRequestDto.passengerCount,
      requesterId,
      currentStage: VehicleRequestStage.SUBMITTED,
      status: RequestStatus.PENDING,
      estimatedDistance,
      actionHistory: [],
      correctionHistory: [],
      approvalChain: [],
    };

    if (createRequestDto.destinationCoordinates) {
      requestData.destinationCoordinates = createRequestDto.destinationCoordinates;
    }

    if (supervisorIdToStore) {
      requestData.supervisorId = supervisorIdToStore;
    }

    const request = new this.requestModel(requestData);
    const savedRequest = await request.save();

    // Add creation action to history
    this.addActionHistory(
      savedRequest,
      WorkflowAction.APPROVE, // Creation is implicit approval to start workflow
      requesterId,
      VehicleRequestStage.SUBMITTED,
      'Request created',
    );

    // Determine next approver based on requester role
    let nextApprover: any = null;
    if (!requester.isSupervisor) {
      nextApprover = await this.usersService.findById(supervisorIdToStore!);
    } else {
      // Supervisor: goes directly to DGS
      const allUsers = await this.usersService.findAll();
      const dgsUsers = allUsers.filter(u => {
        const roles = u.roles && u.roles.length > 0 ? u.roles : [UserRole.STAFF];
        return roles.includes(UserRole.DGS);
      });
      nextApprover = dgsUsers[0];
    }

    // Send notification to next approver
    if (nextApprover) {
      await this.notificationsService.sendNotification(
        (nextApprover._id as any).toString(),
        NotificationType.REQUEST_CREATED,
        'New Vehicle Request',
        `A new vehicle request has been submitted by ${requester.name}`,
        (savedRequest._id as any).toString(),
      );
    }

    await savedRequest.save();
    this.eventEmitter.emit('request.updated', new RequestUpdatedEvent());

    return savedRequest;
  }

  async findAll(user: any): Promise<VehicleRequestDocument[]> {
    const userRoles = user.roles && user.roles.length > 0 
      ? user.roles 
      : [UserRole.STAFF];
    
    const isSupervisor = user.isSupervisor === true;
    let query: any = {};
    const stages: string[] = [];

    // Get stages user can act on based on roles
    for (const role of userRoles) {
      const roleStages = this.getStagesForRole(role, isSupervisor);
      stages.push(...roleStages);
    }

    // If user has STAFF role, include their own requests
    if (userRoles.includes(UserRole.STAFF)) {
      const uniqueStages = [...new Set(stages)];
      const queryConditions: any[] = [{ requesterId: user._id }];
      
      if (isSupervisor) {
        queryConditions.push({ 
          supervisorId: user._id, 
          currentStage: VehicleRequestStage.SUBMITTED,
        });
      }
      
      if (uniqueStages.length > 0) {
        queryConditions.push({ currentStage: { $in: uniqueStages } });
      }
      
      if (queryConditions.length > 1) {
        query.$or = queryConditions;
      } else {
        query = queryConditions[0];
      }
    } else {
      const uniqueStages = [...new Set(stages)];
      if (uniqueStages.length > 0) {
        query.currentStage = { $in: uniqueStages };
      }
    }

    return this.requestModel
      .find(query)
      .populate('requesterId', 'name email phone department')
      .populate('supervisorId', 'name email role')
      .populate('assignedDriverId', 'name email phone employeeId')
      .populate('assignedVehicleId', 'plateNumber make model capacity')
      .populate('pickupOffice', 'name address coordinates')
      .populate('actionHistory.performedBy', 'name email role')
      .populate('correctionHistory.requestedBy', 'name email')
      .populate('approvalChain.approverId', 'name email role')
      .populate('rejectedBy', 'name email')
      .populate('correctedBy', 'name email')
      .populate('cancelledBy', 'name email')
      .sort({ createdAt: -1 })
      .exec();
  }

  /**
   * Get stages a role can act on
   */
  private getStagesForRole(role: UserRole, isSupervisor: boolean): string[] {
    const stages: string[] = [];
    
    switch (role) {
      case UserRole.DGS:
        stages.push(
          VehicleRequestStage.SUBMITTED,
          VehicleRequestStage.SUPERVISOR_REVIEW,
          VehicleRequestStage.DGS_REVIEW,
        );
        break;
      case UserRole.DDGS:
        stages.push(VehicleRequestStage.DDGS_REVIEW);
        break;
      case UserRole.AD_TRANSPORT:
        stages.push(VehicleRequestStage.AD_TRANSPORT_REVIEW);
        break;
      case UserRole.TRANSPORT_OFFICER:
        stages.push(VehicleRequestStage.TRANSPORT_OFFICER_ASSIGNMENT);
        break;
      case UserRole.DRIVER:
        stages.push(VehicleRequestStage.ASSIGNED, VehicleRequestStage.IN_PROGRESS);
        break;
    }
    
    return stages;
  }

  async findById(id: string): Promise<VehicleRequestDocument> {
    const request = await this.requestModel
      .findById(id)
      .populate('requesterId', 'name email phone department')
      .populate('supervisorId', 'name email role')
      .populate('assignedDriverId', 'name email phone employeeId')
      .populate('assignedVehicleId', 'plateNumber make model capacity')
      .populate('pickupOffice', 'name address coordinates')
      .populate('actionHistory.performedBy', 'name email role')
      .populate('correctionHistory.requestedBy', 'name email')
      .populate('approvalChain.approverId', 'name email role')
      .populate('rejectedBy', 'name email')
      .populate('correctedBy', 'name email')
      .populate('cancelledBy', 'name email')
      .exec();
    if (!request) {
      throw new NotFoundException('Request not found');
    }
    return request;
  }

  async update(id: string, requesterId: string, updateDto: UpdateRequestDto): Promise<VehicleRequestDocument> {
    const request = await this.findById(id);

    const requestRequesterId = this.extractId(request.requesterId);
    const requesterIdStr = String(requesterId);

    if (requestRequesterId !== requesterIdStr) {
      throw new ForbiddenException('You can only update your own requests');
    }

    const currentStage = this.workflowService.getCurrentStage(request);
    
    // Only allow updates when needs correction or rejected
    if (currentStage !== VehicleRequestStage.NEEDS_CORRECTION && 
        currentStage !== VehicleRequestStage.REJECTED) {
      throw new BadRequestException('Request can only be updated when it needs correction or has been rejected');
    }

    // Update provided fields
    if (updateDto.originOffice !== undefined) {
      request.originOffice = updateDto.originOffice;
    }
    if (updateDto.destination !== undefined) {
      request.destination = updateDto.destination;
    }
    if (updateDto.destinationCoordinates !== undefined) {
      request.destinationCoordinates = updateDto.destinationCoordinates;
    }
    if (updateDto.startDate !== undefined) {
      request.startDate = new Date(updateDto.startDate);
    }
    if (updateDto.endDate !== undefined) {
      request.endDate = new Date(updateDto.endDate);
    }
    if (updateDto.purpose !== undefined) {
      request.purpose = updateDto.purpose;
    }
    if (updateDto.passengerCount !== undefined) {
      request.passengerCount = updateDto.passengerCount;
    }
    if (updateDto.supervisorId !== undefined) {
      if (updateDto.supervisorId) {
        const supervisor = await this.usersService.findById(updateDto.supervisorId);
        if (!supervisor) {
          throw new NotFoundException('Supervisor not found');
        }
        if (!supervisor.isSupervisor) {
          throw new BadRequestException('Selected user is not a supervisor');
        }
        const requester = await this.usersService.findById(requesterId);
        if (requester && supervisor.department !== requester.department) {
          throw new BadRequestException('Selected supervisor must be from the same department');
        }
      }
      request.supervisorId = updateDto.supervisorId || undefined;
    }

    // Recalculate distance if destination changed
    if (updateDto.destination !== undefined && updateDto.destinationCoordinates) {
      try {
        const originOfficeId = updateDto.originOffice !== undefined 
          ? updateDto.originOffice 
          : request.originOffice.toString();
        const originOffice = await this.officesService.findById(originOfficeId);
        if (originOffice && originOffice.coordinates) {
          const distanceResult = await this.mapsService.calculateDistance(
            originOffice.coordinates,
            updateDto.destinationCoordinates,
          );
          request.estimatedDistance = distanceResult.distance;
        }
      } catch (error) {
        console.error('[RequestsService] Error calculating distance:', error);
      }
    }

    const updatedRequest = await request.save();

    await updatedRequest.populate('requesterId', 'name email phone department');
    await updatedRequest.populate('supervisorId', 'name email role');
    await updatedRequest.populate('assignedDriverId', 'name email phone employeeId');
    await updatedRequest.populate('assignedVehicleId', 'plateNumber make model capacity');
    await updatedRequest.populate('pickupOffice', 'name address coordinates');
    await updatedRequest.populate('actionHistory.performedBy', 'name email role');
    await updatedRequest.populate('correctionHistory.requestedBy', 'name email');
    await updatedRequest.populate('approvalChain.approverId', 'name email role');
    await updatedRequest.populate('rejectedBy', 'name email');
    await updatedRequest.populate('correctedBy', 'name email');
    await updatedRequest.populate('cancelledBy', 'name email');

    this.eventEmitter.emit('request.updated', new RequestUpdatedEvent());

    return updatedRequest;
  }

  async approve(id: string, approverId: string, approveDto: ApproveRequestDto): Promise<VehicleRequestDocument> {
    const request = await this.findById(id);
    const approver = await this.usersService.findById(approverId);
    if (!approver) {
      throw new NotFoundException('Approver not found');
    }

    const currentStage = this.workflowService.getCurrentStage(request);

    // Cannot approve if needs correction
    if (currentStage === VehicleRequestStage.NEEDS_CORRECTION) {
      throw new BadRequestException('Request needs correction and must be resubmitted first');
    }

    // Execute workflow transition
    const { nextStage, transitionContext } = await this.workflowService.executeTransition(
      request,
      approver,
      WorkflowAction.APPROVE,
      { comments: approveDto.comments },
    );

    // Update request stage and status
    request.currentStage = nextStage;
    request.status = this.mapStageToStatus(nextStage);

    // Add to action history
    this.addActionHistory(
      request,
      WorkflowAction.APPROVE,
      (approver._id as any).toString(),
      currentStage,
      approveDto.comments,
    );

    // Mark arrays as modified
    request.markModified('actionHistory');
    request.markModified('approvalChain');

    const updatedRequest = await request.save();

    // Get requester for notification
    const requester = await this.usersService.findById(this.extractId(request.requesterId));

    // Notify requester
    if (requester) {
      await this.notificationsService.sendNotification(
        (requester._id as any).toString(),
        NotificationType.REQUEST_APPROVED,
        'Request Approved',
        `Your vehicle request has been approved by ${approver.name}`,
        (updatedRequest._id as any).toString(),
      );
    }

    // Notify next approver if not final stage
    if (!this.workflowService.isTerminal(nextStage) && nextStage !== VehicleRequestStage.TRANSPORT_OFFICER_ASSIGNMENT) {
      const nextApprover = await this.getNextApproverForStage(nextStage);
      if (nextApprover) {
        await this.notificationsService.sendNotification(
          (nextApprover._id as any).toString(),
          NotificationType.REQUEST_CREATED,
          'Vehicle Request Pending Approval',
          `A vehicle request is pending your approval`,
          (updatedRequest._id as any).toString(),
        );
      }
    }

    this.eventEmitter.emit('request.updated', new RequestUpdatedEvent());

    return updatedRequest;
  }

  async reject(id: string, approverId: string, rejectDto: RejectRequestDto): Promise<VehicleRequestDocument> {
    const request = await this.findById(id);
    const approver = await this.usersService.findById(approverId);
    if (!approver) {
      throw new NotFoundException('Approver not found');
    }

    const currentStage = this.workflowService.getCurrentStage(request);

    // Cannot reject if needs correction
    if (currentStage === VehicleRequestStage.NEEDS_CORRECTION) {
      throw new BadRequestException('Request needs correction and must be resubmitted first');
    }

    // Execute workflow transition
    const { nextStage } = await this.workflowService.executeTransition(
      request,
      approver,
      WorkflowAction.REJECT,
      { rejectionReason: rejectDto.rejectionReason },
    );

    // Update request stage and status
    request.currentStage = nextStage;
    request.status = this.mapStageToStatus(nextStage);

    // Add to action history
    this.addActionHistory(
      request,
      WorkflowAction.REJECT,
      (approver._id as any).toString(),
      currentStage,
      rejectDto.rejectionReason,
    );

    // Backward compatibility fields
    request.rejectionReason = rejectDto.rejectionReason;
    request.rejectedAt = new Date();
    request.rejectedBy = (approver._id as any).toString();

    request.markModified('actionHistory');
    request.markModified('approvalChain');

    const updatedRequest = await request.save();

    // Notify requester
    const requester = await this.usersService.findById(this.extractId(request.requesterId));
    if (requester) {
      await this.notificationsService.sendNotification(
        (requester._id as any).toString(),
        NotificationType.REQUEST_REJECTED,
        'Request Rejected',
        `Your vehicle request has been rejected: ${rejectDto.rejectionReason}`,
        (updatedRequest._id as any).toString(),
      );
    }

    this.eventEmitter.emit('request.updated', new RequestUpdatedEvent());

    return updatedRequest;
  }

  async sendBackForCorrection(
    id: string,
    approverId: string,
    correctionDto: SendBackForCorrectionDto,
  ): Promise<VehicleRequestDocument> {
    const request = await this.findById(id);
    const approver = await this.usersService.findById(approverId);
    if (!approver) {
      throw new NotFoundException('Approver not found');
    }

    const currentStage = this.workflowService.getCurrentStage(request);

    // Check if user can send back
    if (!(await this.workflowService.canSendBack(approver, request))) {
      throw new ForbiddenException('You do not have permission to send back this request for correction');
    }

    // Cannot send back if already rejected or needs correction
    if (currentStage === VehicleRequestStage.REJECTED) {
      throw new BadRequestException('Cannot send rejected request back for correction');
    }
    if (currentStage === VehicleRequestStage.NEEDS_CORRECTION) {
      throw new BadRequestException('Request already needs correction');
    }

    // Cannot send back at terminal stages
    const terminalStages = [
      VehicleRequestStage.COMPLETED,
      VehicleRequestStage.IN_PROGRESS,
      VehicleRequestStage.RETURNED,
      VehicleRequestStage.TRANSPORT_OFFICER_ASSIGNMENT,
    ];
    if (terminalStages.includes(currentStage as VehicleRequestStage)) {
      throw new BadRequestException(`Cannot send back request at ${currentStage} stage`);
    }

    // Execute workflow transition
    const { nextStage } = await this.workflowService.executeTransition(
      request,
      approver,
      WorkflowAction.SEND_BACK,
      { correctionNote: correctionDto.correctionNote },
    );

    // Update request stage and status
    request.currentStage = nextStage;
    request.status = this.mapStageToStatus(nextStage);

    // Add to action history
    this.addActionHistory(
      request,
      WorkflowAction.SEND_BACK,
      (approver._id as any).toString(),
      currentStage,
      correctionDto.correctionNote,
    );

    // Add to correction history
    request.correctionHistory.push({
      stage: currentStage,
      requestedBy: (approver._id as any).toString(),
      requestedAt: new Date(),
      correctionNote: correctionDto.correctionNote,
      resubmissionCount: 1,
    } as any);

    // Backward compatibility fields
    request.correctionNote = correctionDto.correctionNote;
    request.correctedAt = new Date();
    request.correctedBy = (approver._id as any).toString();
    request.sentBackToStatus = this.mapStageToStatus(currentStage) as any;

    request.markModified('actionHistory');
    request.markModified('correctionHistory');
    request.markModified('approvalChain');

    const updatedRequest = await request.save();

    // Notify requester
    const requester = await this.usersService.findById(this.extractId(request.requesterId));
    if (requester) {
      await this.notificationsService.sendNotification(
        (requester._id as any).toString(),
        NotificationType.REQUEST_NEEDS_CORRECTION,
        'Request Needs Correction',
        `Your vehicle request has been sent back for correction: ${correctionDto.correctionNote}`,
        (updatedRequest._id as any).toString(),
      );
    }

    this.eventEmitter.emit('request.updated', new RequestUpdatedEvent());

    return updatedRequest;
  }

  async cancel(id: string, requesterId: string, cancellationReason: string): Promise<VehicleRequestDocument> {
    const request = await this.findById(id);
    const requester = await this.usersService.findById(requesterId);
    if (!requester) {
      throw new NotFoundException('Requester not found');
    }

    const currentStage = this.workflowService.getCurrentStage(request);

    // Check if user can cancel
    if (!(await this.workflowService.canCancel(request, requester))) {
      throw new ForbiddenException('You do not have permission to cancel this request');
    }

    // Execute workflow transition
    const { nextStage } = await this.workflowService.executeTransition(
      request,
      requester,
      WorkflowAction.CANCEL,
      { cancellationReason },
    );

    // Update request stage and status
    request.currentStage = nextStage;
    request.status = this.mapStageToStatus(nextStage);

    // Add to action history
    this.addActionHistory(
      request,
      WorkflowAction.CANCEL,
      requesterId,
      currentStage,
      cancellationReason,
    );

    // Set cancellation fields
    request.cancellationReason = cancellationReason;
    request.cancelledAt = new Date();
    request.cancelledBy = requesterId;

    request.markModified('actionHistory');
    request.markModified('approvalChain');

    const updatedRequest = await request.save();

    // Notify relevant parties (supervisor, approvers in the chain)
    const notifyList: any[] = [];
    
    if (request.supervisorId) {
      const supervisor = await this.usersService.findById(this.extractId(request.supervisorId));
      if (supervisor) notifyList.push(supervisor);
    }

    // Notify approvers who have acted on the request
    for (const action of request.actionHistory) {
      const approver = await this.usersService.findById(action.performedBy);
      if (approver && !notifyList.find(u => this.extractId(u._id) === this.extractId(approver._id))) {
        notifyList.push(approver);
      }
    }

    for (const user of notifyList) {
      await this.notificationsService.sendNotification(
        (user._id as any).toString(),
        NotificationType.REQUEST_REJECTED, // Use rejected type for cancellation
        'Request Cancelled',
        `Vehicle request has been cancelled by ${requester.name}: ${cancellationReason}`,
        (updatedRequest._id as any).toString(),
      );
    }

    this.eventEmitter.emit('request.updated', new RequestUpdatedEvent());

    return updatedRequest;
  }

  async resubmit(id: string, requesterId: string): Promise<VehicleRequestDocument> {
    const request = await this.findById(id);

    const requestRequesterId = this.extractId(request.requesterId);
    const requesterIdStr = String(requesterId);

    if (requestRequesterId !== requesterIdStr) {
      throw new ForbiddenException('You can only resubmit your own requests');
    }

    const currentStage = this.workflowService.getCurrentStage(request);

    if (currentStage !== VehicleRequestStage.REJECTED && 
        currentStage !== VehicleRequestStage.NEEDS_CORRECTION) {
      throw new BadRequestException('Only rejected or needs correction requests can be resubmitted');
    }

    // Get latest correction entry if exists
    const hasCorrections =
      Array.isArray(request.correctionHistory) && request.correctionHistory.length > 0;
    let latestCorrection: CorrectionHistory | null = null;

    if (hasCorrections) {
      latestCorrection = request.correctionHistory[
        request.correctionHistory.length - 1
      ] as CorrectionHistory;
      // Update resubmission count
      latestCorrection.resubmissionCount += 1;
      latestCorrection.resolvedAt = new Date();
    }

    // Execute workflow transition
    const { nextStage } = await this.workflowService.executeTransition(
      request,
      await this.usersService.findById(requesterId),
      WorkflowAction.RESUBMIT,
    );

    // Update request stage and status
    request.currentStage = nextStage;
    request.status = this.mapStageToStatus(nextStage);

    // Add to action history
    this.addActionHistory(
      request,
      WorkflowAction.RESUBMIT,
      requesterId,
      currentStage,
      'Request resubmitted after correction',
    );

    // Clear backward compatibility fields
    if (currentStage === VehicleRequestStage.NEEDS_CORRECTION) {
      request.correctionNote = undefined;
      request.correctedAt = undefined;
      request.correctedBy = undefined;
      request.sentBackToStatus = undefined;
    } else {
      request.rejectionReason = undefined;
      request.rejectedAt = undefined;
      request.rejectedBy = undefined;
    }

    request.resubmittedAt = new Date();

    request.markModified('actionHistory');
    request.markModified('correctionHistory');
    request.markModified('approvalChain');

    const updatedRequest = await request.save();

    // Determine who to notify (supervisor or approver at correction stage)
    let notifyTarget: any = null;
    
    if (request.supervisorId && !request.requesterId || this.extractId(request.requesterId) !== this.extractId(request.supervisorId)) {
      notifyTarget = await this.usersService.findById(this.extractId(request.supervisorId));
    } else if (latestCorrection) {
      notifyTarget = await this.usersService.findById(latestCorrection.requestedBy);
    }

    if (notifyTarget) {
      const correctionNote = latestCorrection?.correctionNote || '';
      const message = correctionNote
        ? `A vehicle request has been corrected and resubmitted. Correction note: "${correctionNote}". It is pending your review.`
        : `A vehicle request has been corrected and resubmitted. It is pending your review.`;
      
      await this.notificationsService.sendNotification(
        (notifyTarget._id as any).toString(),
        NotificationType.REQUEST_RESUBMITTED,
        'Request Resubmitted',
        message,
        (updatedRequest._id as any).toString(),
      );
    }

    this.eventEmitter.emit('request.updated', new RequestUpdatedEvent());

    return updatedRequest;
  }

  /**
   * Get next approver for a stage
   */
  private async getNextApproverForStage(stage: string): Promise<any> {
    switch (stage) {
      case VehicleRequestStage.SUPERVISOR_REVIEW:
        const dgsUsers = await this.usersService.findByRole(UserRole.DGS);
        return dgsUsers[0];
      case VehicleRequestStage.DGS_REVIEW:
        const ddgsUsers = await this.usersService.findByRole(UserRole.DDGS);
        return ddgsUsers[0];
      case VehicleRequestStage.DDGS_REVIEW:
        const adTransportUsers = await this.usersService.findByRole(UserRole.AD_TRANSPORT);
        return adTransportUsers[0];
      case VehicleRequestStage.AD_TRANSPORT_REVIEW:
        const transportOfficers = await this.usersService.findByRole(UserRole.TRANSPORT_OFFICER);
        return transportOfficers[0];
      default:
        return null;
    }
  }
}

