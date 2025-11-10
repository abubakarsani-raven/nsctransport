import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document } from 'mongoose';

export type OfficeDocument = Office & Document;

@Schema({ timestamps: true })
export class Office {
  @Prop({ required: true })
  name: string;

  @Prop({ required: true })
  address: string;

  @Prop({
    type: {
      lat: Number,
      lng: Number,
    },
    required: true,
  })
  coordinates: {
    lat: number;
    lng: number;
  };

  @Prop({ default: false })
  isHeadOffice: boolean;
}

export const OfficeSchema = SchemaFactory.createForClass(Office);

