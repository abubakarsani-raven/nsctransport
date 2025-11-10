import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document } from 'mongoose';

export type TripDocument = Trip & Document;

export enum TripStatus {
  PENDING = 'pending',
  IN_PROGRESS = 'in_progress',
  COMPLETED = 'completed',
  RETURNED = 'returned',
}

@Schema({ timestamps: true })
export class Trip {
  @Prop({ type: String, ref: 'VehicleRequest', required: true })
  requestId: string;

  @Prop({ type: String, ref: 'User', required: true })
  driverId: string;

  @Prop({ type: String, ref: 'Vehicle', required: true })
  vehicleId: string;

  @Prop({
    type: {
      lat: Number,
      lng: Number,
      address: String,
    },
    required: true,
  })
  startLocation: {
    lat: number;
    lng: number;
    address: string;
  };

  @Prop({
    type: {
      lat: Number,
      lng: Number,
      address: String,
    },
    required: true,
  })
  endLocation: {
    lat: number;
    lng: number;
    address: string;
  };

  @Prop()
  startTime?: Date;

  @Prop()
  endTime?: Date;

  @Prop()
  returnTime?: Date;

  @Prop()
  distance?: number;

  @Prop()
  duration?: number;

  @Prop({
    type: [
      {
        lat: Number,
        lng: Number,
        timestamp: Date,
      },
    ],
    default: [],
  })
  route: Array<{
    lat: number;
    lng: number;
    timestamp: Date;
  }>;

  @Prop({ required: true, enum: TripStatus, default: TripStatus.PENDING })
  status: TripStatus;
}

export const TripSchema = SchemaFactory.createForClass(Trip);

