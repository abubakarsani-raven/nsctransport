import { Module } from '@nestjs/common';
import { AssignmentsService } from './assignments.service';
import { AssignmentsController } from './assignments.controller';
import { VehicleRequestsModule } from '../requests/vehicle/vehicle-request.module';
import { VehiclesModule } from '../vehicles/vehicles.module';
import { UsersModule } from '../users/users.module';
import { TripsModule } from '../trips/trips.module';
import { NotificationsModule } from '../notifications/notifications.module';
import { OfficesModule } from '../offices/offices.module';

@Module({
  imports: [
    VehicleRequestsModule,
    VehiclesModule,
    UsersModule,
    TripsModule,
    NotificationsModule,
    OfficesModule,
  ],
  controllers: [AssignmentsController],
  providers: [AssignmentsService],
  exports: [AssignmentsService],
})
export class AssignmentsModule {}

