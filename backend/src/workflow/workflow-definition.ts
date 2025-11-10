import { WorkflowAction } from './schemas/workflow-actions.enum';
import { WorkflowStage, WorkflowTransition } from './schemas/workflow-transition.interface';
import { UserRole } from '../users/schemas/user.schema';

/**
 * Vehicle Request Workflow Stages
 */
export enum VehicleRequestStage {
  SUBMITTED = 'submitted',
  SUPERVISOR_REVIEW = 'supervisor_review',
  DGS_REVIEW = 'dgs_review',
  DDGS_REVIEW = 'ddgs_review',
  AD_TRANSPORT_REVIEW = 'ad_transport_review',
  TRANSPORT_OFFICER_ASSIGNMENT = 'transport_officer_assignment',
  ASSIGNED = 'assigned',
  IN_PROGRESS = 'in_progress',
  COMPLETED = 'completed',
  RETURNED = 'returned',
  CANCELLED = 'cancelled',
  REJECTED = 'rejected',
  NEEDS_CORRECTION = 'needs_correction',
}

/**
 * Vehicle Request Workflow Definition
 */
export const VEHICLE_REQUEST_WORKFLOW: WorkflowStage[] = [
  {
    id: VehicleRequestStage.SUBMITTED,
    name: 'Submitted',
    description: 'Request has been submitted (internal stage - requests go directly to review)',
    isInitial: false, // Not used as initial stage anymore
    actions: {
      stage: VehicleRequestStage.SUBMITTED,
      allowedActions: [WorkflowAction.CANCEL, WorkflowAction.APPROVE, WorkflowAction.REJECT, WorkflowAction.SEND_BACK],
      requiredRole: ['supervisor', UserRole.DGS], // Supervisor or DGS can approve/reject/send back
      requiresSupervisorMatch: true, // Supervisor must match request's supervisor
    },
  },
  {
    id: VehicleRequestStage.SUPERVISOR_REVIEW,
    name: 'Supervisor Review',
    description: 'Request is being reviewed by supervisor',
    isInitial: true, // This is the initial stage for non-supervisor requests
    actions: {
      stage: VehicleRequestStage.SUPERVISOR_REVIEW,
      allowedActions: [WorkflowAction.APPROVE, WorkflowAction.REJECT, WorkflowAction.SEND_BACK, WorkflowAction.CANCEL],
      requiredRole: ['supervisor', UserRole.DGS], // Supervisor or DGS can approve
      requiresSupervisorMatch: true, // Supervisor must match request's supervisor
    },
  },
  {
    id: VehicleRequestStage.DGS_REVIEW,
    name: 'DGS Review',
    description: 'Request is being reviewed by Deputy General Secretary',
    isInitial: true, // This is the initial stage for supervisor requests
    actions: {
      stage: VehicleRequestStage.DGS_REVIEW,
      allowedActions: [WorkflowAction.APPROVE, WorkflowAction.REJECT, WorkflowAction.SEND_BACK, WorkflowAction.CANCEL, WorkflowAction.ASSIGN],
      requiredRole: UserRole.DGS, // DGS can approve at this stage
      requiresSupervisorMatch: false,
    },
  },
  {
    id: VehicleRequestStage.DDGS_REVIEW,
    name: 'DDGS Review',
    description: 'Request is being reviewed by Deputy Director General Secretary',
    actions: {
      stage: VehicleRequestStage.DDGS_REVIEW,
      allowedActions: [WorkflowAction.APPROVE, WorkflowAction.REJECT, WorkflowAction.SEND_BACK],
      requiredRole: UserRole.DDGS,
      requiresSupervisorMatch: false,
    },
  },
  {
    id: VehicleRequestStage.AD_TRANSPORT_REVIEW,
    name: 'AD Transport Review',
    description: 'Request is being reviewed by Assistant Director Transport',
    actions: {
      stage: VehicleRequestStage.AD_TRANSPORT_REVIEW,
      allowedActions: [WorkflowAction.APPROVE, WorkflowAction.REJECT, WorkflowAction.SEND_BACK],
      requiredRole: UserRole.AD_TRANSPORT,
      requiresSupervisorMatch: false,
    },
  },
  {
    id: VehicleRequestStage.TRANSPORT_OFFICER_ASSIGNMENT,
    name: 'Transport Officer Assignment',
    description: 'Transport officer is assigning driver and vehicle',
    actions: {
      stage: VehicleRequestStage.TRANSPORT_OFFICER_ASSIGNMENT,
      allowedActions: [WorkflowAction.ASSIGN],
      requiredRole: UserRole.TRANSPORT_OFFICER,
      requiresSupervisorMatch: false,
    },
  },
  {
    id: VehicleRequestStage.ASSIGNED,
    name: 'Trip Ready',
    description: 'Driver and vehicle have been assigned. Trip is awaiting start.',
    actions: {
      stage: VehicleRequestStage.ASSIGNED,
      allowedActions: [WorkflowAction.START_TRIP],
      requiredRole: UserRole.DRIVER,
      requiresSupervisorMatch: false,
    },
  },
  {
    id: VehicleRequestStage.IN_PROGRESS,
    name: 'In Progress',
    description: 'Trip is in progress',
    actions: {
      stage: VehicleRequestStage.IN_PROGRESS,
      allowedActions: [WorkflowAction.COMPLETE_TRIP],
      requiredRole: UserRole.DRIVER,
      requiresSupervisorMatch: false,
    },
  },
  {
    id: VehicleRequestStage.COMPLETED,
    name: 'Completed',
    description: 'Trip has been completed',
    isTerminal: true,
    actions: {
      stage: VehicleRequestStage.COMPLETED,
      allowedActions: [WorkflowAction.RETURN_VEHICLE],
      requiredRole: UserRole.DRIVER,
      requiresSupervisorMatch: false,
    },
  },
  {
    id: VehicleRequestStage.RETURNED,
    name: 'Returned',
    description: 'Vehicle has been returned',
    isTerminal: true,
    actions: {
      stage: VehicleRequestStage.RETURNED,
      allowedActions: [],
      requiresSupervisorMatch: false,
    },
  },
  {
    id: VehicleRequestStage.CANCELLED,
    name: 'Cancelled',
    description: 'Request has been cancelled',
    isTerminal: true,
    actions: {
      stage: VehicleRequestStage.CANCELLED,
      allowedActions: [],
      requiresSupervisorMatch: false,
    },
  },
  {
    id: VehicleRequestStage.REJECTED,
    name: 'Rejected',
    description: 'Request has been rejected',
    isTerminal: true,
    actions: {
      stage: VehicleRequestStage.REJECTED,
      allowedActions: [WorkflowAction.RESUBMIT],
      requiresSupervisorMatch: false,
    },
  },
  {
    id: VehicleRequestStage.NEEDS_CORRECTION,
    name: 'Needs Correction',
    description: 'Request needs correction and has been sent back',
    actions: {
      stage: VehicleRequestStage.NEEDS_CORRECTION,
      allowedActions: [WorkflowAction.RESUBMIT],
      requiresSupervisorMatch: false,
    },
  },
];

/**
 * Workflow transitions for vehicle requests
 */
export const VEHICLE_REQUEST_TRANSITIONS: WorkflowTransition[] = [
  // Approval transitions
  {
    fromStage: VehicleRequestStage.SUBMITTED,
    toStage: VehicleRequestStage.DGS_REVIEW,
    action: WorkflowAction.APPROVE,
    condition: (context: any) => {
      // If requester is supervisor, go directly to DGS (skip supervisor review)
      return context.requesterIsSupervisor === true;
    },
  },
  {
    fromStage: VehicleRequestStage.SUBMITTED,
    toStage: VehicleRequestStage.SUPERVISOR_REVIEW,
    action: WorkflowAction.APPROVE,
    condition: (context: any) => {
      // If requester is not supervisor, go to supervisor review
      return context.requesterIsSupervisor !== true;
    },
  },
  {
    fromStage: VehicleRequestStage.SUPERVISOR_REVIEW,
    toStage: VehicleRequestStage.DGS_REVIEW,
    action: WorkflowAction.APPROVE,
  },
  {
    fromStage: VehicleRequestStage.DGS_REVIEW,
    toStage: VehicleRequestStage.DDGS_REVIEW,
    action: WorkflowAction.APPROVE,
  },
  // Allow DGS to skip DDGS and ADTransport, go directly to Transport Officer using ASSIGN action
  {
    fromStage: VehicleRequestStage.DGS_REVIEW,
    toStage: VehicleRequestStage.TRANSPORT_OFFICER_ASSIGNMENT,
    action: WorkflowAction.ASSIGN,
  },
  {
    fromStage: VehicleRequestStage.DDGS_REVIEW,
    toStage: VehicleRequestStage.AD_TRANSPORT_REVIEW,
    action: WorkflowAction.APPROVE,
  },
  {
    fromStage: VehicleRequestStage.AD_TRANSPORT_REVIEW,
    toStage: VehicleRequestStage.TRANSPORT_OFFICER_ASSIGNMENT,
    action: WorkflowAction.APPROVE,
  },
  {
    fromStage: VehicleRequestStage.TRANSPORT_OFFICER_ASSIGNMENT,
    toStage: VehicleRequestStage.ASSIGNED,
    action: WorkflowAction.ASSIGN,
  },
  {
    fromStage: VehicleRequestStage.ASSIGNED,
    toStage: VehicleRequestStage.IN_PROGRESS,
    action: WorkflowAction.START_TRIP,
  },
  {
    fromStage: VehicleRequestStage.IN_PROGRESS,
    toStage: VehicleRequestStage.COMPLETED,
    action: WorkflowAction.COMPLETE_TRIP,
  },
  {
    fromStage: VehicleRequestStage.COMPLETED,
    toStage: VehicleRequestStage.RETURNED,
    action: WorkflowAction.RETURN_VEHICLE,
  },
  // Rejection transitions
  {
    fromStage: VehicleRequestStage.SUBMITTED,
    toStage: VehicleRequestStage.REJECTED,
    action: WorkflowAction.REJECT,
  },
  {
    fromStage: VehicleRequestStage.SUPERVISOR_REVIEW,
    toStage: VehicleRequestStage.REJECTED,
    action: WorkflowAction.REJECT,
  },
  {
    fromStage: VehicleRequestStage.DGS_REVIEW,
    toStage: VehicleRequestStage.REJECTED,
    action: WorkflowAction.REJECT,
  },
  {
    fromStage: VehicleRequestStage.DDGS_REVIEW,
    toStage: VehicleRequestStage.REJECTED,
    action: WorkflowAction.REJECT,
  },
  {
    fromStage: VehicleRequestStage.AD_TRANSPORT_REVIEW,
    toStage: VehicleRequestStage.REJECTED,
    action: WorkflowAction.REJECT,
  },
  {
    fromStage: VehicleRequestStage.ASSIGNED,
    toStage: VehicleRequestStage.REJECTED,
    action: WorkflowAction.REJECT,
  },
  // Send back for correction transitions
  {
    fromStage: VehicleRequestStage.SUBMITTED,
    toStage: VehicleRequestStage.NEEDS_CORRECTION,
    action: WorkflowAction.SEND_BACK,
  },
  {
    fromStage: VehicleRequestStage.SUPERVISOR_REVIEW,
    toStage: VehicleRequestStage.NEEDS_CORRECTION,
    action: WorkflowAction.SEND_BACK,
  },
  {
    fromStage: VehicleRequestStage.DGS_REVIEW,
    toStage: VehicleRequestStage.NEEDS_CORRECTION,
    action: WorkflowAction.SEND_BACK,
  },
  {
    fromStage: VehicleRequestStage.DDGS_REVIEW,
    toStage: VehicleRequestStage.NEEDS_CORRECTION,
    action: WorkflowAction.SEND_BACK,
  },
  {
    fromStage: VehicleRequestStage.AD_TRANSPORT_REVIEW,
    toStage: VehicleRequestStage.NEEDS_CORRECTION,
    action: WorkflowAction.SEND_BACK,
  },
  {
    fromStage: VehicleRequestStage.ASSIGNED,
    toStage: VehicleRequestStage.NEEDS_CORRECTION,
    action: WorkflowAction.SEND_BACK,
  },
  // Cancellation transitions
  {
    fromStage: VehicleRequestStage.SUBMITTED,
    toStage: VehicleRequestStage.CANCELLED,
    action: WorkflowAction.CANCEL,
  },
  {
    fromStage: VehicleRequestStage.SUPERVISOR_REVIEW,
    toStage: VehicleRequestStage.CANCELLED,
    action: WorkflowAction.CANCEL,
  },
  {
    fromStage: VehicleRequestStage.DGS_REVIEW,
    toStage: VehicleRequestStage.CANCELLED,
    action: WorkflowAction.CANCEL,
  },
  {
    fromStage: VehicleRequestStage.DDGS_REVIEW,
    toStage: VehicleRequestStage.CANCELLED,
    action: WorkflowAction.CANCEL,
  },
  {
    fromStage: VehicleRequestStage.AD_TRANSPORT_REVIEW,
    toStage: VehicleRequestStage.CANCELLED,
    action: WorkflowAction.CANCEL,
  },
  {
    fromStage: VehicleRequestStage.ASSIGNED,
    toStage: VehicleRequestStage.CANCELLED,
    action: WorkflowAction.CANCEL,
  },
  // Resubmission transitions (resume from correction stage)
  {
    fromStage: VehicleRequestStage.NEEDS_CORRECTION,
    toStage: VehicleRequestStage.SUBMITTED,
    action: WorkflowAction.RESUBMIT,
  },
  {
    fromStage: VehicleRequestStage.REJECTED,
    toStage: VehicleRequestStage.SUBMITTED,
    action: WorkflowAction.RESUBMIT,
  },
];

/**
 * Get workflow stage by ID
 */
export function getWorkflowStage(stageId: string): WorkflowStage | undefined {
  return VEHICLE_REQUEST_WORKFLOW.find((stage) => stage.id === stageId);
}

/**
 * Get initial workflow stage
 */
export function getInitialStage(): WorkflowStage {
  return VEHICLE_REQUEST_WORKFLOW.find((stage) => stage.isInitial)!;
}

/**
 * Get terminal stages
 */
export function getTerminalStages(): WorkflowStage[] {
  return VEHICLE_REQUEST_WORKFLOW.filter((stage) => stage.isTerminal);
}

/**
 * Check if stage is terminal
 */
export function isTerminalStage(stageId: string): boolean {
  const stage = getWorkflowStage(stageId);
  return stage?.isTerminal === true;
}

