import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document } from 'mongoose';

export type NotificationDeviceTokenDocument = NotificationDeviceToken & Document;

@Schema({ timestamps: true })
export class NotificationDeviceToken {
  @Prop({ type: String, ref: 'User', required: true, index: true })
  userId: string;

  @Prop({ required: true, unique: true })
  token: string;

  @Prop({ required: true, enum: ['android', 'ios', 'web'] })
  platform: string;

  @Prop()
  deviceName?: string;

  @Prop({ default: Date.now })
  lastUsedAt: Date;
}

export const NotificationDeviceTokenSchema = SchemaFactory.createForClass(NotificationDeviceToken);

// Create compound index for userId and token
NotificationDeviceTokenSchema.index({ userId: 1, token: 1 }, { unique: true });

