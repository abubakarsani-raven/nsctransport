import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document } from 'mongoose';

export type MaintenanceRecordDocument = MaintenanceRecord & Document;

export enum MaintenanceType {
  OIL_CHANGE = 'oil_change',
  TIRE_CHANGE = 'tire_change',
  BRAKE_LIGHTS = 'brake_lights',
  HEAD_LIGHTS = 'head_lights',
  BRAKE_PADS = 'brake_pads',
  GEAR_OIL_CHECK = 'gear_oil_check',
  ENGINE_FILTER = 'engine_filter',
  AIR_FILTER = 'air_filter',
  BATTERY_REPLACEMENT = 'battery_replacement',
  FLUID_CHECK = 'fluid_check',
  GENERAL_INSPECTION = 'general_inspection',
  OTHER = 'other',
}

@Schema({ timestamps: true })
export class MaintenanceRecord {
  @Prop({ type: String, ref: 'Vehicle', required: true })
  vehicleId: string;

  @Prop({ required: true, enum: MaintenanceType })
  maintenanceType: MaintenanceType;

  @Prop()
  customTypeName?: string;

  @Prop()
  description?: string;

  @Prop({ required: true })
  performedAt: Date;

  @Prop()
  availableUntil?: Date;

  @Prop()
  quantity?: number;

  @Prop({ type: String, ref: 'User' })
  performedBy?: string;

  @Prop()
  cost?: number;
}

export const MaintenanceRecordSchema = SchemaFactory.createForClass(MaintenanceRecord);

