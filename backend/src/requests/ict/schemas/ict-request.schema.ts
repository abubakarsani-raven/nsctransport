import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document } from 'mongoose';
import { ActionHistory, ActionHistorySchema } from './action-history.schema';
import { CorrectionHistory, CorrectionHistorySchema } from './correction-history.schema';
import { RequestType } from '../../base/request-type.enum';

export type IctRequestDocument = IctRequest & Document;

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

@Schema()
export class ApprovalEntry {
  @Prop({ type: String, ref: 'User', required: true })
  approverId: string;

  @Prop({ required: true })
  status: string;

  @Prop({ required: true })
  timestamp: Date;

  @Prop()
  comments?: string;
}

const ApprovalEntrySchema = SchemaFactory.createForClass(ApprovalEntry);

@Schema({ timestamps: true })
export class IctRequest {
  @Prop({ type: String, enum: RequestType, default: RequestType.ICT })
  requestType: RequestType;

  @Prop({ type: String, ref: 'User', required: true })
  requesterId: string;

  @Prop({ type: String, ref: 'User' })
  supervisorId?: string;

  @Prop({ required: true })
  equipmentType: string; // e.g., 'laptop', 'printer', 'monitor', etc.

  @Prop({ required: true })
  specifications: string; // Detailed specifications

  @Prop({ required: true })
  purpose: string; // Purpose of the request

  @Prop({ required: true, default: 'normal' })
  urgency: string; // 'low', 'normal', 'high', 'urgent'

  @Prop()
  quantity?: number; // Number of items needed

  @Prop()
  estimatedCost?: number; // Estimated cost if applicable

  @Prop()
  justification?: string; // Business justification

  // Workflow stage
  @Prop({ required: true, default: 'ict_submitted' })
  currentStage: string;

  // Status field
  @Prop({ required: true, enum: IctRequestStatus, default: IctRequestStatus.PENDING })
  status: IctRequestStatus;

  // Action history
  @Prop({ type: [ActionHistorySchema], default: [] })
  actionHistory: ActionHistory[];

  // Correction history
  @Prop({ type: [CorrectionHistorySchema], default: [] })
  correctionHistory: CorrectionHistory[];

  // Approval chain
  @Prop({ type: [ApprovalEntrySchema], default: [] })
  approvalChain: ApprovalEntry[];

  // Rejection fields
  @Prop()
  rejectionReason?: string;

  @Prop()
  rejectedAt?: Date;

  @Prop({ type: String, ref: 'User' })
  rejectedBy?: string;

  // Resubmission tracking
  @Prop()
  resubmittedAt?: Date;

  // Correction fields
  @Prop()
  correctionNote?: string;

  @Prop()
  correctedAt?: Date;

  @Prop({ type: String, ref: 'User' })
  correctedBy?: string;

  @Prop({ enum: IctRequestStatus })
  sentBackToStatus?: IctRequestStatus;

  // Cancellation fields
  @Prop()
  cancellationReason?: string;

  @Prop()
  cancelledAt?: Date;

  @Prop({ type: String, ref: 'User' })
  cancelledBy?: string;

  // Fulfillment fields
  @Prop()
  fulfilledAt?: Date;

  @Prop({ type: String, ref: 'User' })
  fulfilledBy?: string;

  @Prop()
  fulfillmentNotes?: string;
}

export const IctRequestSchema = SchemaFactory.createForClass(IctRequest);

