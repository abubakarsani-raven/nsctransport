export enum IctRequestStatus {
  PENDING = 'ict_pending',
  SUPERVISOR_APPROVED = 'ict_supervisor_approved',
  ICT_OFFICER_APPROVED = 'ict_ict_officer_approved',
  APPROVED = 'ict_approved',
  REJECTED = 'ict_rejected',
  NEEDS_CORRECTION = 'ict_needs_correction',
  CANCELLED = 'ict_cancelled',
  FULFILLED = 'ict_fulfilled',
}

export interface IctRequest {
  _id: string;
  requestType: 'ICT';
  requesterId: string | { _id: string; name: string; email: string };
  supervisorId?: string | { _id: string; name: string; email: string };
  equipmentType: string;
  specifications: string;
  purpose: string;
  status: IctRequestStatus;
  urgency?: string;
  actionHistory?: Array<{
    action: string;
    performedBy: string | { _id: string; name: string; email: string };
    timestamp: Date;
    comments?: string;
  }>;
  approvalChain?: Array<{
    approverId: string;
    status: string;
    timestamp: Date;
    comments?: string;
  }>;
  createdAt?: string;
  updatedAt?: string;
}

export interface CreateIctRequestDto {
  equipmentType: string;
  specifications: string;
  purpose: string;
  urgency?: string;
}

export const ICT_STATUS_LABELS: Record<IctRequestStatus, string> = {
  [IctRequestStatus.PENDING]: 'Pending',
  [IctRequestStatus.SUPERVISOR_APPROVED]: 'Supervisor Approved',
  [IctRequestStatus.ICT_OFFICER_APPROVED]: 'ICT Officer Approved',
  [IctRequestStatus.APPROVED]: 'Approved',
  [IctRequestStatus.REJECTED]: 'Rejected',
  [IctRequestStatus.NEEDS_CORRECTION]: 'Needs Correction',
  [IctRequestStatus.CANCELLED]: 'Cancelled',
  [IctRequestStatus.FULFILLED]: 'Fulfilled',
};

