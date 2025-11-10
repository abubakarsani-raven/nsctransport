import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document } from 'mongoose';
import { MaintenanceType } from './maintenance-record.schema';

export type MaintenanceReminderDocument = MaintenanceReminder & Document;

@Schema({ timestamps: true })
export class MaintenanceReminder {
  @Prop({ type: String, ref: 'Vehicle', required: true })
  vehicleId: string;

  @Prop({ required: true, enum: MaintenanceType })
  maintenanceType: MaintenanceType;

  @Prop()
  customTypeName?: string;

  @Prop({ required: true })
  reminderIntervalDays: number;

  @Prop()
  lastPerformedDate?: Date;

  @Prop()
  nextReminderDate: Date;

  @Prop({ default: true })
  isActive: boolean;

  @Prop()
  notes?: string;
}

export const MaintenanceReminderSchema = SchemaFactory.createForClass(MaintenanceReminder);

