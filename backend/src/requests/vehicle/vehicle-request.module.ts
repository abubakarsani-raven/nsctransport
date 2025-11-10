import { Module } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { VehicleRequestService } from './vehicle-request.service';
import { VehicleRequestController } from './vehicle-request.controller';
import { VehicleRequest, VehicleRequestSchema } from './schemas/vehicle-request.schema';
import { UsersModule } from '../../users/users.module';
import { NotificationsModule } from '../../notifications/notifications.module';
import { MapsModule } from '../../maps/maps.module';
import { OfficesModule } from '../../offices/offices.module';
import { WorkflowModule } from '../../workflow/workflow.module';

@Module({
  imports: [
    MongooseModule.forFeature([{ name: VehicleRequest.name, schema: VehicleRequestSchema }]),
    UsersModule,
    NotificationsModule,
    MapsModule,
    OfficesModule,
    WorkflowModule,
  ],
  controllers: [VehicleRequestController],
  providers: [VehicleRequestService],
  exports: [VehicleRequestService],
})
export class VehicleRequestsModule {}

