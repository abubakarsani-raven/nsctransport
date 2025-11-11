export enum StoreRequestStatus {
  PENDING = 'store_pending',
  SUPERVISOR_APPROVED = 'store_supervisor_approved',
  STORE_OFFICER_APPROVED = 'store_officer_approved',
  APPROVED = 'store_approved',
  REJECTED = 'store_rejected',
  NEEDS_CORRECTION = 'store_needs_correction',
  CANCELLED = 'store_cancelled',
  FULFILLED = 'store_fulfilled',
}

export interface StoreRequest {
  _id: string;
  requestType: 'STORE';
  requesterId: string | { _id: string; name: string; email: string };
  supervisorId?: string | { _id: string; name: string; email: string };
  itemName: string;
  category?: string;
  quantity: number;
  unit?: string;
  purpose: string;
  status: StoreRequestStatus;
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

export interface CreateStoreRequestDto {
  itemName: string;
  category?: string;
  quantity: number;
  unit?: string;
  purpose: string;
  urgency?: string;
}

export const STORE_STATUS_LABELS: Record<StoreRequestStatus, string> = {
  [StoreRequestStatus.PENDING]: 'Pending',
  [StoreRequestStatus.SUPERVISOR_APPROVED]: 'Supervisor Approved',
  [StoreRequestStatus.STORE_OFFICER_APPROVED]: 'Store Officer Approved',
  [StoreRequestStatus.APPROVED]: 'Approved',
  [StoreRequestStatus.REJECTED]: 'Rejected',
  [StoreRequestStatus.NEEDS_CORRECTION]: 'Needs Correction',
  [StoreRequestStatus.CANCELLED]: 'Cancelled',
  [StoreRequestStatus.FULFILLED]: 'Fulfilled',
};

