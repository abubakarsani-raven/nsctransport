import { IsEnum, IsString, IsDate, IsOptional, IsNumber, ValidateIf } from 'class-validator';
import { Type } from 'class-transformer';
import { MaintenanceType } from '../schemas/maintenance-record.schema';
import { IsDateAfterOrEqual } from './validators/date-comparison.validator';

export class UpdateMaintenanceRecordDto {
  @IsEnum(MaintenanceType)
  @IsOptional()
  maintenanceType?: MaintenanceType;

  @IsString()
  @IsOptional()
  customTypeName?: string;

  @IsString()
  @IsOptional()
  description?: string;

  @IsDate()
  @Type(() => Date)
  @IsOptional()
  performedAt?: Date;

  @IsDate()
  @Type(() => Date)
  @IsOptional()
  @ValidateIf((o) => o.availableUntil !== undefined && o.availableUntil !== null && o.performedAt !== undefined && o.performedAt !== null)
  @IsDateAfterOrEqual('performedAt', {
    message: 'Available Until date must be greater than or equal to Performed At date',
  })
  availableUntil?: Date;

  @IsNumber()
  @IsOptional()
  quantity?: number;

  @IsString()
  @IsOptional()
  performedBy?: string;

  @IsNumber()
  @IsOptional()
  cost?: number;
}

