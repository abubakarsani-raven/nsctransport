import { Module } from '@nestjs/common';
import { TrackingGateway } from './tracking.gateway';
import { TrackingService } from './tracking.service';
import { TrackingController } from './tracking.controller';
import { TripsModule } from '../trips/trips.module';
import { VehiclesModule } from '../vehicles/vehicles.module';
import { UsersModule } from '../users/users.module';
import { VehicleRequestsModule } from '../requests/vehicle/vehicle-request.module';
import { JwtModule } from '@nestjs/jwt';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { NotificationsModule } from '../notifications/notifications.module';

@Module({
  imports: [
    TripsModule,
    VehiclesModule,
    UsersModule,
    VehicleRequestsModule,
    NotificationsModule,
    ConfigModule,
    JwtModule.registerAsync({
      useFactory: async (configService: ConfigService) => ({
        secret: configService.get<string>('JWT_SECRET') || 'your-secret-key-change-in-production',
      }),
      inject: [ConfigService],
    }),
  ],
  controllers: [TrackingController],
  providers: [TrackingGateway, TrackingService],
})
export class TrackingModule {}

