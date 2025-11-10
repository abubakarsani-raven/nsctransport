import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document } from 'mongoose';

export type CorrectionHistoryDocument = CorrectionHistory & Document;

@Schema()
export class CorrectionHistory {
  @Prop({ required: true })
  stage: string;

  @Prop({ type: String, ref: 'User', required: true })
  requestedBy: string;

  @Prop({ required: true, default: Date.now })
  requestedAt: Date;

  @Prop({ required: true })
  correctionNote: string;

  @Prop()
  resolvedAt?: Date;

  @Prop({ default: 1 })
  resubmissionCount: number;
}

export const CorrectionHistorySchema = SchemaFactory.createForClass(CorrectionHistory);

