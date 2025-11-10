import { WorkflowAction } from './schemas/workflow-actions.enum';
import { WorkflowStage, WorkflowTransition } from './schemas/workflow-transition.interface';
import { UserRole } from '../users/schemas/user.schema';

/**
 * ICT Request Workflow Stages
 */
export enum IctRequestStage {
  SUBMITTED = 'ict_submitted',
  SUPERVISOR_REVIEW = 'ict_supervisor_review',
  ICT_OFFICER_REVIEW = 'ict_ict_officer_review',
  APPROVED = 'ict_approved',
  REJECTED = 'ict_rejected',
  NEEDS_CORRECTION = 'ict_needs_correction',
  CANCELLED = 'ict_cancelled',
  FULFILLED = 'ict_fulfilled',
}

/**
 * ICT Request Workflow Definition
 */
export const ICT_REQUEST_WORKFLOW: WorkflowStage[] = [
  {
    id: IctRequestStage.SUBMITTED,
    name: 'Submitted',
    description: 'ICT request has been submitted',
    isInitial: false,
    actions: {
      stage: IctRequestStage.SUBMITTED,
      allowedActions: [WorkflowAction.CANCEL, WorkflowAction.APPROVE, WorkflowAction.REJECT, WorkflowAction.SEND_BACK],
      requiredRole: ['supervisor'],
      requiresSupervisorMatch: true,
    },
  },
  {
    id: IctRequestStage.SUPERVISOR_REVIEW,
    name: 'Supervisor Review',
    description: 'Request is being reviewed by supervisor',
    isInitial: true,
    actions: {
      stage: IctRequestStage.SUPERVISOR_REVIEW,
      allowedActions: [WorkflowAction.APPROVE, WorkflowAction.REJECT, WorkflowAction.SEND_BACK, WorkflowAction.CANCEL],
      requiredRole: ['supervisor'],
      requiresSupervisorMatch: true,
    },
  },
  {
    id: IctRequestStage.ICT_OFFICER_REVIEW,
    name: 'ICT Officer Review',
    description: 'Request is being reviewed by ICT officer',
    actions: {
      stage: IctRequestStage.ICT_OFFICER_REVIEW,
      allowedActions: [WorkflowAction.APPROVE, WorkflowAction.REJECT, WorkflowAction.SEND_BACK],
      requiredRole: UserRole.ADMIN, // Assuming admin or specific ICT role
      requiresSupervisorMatch: false,
    },
  },
  {
    id: IctRequestStage.APPROVED,
    name: 'Approved',
    description: 'Request has been approved',
    actions: {
      stage: IctRequestStage.APPROVED,
      allowedActions: [WorkflowAction.FULFILL],
      requiredRole: UserRole.ADMIN,
      requiresSupervisorMatch: false,
    },
  },
  {
    id: IctRequestStage.FULFILLED,
    name: 'Fulfilled',
    description: 'Request has been fulfilled',
    isTerminal: true,
    actions: {
      stage: IctRequestStage.FULFILLED,
      allowedActions: [],
      requiresSupervisorMatch: false,
    },
  },
  {
    id: IctRequestStage.REJECTED,
    name: 'Rejected',
    description: 'Request has been rejected',
    isTerminal: true,
    actions: {
      stage: IctRequestStage.REJECTED,
      allowedActions: [WorkflowAction.RESUBMIT],
      requiresSupervisorMatch: false,
    },
  },
  {
    id: IctRequestStage.NEEDS_CORRECTION,
    name: 'Needs Correction',
    description: 'Request needs correction and has been sent back',
    actions: {
      stage: IctRequestStage.NEEDS_CORRECTION,
      allowedActions: [WorkflowAction.RESUBMIT],
      requiresSupervisorMatch: false,
    },
  },
  {
    id: IctRequestStage.CANCELLED,
    name: 'Cancelled',
    description: 'Request has been cancelled',
    isTerminal: true,
    actions: {
      stage: IctRequestStage.CANCELLED,
      allowedActions: [],
      requiresSupervisorMatch: false,
    },
  },
];

/**
 * Workflow transitions for ICT requests
 */
export const ICT_REQUEST_TRANSITIONS: WorkflowTransition[] = [
  {
    fromStage: IctRequestStage.SUPERVISOR_REVIEW,
    toStage: IctRequestStage.ICT_OFFICER_REVIEW,
    action: WorkflowAction.APPROVE,
  },
  {
    fromStage: IctRequestStage.ICT_OFFICER_REVIEW,
    toStage: IctRequestStage.APPROVED,
    action: WorkflowAction.APPROVE,
  },
  {
    fromStage: IctRequestStage.APPROVED,
    toStage: IctRequestStage.FULFILLED,
    action: WorkflowAction.FULFILL,
  },
  {
    fromStage: IctRequestStage.SUPERVISOR_REVIEW,
    toStage: IctRequestStage.REJECTED,
    action: WorkflowAction.REJECT,
  },
  {
    fromStage: IctRequestStage.ICT_OFFICER_REVIEW,
    toStage: IctRequestStage.REJECTED,
    action: WorkflowAction.REJECT,
  },
  {
    fromStage: IctRequestStage.SUPERVISOR_REVIEW,
    toStage: IctRequestStage.NEEDS_CORRECTION,
    action: WorkflowAction.SEND_BACK,
  },
  {
    fromStage: IctRequestStage.ICT_OFFICER_REVIEW,
    toStage: IctRequestStage.NEEDS_CORRECTION,
    action: WorkflowAction.SEND_BACK,
  },
  {
    fromStage: IctRequestStage.SUPERVISOR_REVIEW,
    toStage: IctRequestStage.CANCELLED,
    action: WorkflowAction.CANCEL,
  },
  {
    fromStage: IctRequestStage.NEEDS_CORRECTION,
    toStage: IctRequestStage.SUPERVISOR_REVIEW,
    action: WorkflowAction.RESUBMIT,
  },
  {
    fromStage: IctRequestStage.REJECTED,
    toStage: IctRequestStage.SUPERVISOR_REVIEW,
    action: WorkflowAction.RESUBMIT,
  },
];

/**
 * Get workflow stage by ID
 */
export function getIctWorkflowStage(stageId: string): WorkflowStage | undefined {
  return ICT_REQUEST_WORKFLOW.find((stage) => stage.id === stageId);
}

/**
 * Get initial workflow stage
 */
export function getIctInitialStage(): WorkflowStage {
  return ICT_REQUEST_WORKFLOW.find((stage) => stage.isInitial)!;
}

/**
 * Check if stage is terminal
 */
export function isIctTerminalStage(stageId: string): boolean {
  const stage = getIctWorkflowStage(stageId);
  return stage?.isTerminal === true;
}

