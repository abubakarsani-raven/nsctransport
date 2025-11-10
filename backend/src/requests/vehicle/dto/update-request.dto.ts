import { IsString, IsDateString, IsNumber, Min, IsOptional } from 'class-validator';

export class UpdateRequestDto {
  @IsOptional()
  @IsString()
  originOffice?: string;

  @IsOptional()
  @IsString()
  destination?: string;

  @IsOptional()
  destinationCoordinates?: {
    lat: number;
    lng: number;
  };

  @IsOptional()
  @IsDateString()
  startDate?: string;

  @IsOptional()
  @IsDateString()
  endDate?: string;

  @IsOptional()
  @IsString()
  purpose?: string;

  @IsOptional()
  @IsNumber()
  @Min(1)
  passengerCount?: number;

  @IsOptional()
  @IsString()
  supervisorId?: string;
}





