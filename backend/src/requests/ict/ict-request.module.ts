import { Module } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { IctRequestService } from './ict-request.service';
import { IctRequestController } from './ict-request.controller';
import { IctRequest, IctRequestSchema } from './schemas/ict-request.schema';
import { UsersModule } from '../../users/users.module';
import { NotificationsModule } from '../../notifications/notifications.module';

@Module({
  imports: [
    MongooseModule.forFeature([{ name: IctRequest.name, schema: IctRequestSchema }]),
    UsersModule,
    NotificationsModule,
  ],
  controllers: [IctRequestController],
  providers: [IctRequestService],
  exports: [IctRequestService],
})
export class IctRequestsModule {}

