import { IsString, IsOptional, IsEnum } from 'class-validator';
import { FaultStatus } from '../schemas/fault-report.schema';

export class UpdateFaultReportDto {
  @IsEnum(FaultStatus)
  @IsOptional()
  status?: FaultStatus;

  @IsString()
  @IsOptional()
  resolutionNotes?: string;
}

