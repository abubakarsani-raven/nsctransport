import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document } from 'mongoose';

export type CorrectionHistoryDocument = CorrectionHistory & Document;

@Schema()
export class CorrectionHistory {
  @Prop({ required: true })
  stage: string; // Stage where correction was requested

  @Prop({ type: String, ref: 'User', required: true })
  requestedBy: string; // User who requested the correction

  @Prop({ required: true, default: Date.now })
  requestedAt: Date;

  @Prop({ required: true })
  correctionNote: string; // Note explaining what needs to be corrected

  @Prop()
  resolvedAt?: Date; // When the correction was resolved (resubmitted)

  @Prop({ default: 1 })
  resubmissionCount: number; // How many times corrected at this stage
}

export const CorrectionHistorySchema = SchemaFactory.createForClass(CorrectionHistory);

