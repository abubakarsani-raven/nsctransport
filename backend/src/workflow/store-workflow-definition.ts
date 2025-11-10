import { WorkflowAction } from './schemas/workflow-actions.enum';
import { WorkflowStage, WorkflowTransition } from './schemas/workflow-transition.interface';
import { UserRole } from '../users/schemas/user.schema';

/**
 * Store Request Workflow Stages
 */
export enum StoreRequestStage {
  SUBMITTED = 'store_submitted',
  SUPERVISOR_REVIEW = 'store_supervisor_review',
  STORE_OFFICER_REVIEW = 'store_officer_review',
  APPROVED = 'store_approved',
  REJECTED = 'store_rejected',
  NEEDS_CORRECTION = 'store_needs_correction',
  CANCELLED = 'store_cancelled',
  FULFILLED = 'store_fulfilled',
}

/**
 * Store Request Workflow Definition
 */
export const STORE_REQUEST_WORKFLOW: WorkflowStage[] = [
  {
    id: StoreRequestStage.SUBMITTED,
    name: 'Submitted',
    description: 'Store request has been submitted',
    isInitial: false,
    actions: {
      stage: StoreRequestStage.SUBMITTED,
      allowedActions: [WorkflowAction.CANCEL, WorkflowAction.APPROVE, WorkflowAction.REJECT, WorkflowAction.SEND_BACK],
      requiredRole: ['supervisor'],
      requiresSupervisorMatch: true,
    },
  },
  {
    id: StoreRequestStage.SUPERVISOR_REVIEW,
    name: 'Supervisor Review',
    description: 'Request is being reviewed by supervisor',
    isInitial: true,
    actions: {
      stage: StoreRequestStage.SUPERVISOR_REVIEW,
      allowedActions: [WorkflowAction.APPROVE, WorkflowAction.REJECT, WorkflowAction.SEND_BACK, WorkflowAction.CANCEL],
      requiredRole: ['supervisor'],
      requiresSupervisorMatch: true,
    },
  },
  {
    id: StoreRequestStage.STORE_OFFICER_REVIEW,
    name: 'Store Officer Review',
    description: 'Request is being reviewed by store officer',
    actions: {
      stage: StoreRequestStage.STORE_OFFICER_REVIEW,
      allowedActions: [WorkflowAction.APPROVE, WorkflowAction.REJECT, WorkflowAction.SEND_BACK],
      requiredRole: UserRole.ADMIN, // Assuming admin or specific store role
      requiresSupervisorMatch: false,
    },
  },
  {
    id: StoreRequestStage.APPROVED,
    name: 'Approved',
    description: 'Request has been approved',
    actions: {
      stage: StoreRequestStage.APPROVED,
      allowedActions: [WorkflowAction.FULFILL],
      requiredRole: UserRole.ADMIN,
      requiresSupervisorMatch: false,
    },
  },
  {
    id: StoreRequestStage.FULFILLED,
    name: 'Fulfilled',
    description: 'Request has been fulfilled',
    isTerminal: true,
    actions: {
      stage: StoreRequestStage.FULFILLED,
      allowedActions: [],
      requiresSupervisorMatch: false,
    },
  },
  {
    id: StoreRequestStage.REJECTED,
    name: 'Rejected',
    description: 'Request has been rejected',
    isTerminal: true,
    actions: {
      stage: StoreRequestStage.REJECTED,
      allowedActions: [WorkflowAction.RESUBMIT],
      requiresSupervisorMatch: false,
    },
  },
  {
    id: StoreRequestStage.NEEDS_CORRECTION,
    name: 'Needs Correction',
    description: 'Request needs correction and has been sent back',
    actions: {
      stage: StoreRequestStage.NEEDS_CORRECTION,
      allowedActions: [WorkflowAction.RESUBMIT],
      requiresSupervisorMatch: false,
    },
  },
  {
    id: StoreRequestStage.CANCELLED,
    name: 'Cancelled',
    description: 'Request has been cancelled',
    isTerminal: true,
    actions: {
      stage: StoreRequestStage.CANCELLED,
      allowedActions: [],
      requiresSupervisorMatch: false,
    },
  },
];

/**
 * Workflow transitions for store requests
 */
export const STORE_REQUEST_TRANSITIONS: WorkflowTransition[] = [
  {
    fromStage: StoreRequestStage.SUPERVISOR_REVIEW,
    toStage: StoreRequestStage.STORE_OFFICER_REVIEW,
    action: WorkflowAction.APPROVE,
  },
  {
    fromStage: StoreRequestStage.STORE_OFFICER_REVIEW,
    toStage: StoreRequestStage.APPROVED,
    action: WorkflowAction.APPROVE,
  },
  {
    fromStage: StoreRequestStage.APPROVED,
    toStage: StoreRequestStage.FULFILLED,
    action: WorkflowAction.FULFILL,
  },
  {
    fromStage: StoreRequestStage.SUPERVISOR_REVIEW,
    toStage: StoreRequestStage.REJECTED,
    action: WorkflowAction.REJECT,
  },
  {
    fromStage: StoreRequestStage.STORE_OFFICER_REVIEW,
    toStage: StoreRequestStage.REJECTED,
    action: WorkflowAction.REJECT,
  },
  {
    fromStage: StoreRequestStage.SUPERVISOR_REVIEW,
    toStage: StoreRequestStage.NEEDS_CORRECTION,
    action: WorkflowAction.SEND_BACK,
  },
  {
    fromStage: StoreRequestStage.STORE_OFFICER_REVIEW,
    toStage: StoreRequestStage.NEEDS_CORRECTION,
    action: WorkflowAction.SEND_BACK,
  },
  {
    fromStage: StoreRequestStage.SUPERVISOR_REVIEW,
    toStage: StoreRequestStage.CANCELLED,
    action: WorkflowAction.CANCEL,
  },
  {
    fromStage: StoreRequestStage.NEEDS_CORRECTION,
    toStage: StoreRequestStage.SUPERVISOR_REVIEW,
    action: WorkflowAction.RESUBMIT,
  },
  {
    fromStage: StoreRequestStage.REJECTED,
    toStage: StoreRequestStage.SUPERVISOR_REVIEW,
    action: WorkflowAction.RESUBMIT,
  },
];

/**
 * Get workflow stage by ID
 */
export function getStoreWorkflowStage(stageId: string): WorkflowStage | undefined {
  return STORE_REQUEST_WORKFLOW.find((stage) => stage.id === stageId);
}

/**
 * Get initial workflow stage
 */
export function getStoreInitialStage(): WorkflowStage {
  return STORE_REQUEST_WORKFLOW.find((stage) => stage.isInitial)!;
}

/**
 * Check if stage is terminal
 */
export function isStoreTerminalStage(stageId: string): boolean {
  const stage = getStoreWorkflowStage(stageId);
  return stage?.isTerminal === true;
}

