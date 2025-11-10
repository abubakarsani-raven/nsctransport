import { IsString, IsNotEmpty, IsOptional } from 'class-validator';

export class AssignPermanentlyDto {
  @IsString()
  @IsNotEmpty()
  userId: string;

  @IsString()
  @IsNotEmpty()
  driverId: string;

  @IsString()
  @IsNotEmpty()
  position: string;

  @IsString()
  @IsOptional()
  notes?: string;
}







