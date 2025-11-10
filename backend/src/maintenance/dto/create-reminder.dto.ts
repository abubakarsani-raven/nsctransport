import { IsEnum, IsString, IsNumber, IsOptional, IsBoolean, IsDate, IsNotEmpty } from 'class-validator';
import { Type } from 'class-transformer';
import { MaintenanceType } from '../schemas/maintenance-record.schema';

export class CreateReminderDto {
  @IsEnum(MaintenanceType)
  @IsNotEmpty()
  maintenanceType: MaintenanceType;

  @IsString()
  @IsOptional()
  customTypeName?: string;

  @IsNumber()
  @IsNotEmpty()
  reminderIntervalDays: number;

  @IsDate()
  @Type(() => Date)
  @IsOptional()
  lastPerformedDate?: Date;

  @IsBoolean()
  @IsOptional()
  isActive?: boolean;

  @IsString()
  @IsOptional()
  notes?: string;
}

