import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document } from 'mongoose';

export type FaultReportDocument = FaultReport & Document;

export enum FaultPriority {
  LOW = 'low',
  MEDIUM = 'medium',
  HIGH = 'high',
  CRITICAL = 'critical',
}

export enum FaultStatus {
  REPORTED = 'reported',
  IN_PROGRESS = 'in_progress',
  RESOLVED = 'resolved',
  CLOSED = 'closed',
}

@Schema({ timestamps: true })
export class FaultReport {
  @Prop({ type: String, ref: 'Vehicle', required: true })
  vehicleId: string;

  @Prop({ type: String, ref: 'User', required: true })
  reportedBy: string;

  @Prop({ required: true })
  category: string; // engine, brakes, tires, electrical, body, other

  @Prop({ required: true })
  description: string;

  @Prop({ type: [String], default: [] })
  photos?: string[];

  @Prop({ required: true, enum: FaultPriority, default: FaultPriority.MEDIUM })
  priority: FaultPriority;

  @Prop({ required: true, enum: FaultStatus, default: FaultStatus.REPORTED })
  status: FaultStatus;

  @Prop()
  resolvedAt?: Date;

  @Prop({ type: String, ref: 'User' })
  resolvedBy?: string;

  @Prop()
  resolutionNotes?: string;
}

export const FaultReportSchema = SchemaFactory.createForClass(FaultReport);

