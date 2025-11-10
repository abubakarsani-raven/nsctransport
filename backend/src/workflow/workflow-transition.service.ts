import { Injectable, BadRequestException } from '@nestjs/common';
import {
  VEHICLE_REQUEST_TRANSITIONS,
  VehicleRequestStage,
  getWorkflowStage,
  isTerminalStage,
} from './workflow-definition';
import { WorkflowAction } from './schemas/workflow-actions.enum';
import { WorkflowTransition } from './schemas/workflow-transition.interface';

@Injectable()
export class WorkflowTransitionService {
  /**
   * Get the next stage based on current stage and action
   */
  getNextStage(
    currentStage: string,
    action: WorkflowAction,
    context?: any,
  ): string | null {
    // Find transitions matching current stage and action
    const transitions = VEHICLE_REQUEST_TRANSITIONS.filter(
      (transition) =>
        transition.fromStage === currentStage && transition.action === action,
    );

    if (transitions.length === 0) {
      return null;
    }

    // If there's a condition, use it to filter
    if (transitions.length === 1 && !transitions[0].condition) {
      return transitions[0].toStage;
    }

    // Multiple transitions or transition with condition
    for (const transition of transitions) {
      if (!transition.condition || transition.condition(context || {})) {
        return transition.toStage;
      }
    }

    // Default to first transition if no condition matches
    return transitions[0]?.toStage || null;
  }

  /**
   * Check if a transition is valid
   */
  isValidTransition(
    fromStage: string,
    toStage: string,
    action: WorkflowAction,
    context?: any,
  ): boolean {
    const transitions = VEHICLE_REQUEST_TRANSITIONS.filter(
      (transition) =>
        transition.fromStage === fromStage &&
        transition.toStage === toStage &&
        transition.action === action,
    );

    if (transitions.length === 0) {
      return false;
    }

    // Check condition if present
    for (const transition of transitions) {
      if (!transition.condition || transition.condition(context || {})) {
        return true;
      }
    }

    return false;
  }

  /**
   * Get all possible transitions from a stage
   */
  getAvailableTransitions(stage: string): WorkflowTransition[] {
    return VEHICLE_REQUEST_TRANSITIONS.filter(
      (transition) => transition.fromStage === stage,
    );
  }

  /**
   * Check if action can be performed at current stage
   */
  canPerformAction(stage: string, action: WorkflowAction): boolean {
    const workflowStage = getWorkflowStage(stage);
    if (!workflowStage) {
      return false;
    }

    return workflowStage.actions.allowedActions.includes(action);
  }

  /**
   * Validate that the target stage is not terminal (unless it's a terminal action)
   */
  validateTransition(
    fromStage: string,
    toStage: string,
    action: WorkflowAction,
  ): void {
    // Terminal stages can only be reached by specific actions
    const terminalStages = [
      VehicleRequestStage.COMPLETED,
      VehicleRequestStage.RETURNED,
      VehicleRequestStage.CANCELLED,
      VehicleRequestStage.REJECTED,
    ];

    if (terminalStages.includes(toStage as VehicleRequestStage)) {
      const allowedTerminalActions = [
        WorkflowAction.REJECT,
        WorkflowAction.CANCEL,
        WorkflowAction.COMPLETE_TRIP,
        WorkflowAction.RETURN_VEHICLE,
      ];

      if (!allowedTerminalActions.includes(action)) {
        throw new BadRequestException(
          `Cannot transition to terminal stage ${toStage} with action ${action}`,
        );
      }
    }

    // Check if transition is valid
    if (!this.isValidTransition(fromStage, toStage, action)) {
      throw new BadRequestException(
        `Invalid transition from ${fromStage} to ${toStage} with action ${action}`,
      );
    }
  }
}

