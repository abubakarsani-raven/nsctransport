import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document } from 'mongoose';
import { WorkflowAction } from '../../../workflow/schemas/workflow-actions.enum';

export type ActionHistoryDocument = ActionHistory & Document;

@Schema()
export class ActionHistory {
  @Prop({ required: true, enum: WorkflowAction })
  action: WorkflowAction;

  @Prop({ type: String, ref: 'User', required: true })
  performedBy: string;

  @Prop({ required: true })
  performedAt: Date;

  @Prop({ required: true })
  stage: string;

  @Prop()
  notes?: string;

  @Prop({ type: Object })
  metadata?: Record<string, any>;
}

export const ActionHistorySchema = SchemaFactory.createForClass(ActionHistory);

