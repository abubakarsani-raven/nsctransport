import { ActionHistory } from '../schemas/action-history.schema';
import { CorrectionHistory } from '../schemas/correction-history.schema';
import { RequestType } from './request-type.enum';

/**
 * Base interface for all request types
 * Contains common fields shared across all request modules
 */
export interface BaseRequest {
  requesterId: string;
  supervisorId?: string;
  requestType: RequestType;
  currentStage: string;
  status: string;
  actionHistory: ActionHistory[];
  correctionHistory: CorrectionHistory[];
  approvalChain?: any[];
  rejectionReason?: string;
  rejectedAt?: Date;
  rejectedBy?: string;
  resubmittedAt?: Date;
  correctionNote?: string;
  correctedAt?: Date;
  correctedBy?: string;
  sentBackToStatus?: string;
  cancellationReason?: string;
  cancelledAt?: Date;
  cancelledBy?: string;
  createdAt?: Date;
  updatedAt?: Date;
}

