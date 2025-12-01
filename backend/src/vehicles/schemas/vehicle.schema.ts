import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document } from 'mongoose';

export type VehicleDocument = Vehicle & Document;

export enum VehicleStatus {
  AVAILABLE = 'available',
  ASSIGNED = 'assigned',
  MAINTENANCE = 'maintenance',
  PERMANENTLY_ASSIGNED = 'permanently_assigned',
}

@Schema({ timestamps: true })
export class Vehicle {
  @Prop({ required: true, unique: true })
  plateNumber: string;

  @Prop({ required: true })
  make: string;

  @Prop({ required: true })
  model: string;

  @Prop({ required: true })
  year: number;

  @Prop({ required: true })
  capacity: number;

  @Prop({ required: true, enum: VehicleStatus, default: VehicleStatus.AVAILABLE })
  status: VehicleStatus;

  @Prop({
    type: {
      lat: Number,
      lng: Number,
    },
  })
  currentLocation?: {
    lat: number;
    lng: number;
  };

  @Prop({
    type: {
      lat: Number,
      lng: Number,
    },
  })
  officeLocation?: {
    lat: number;
    lng: number;
  };

  @Prop({ type: String, ref: 'User' })
  permanentlyAssignedToUserId?: string;

  @Prop({ type: String, ref: 'User' })
  permanentlyAssignedDriverId?: string;

  @Prop()
  permanentAssignmentPosition?: string;

  @Prop()
  permanentAssignmentNotes?: string;

  @Prop({ default: 0 })
  totalDistanceTravelled?: number; // Total distance in kilometers (cumulative)

  @Prop()
  initialOdometerReading?: number; // Initial odometer when vehicle was added

  @Prop()
  lastOdometerUpdate?: Date; // Last time distance was updated

  @Prop()
  lastRecordedDistance?: number; // Last recorded distance value
}

export const VehicleSchema = SchemaFactory.createForClass(Vehicle);

