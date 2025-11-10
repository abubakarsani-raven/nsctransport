import { IsString, IsNotEmpty, IsDateString, IsNumber, Min, IsOptional, IsArray, ArrayMinSize } from 'class-validator';

export class CreateRequestDto {
  @IsString()
  @IsNotEmpty()
  originOffice: string;

  @IsString()
  @IsNotEmpty()
  destination: string;

  @IsOptional()
  destinationCoordinates?: {
    lat: number;
    lng: number;
  };

  @IsDateString()
  @IsNotEmpty()
  startDate: string;

  @IsDateString()
  @IsNotEmpty()
  endDate: string;

  @IsString()
  @IsNotEmpty()
  purpose: string;

  @IsNumber()
  @Min(1)
  @IsNotEmpty()
  passengerCount: number;

  @IsOptional()
  @IsString()
  supervisorId?: string;

  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  participantIds?: string[];
}

