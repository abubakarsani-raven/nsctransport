import { IsString, IsNotEmpty, IsEnum, IsOptional, IsArray } from 'class-validator';
import { FaultPriority } from '../schemas/fault-report.schema';

export class CreateFaultReportDto {
  @IsString()
  @IsNotEmpty()
  vehicleId: string;

  @IsString()
  @IsNotEmpty()
  category: string;

  @IsString()
  @IsNotEmpty()
  description: string;

  @IsArray()
  @IsString({ each: true })
  @IsOptional()
  photos?: string[];

  @IsEnum(FaultPriority)
  @IsOptional()
  priority?: FaultPriority;
}

