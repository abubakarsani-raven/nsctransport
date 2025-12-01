import { Module } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { VehiclesService } from './vehicles.service';
import { VehiclesController } from './vehicles.controller';
import { Vehicle, VehicleSchema } from './schemas/vehicle.schema';
import { VehicleDistanceLog, VehicleDistanceLogSchema } from './schemas/vehicle-distance-log.schema';
import { VehicleDistanceService } from './vehicle-distance.service';
import { UsersModule } from '../users/users.module';

@Module({
  imports: [
    MongooseModule.forFeature([
      { name: Vehicle.name, schema: VehicleSchema },
      { name: VehicleDistanceLog.name, schema: VehicleDistanceLogSchema },
    ]),
    UsersModule,
  ],
  controllers: [VehiclesController],
  providers: [VehiclesService, VehicleDistanceService],
  exports: [VehiclesService, VehicleDistanceService],
})
export class VehiclesModule {}

