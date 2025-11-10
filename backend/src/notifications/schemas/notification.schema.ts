import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document } from 'mongoose';

export type NotificationDocument = Notification & Document;

export enum NotificationType {
  REQUEST_CREATED = 'request_created',
  REQUEST_APPROVED = 'request_approved',
  REQUEST_REJECTED = 'request_rejected',
  REQUEST_RESUBMITTED = 'request_resubmitted',
  REQUEST_NEEDS_CORRECTION = 'request_needs_correction',
  DRIVER_ASSIGNED = 'driver_assigned',
  TRIP_STARTED = 'trip_started',
  TRIP_COMPLETED = 'trip_completed',
  TRIP_RETURNED = 'trip_returned',
  MAINTENANCE_REMINDER = 'maintenance_reminder',
}

@Schema({ timestamps: true })
export class Notification {
  @Prop({ type: String, ref: 'User', required: true })
  userId: string;

  @Prop({ required: true, enum: NotificationType })
  type: NotificationType;

  @Prop({ required: true })
  title: string;

  @Prop({ required: true })
  message: string;

  @Prop({ type: String, ref: 'VehicleRequest' })
  relatedRequestId?: string;

  @Prop({ default: false })
  read: boolean;
}

export const NotificationSchema = SchemaFactory.createForClass(Notification);

