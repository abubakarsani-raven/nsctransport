import { IsString, IsNotEmpty } from 'class-validator';

export class AssignDriverVehicleDto {
  @IsString()
  @IsNotEmpty()
  driverId: string;

  @IsString()
  @IsNotEmpty()
  vehicleId: string;

  @IsString()
  @IsNotEmpty()
  pickupOfficeId: string;
}

