import { IsString, IsOptional } from 'class-validator';

export class UpdatePermanentAssignmentDto {
  @IsString()
  @IsOptional()
  userId?: string;

  @IsString()
  @IsOptional()
  driverId?: string;

  @IsString()
  @IsOptional()
  position?: string;

  @IsString()
  @IsOptional()
  notes?: string;
}












