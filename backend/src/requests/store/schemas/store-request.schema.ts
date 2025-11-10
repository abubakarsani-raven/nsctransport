import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document } from 'mongoose';
import { ActionHistory, ActionHistorySchema } from './action-history.schema';
import { CorrectionHistory, CorrectionHistorySchema } from './correction-history.schema';
import { RequestType } from '../../base/request-type.enum';

export type StoreRequestDocument = StoreRequest & Document;

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
export class StoreRequest {
  @Prop({ type: String, enum: RequestType, default: RequestType.STORE })
  requestType: RequestType;

  @Prop({ type: String, ref: 'User', required: true })
  requesterId: string;

  @Prop({ type: String, ref: 'User' })
  supervisorId?: string;

  @Prop({ required: true })
  itemName: string; // Name of the item

  @Prop({ required: true })
  category: string; // Category of item (e.g., 'stationery', 'cleaning', 'office supplies')

  @Prop({ required: true, min: 1 })
  quantity: number; // Quantity needed

  @Prop({ required: true })
  unit: string; // Unit of measurement (e.g., 'pieces', 'boxes', 'liters')

  @Prop()
  specifications?: string; // Additional specifications

  @Prop({ required: true })
  purpose: string; // Purpose of the request

  @Prop({ required: true, default: 'normal' })
  urgency: string; // 'low', 'normal', 'high', 'urgent'

  @Prop()
  estimatedCost?: number; // Estimated cost if applicable

  @Prop()
  justification?: string; // Business justification

  // Workflow stage
  @Prop({ required: true, default: 'store_submitted' })
  currentStage: string;

  // Status field
  @Prop({ required: true, enum: StoreRequestStatus, default: StoreRequestStatus.PENDING })
  status: StoreRequestStatus;

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

  @Prop({ enum: StoreRequestStatus })
  sentBackToStatus?: StoreRequestStatus;

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

export const StoreRequestSchema = SchemaFactory.createForClass(StoreRequest);

