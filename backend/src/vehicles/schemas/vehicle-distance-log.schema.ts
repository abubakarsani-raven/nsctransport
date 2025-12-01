import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document } from 'mongoose';

export type VehicleDistanceLogDocument = VehicleDistanceLog & Document;

@Schema({ timestamps: true })
export class VehicleDistanceLog {
  @Prop({ type: String, ref: 'Vehicle', required: true })
  vehicleId: string;

  @Prop({ required: true })
  distance: number; // Distance in kilometers

  @Prop({ required: true })
  cumulativeDistance: number; // Total distance after this entry

  @Prop({ type: String, ref: 'Trip' })
  tripId?: string; // If distance came from a trip

  @Prop({ type: String, ref: 'User' })
  recordedBy?: string; // User who recorded this (driver or admin)

  @Prop({ required: true })
  source: 'trip' | 'manual' | 'odometer'; // How distance was recorded

  @Prop()
  notes?: string; // Optional notes

  @Prop({ required: true })
  recordedAt: Date;
}

export const VehicleDistanceLogSchema = SchemaFactory.createForClass(VehicleDistanceLog);

