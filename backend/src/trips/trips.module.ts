import { Module } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { ScheduleModule } from '@nestjs/schedule';
import { TripsService } from './trips.service';
import { TripsController } from './trips.controller';
import { Trip, TripSchema } from './schemas/trip.schema';
import { VehicleRequestsModule } from '../requests/vehicle/vehicle-request.module';
import { MapsModule } from '../maps/maps.module';
import { OfficesModule } from '../offices/offices.module';
import { NotificationsModule } from '../notifications/notifications.module';
import { UsersModule } from '../users/users.module';
import { VehiclesModule } from '../vehicles/vehicles.module';

@Module({
  imports: [
    MongooseModule.forFeature([{ name: Trip.name, schema: TripSchema }]),
    ScheduleModule.forRoot(),
    VehicleRequestsModule,
    MapsModule,
    OfficesModule,
    NotificationsModule,
    UsersModule,
    VehiclesModule,
  ],
  controllers: [TripsController],
  providers: [TripsService],
  exports: [TripsService],
})
export class TripsModule {}

