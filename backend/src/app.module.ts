import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { AppController } from './app.controller';
import { AppService } from './app.service';
import { DatabaseModule } from './database/database.module';
import { EventsModule } from './events/events.module';
import { AuthModule } from './auth/auth.module';
import { UsersModule } from './users/users.module';
import { VehiclesModule } from './vehicles/vehicles.module';
import { OfficesModule } from './offices/offices.module';
import { RequestsModule } from './requests/requests.module';
import { VehicleRequestsModule } from './requests/vehicle/vehicle-request.module';
import { IctRequestsModule } from './requests/ict/ict-request.module';
import { StoreRequestsModule } from './requests/store/store-request.module';
import { MapsModule } from './maps/maps.module';
import { AssignmentsModule } from './assignments/assignments.module';
import { TripsModule } from './trips/trips.module';
import { NotificationsModule } from './notifications/notifications.module';
import { TrackingModule } from './tracking/tracking.module';
import { DepartmentsModule } from './departments/departments.module';
import { MaintenanceModule } from './maintenance/maintenance.module';
import { FaultsModule } from './faults/faults.module';
@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      envFilePath: '.env',
    }),
    EventsModule,
    DatabaseModule,
    AuthModule,
    UsersModule,
    VehiclesModule,
    OfficesModule,
    // Register specific request modules BEFORE the generic RequestsModule
    // This ensures their more specific routes (e.g., /requests/vehicle) match before the generic :id route
    VehicleRequestsModule,
    IctRequestsModule,
    StoreRequestsModule,
    RequestsModule,
    MapsModule,
    AssignmentsModule,
    TripsModule,
    NotificationsModule,
    TrackingModule,
    DepartmentsModule,
    MaintenanceModule,
    FaultsModule,
  ],
  controllers: [AppController],
  providers: [AppService],
})
export class AppModule {}
