import { Module } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { StoreRequestService } from './store-request.service';
import { StoreRequestController } from './store-request.controller';
import { StoreRequest, StoreRequestSchema } from './schemas/store-request.schema';
import { UsersModule } from '../../users/users.module';
import { NotificationsModule } from '../../notifications/notifications.module';

@Module({
  imports: [
    MongooseModule.forFeature([{ name: StoreRequest.name, schema: StoreRequestSchema }]),
    UsersModule,
    NotificationsModule,
  ],
  controllers: [StoreRequestController],
  providers: [StoreRequestService],
  exports: [StoreRequestService],
})
export class StoreRequestsModule {}

