import { IsEnum, IsString, IsDate, IsOptional, IsNumber, IsNotEmpty, ValidateIf } from 'class-validator';
import { Type } from 'class-transformer';
import { MaintenanceType } from '../schemas/maintenance-record.schema';
import { IsDateAfterOrEqual } from './validators/date-comparison.validator';

export class CreateMaintenanceRecordDto {
  @IsEnum(MaintenanceType)
  @IsNotEmpty()
  maintenanceType: MaintenanceType;

  @IsString()
  @IsOptional()
  customTypeName?: string;

  @IsString()
  @IsOptional()
  description?: string;

  @IsDate()
  @Type(() => Date)
  @IsNotEmpty()
  performedAt: Date;

  @IsDate()
  @Type(() => Date)
  @IsOptional()
  @ValidateIf((o) => o.availableUntil !== undefined && o.availableUntil !== null)
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

