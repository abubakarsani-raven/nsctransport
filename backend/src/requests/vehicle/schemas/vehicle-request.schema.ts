import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document } from 'mongoose';
import { ActionHistory, ActionHistorySchema } from './action-history.schema';
import { CorrectionHistory, CorrectionHistorySchema } from './correction-history.schema';
import { RequestType } from '../../base/request-type.enum';

export type VehicleRequestDocument = VehicleRequest & Document;

export enum RequestStatus {
  PENDING = 'pending',
  SUPERVISOR_APPROVED = 'supervisor_approved',
  DGS_APPROVED = 'dgs_approved',
  DDGS_APPROVED = 'ddgs_approved',
  AD_TRANSPORT_APPROVED = 'ad_transport_approved',
  TRANSPORT_OFFICER_ASSIGNED = 'transport_officer_assigned',
  DRIVER_ACCEPTED = 'driver_accepted',
  IN_PROGRESS = 'in_progress',
  COMPLETED = 'completed',
  RETURNED = 'returned',
  REJECTED = 'rejected',
  NEEDS_CORRECTION = 'needs_correction',
  CANCELLED = 'cancelled',
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
export class VehicleRequest {
  @Prop({ type: String, enum: RequestType, default: RequestType.VEHICLE })
  requestType: RequestType;

  @Prop({ type: String, ref: 'User', required: true })
  requesterId: string;

  @Prop({ type: String, ref: 'User' })
  supervisorId?: string;

  @Prop({ type: String, ref: 'Office', required: true })
  originOffice: string;

  @Prop({ required: true })
  destination: string;

  @Prop({
    type: {
      lat: Number,
      lng: Number,
    },
  })
  destinationCoordinates?: {
    lat: number;
    lng: number;
  };

  @Prop({
    type: {
      lat: Number,
      lng: Number,
    },
  })
  coordinates?: {
    lat: number;
    lng: number;
  };

  @Prop({ required: true })
  startDate: Date;

  @Prop({ required: true })
  endDate: Date;

  @Prop({ required: true })
  purpose: string;

  @Prop({ required: true, min: 1 })
  passengerCount: number;

  @Prop({ type: [{ type: String, ref: 'User' }], default: [] })
  participantIds?: string[];

  // Workflow stage (primary field for workflow engine)
  @Prop({ required: true, default: 'submitted' })
  currentStage: string;

  // Status field (kept for backward compatibility, computed from currentStage)
  @Prop({ required: true, enum: RequestStatus, default: RequestStatus.PENDING })
  status: RequestStatus;

  // Action history (separate from approval chain for better tracking)
  @Prop({ type: [ActionHistorySchema], default: [] })
  actionHistory: ActionHistory[];

  // Correction history (tracks all corrections with stage information)
  @Prop({ type: [CorrectionHistorySchema], default: [] })
  correctionHistory: CorrectionHistory[];

  // Approval chain (kept for backward compatibility)
  @Prop({ type: [ApprovalEntrySchema], default: [] })
  approvalChain: ApprovalEntry[];

  @Prop({ type: String, ref: 'User' })
  assignedDriverId?: string;

  @Prop({ type: String, ref: 'Vehicle' })
  assignedVehicleId?: string;

  @Prop({ type: String, ref: 'Office' })
  pickupOffice?: string;

  @Prop()
  estimatedDistance?: number;

  @Prop()
  estimatedFuelLitres?: number;

  @Prop()
  actualDistance?: number;

  @Prop()
  actualTime?: number;

  @Prop()
  averageSpeed?: number; // Average speed in km/h

  // Rejection fields (deprecated in favor of actionHistory, kept for backward compatibility)
  @Prop()
  rejectionReason?: string;

  @Prop()
  rejectedAt?: Date;

  @Prop({ type: String, ref: 'User' })
  rejectedBy?: string;

  // Resubmission tracking
  @Prop()
  resubmittedAt?: Date;

  // Correction fields (deprecated in favor of correctionHistory, kept for backward compatibility)
  @Prop()
  correctionNote?: string;

  @Prop()
  correctedAt?: Date;

  @Prop({ type: String, ref: 'User' })
  correctedBy?: string;

  @Prop({ enum: RequestStatus })
  sentBackToStatus?: RequestStatus;

  // Cancellation fields
  @Prop()
  cancellationReason?: string;

  @Prop()
  cancelledAt?: Date;

  @Prop({ type: String, ref: 'User' })
  cancelledBy?: string;
}

export const VehicleRequestSchema = SchemaFactory.createForClass(VehicleRequest);

