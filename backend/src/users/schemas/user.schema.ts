import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document } from 'mongoose';

export type UserDocument = User & Document;

export enum UserRole {
  STAFF = 'staff',
  DRIVER = 'driver',
  TRANSPORT_OFFICER = 'transport_officer',
  ADMIN = 'admin',
  DGS = 'dgs',
  DDGS = 'ddgs',
  AD_TRANSPORT = 'ad_transport',
}

@Schema({ timestamps: true })
export class User {
  @Prop({ required: true, unique: true })
  email: string;

  @Prop({ required: true })
  password: string;

  @Prop({ required: true })
  name: string;

  @Prop({ required: true })
  phone: string;

  @Prop({ type: [String], enum: UserRole, default: [UserRole.STAFF] })
  roles: UserRole[];

  @Prop()
  department?: string;

  @Prop({ default: false })
  isSupervisor: boolean;

  @Prop({ type: String, ref: 'User' })
  supervisorId?: string;

  @Prop({ unique: true })
  employeeId?: string;
}

export const UserSchema = SchemaFactory.createForClass(User);

