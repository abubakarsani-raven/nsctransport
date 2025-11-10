import { Module } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { ScheduleModule } from '@nestjs/schedule';
import { MaintenanceService } from './maintenance.service';
import { MaintenanceController } from './maintenance.controller';
import { MaintenanceRecord, MaintenanceRecordSchema } from './schemas/maintenance-record.schema';
import { MaintenanceReminder, MaintenanceReminderSchema } from './schemas/maintenance-reminder.schema';
import { VehiclesModule } from '../vehicles/vehicles.module';
import { NotificationsModule } from '../notifications/notifications.module';
import { UsersModule } from '../users/users.module';

@Module({
  imports: [
    MongooseModule.forFeature([
      { name: MaintenanceRecord.name, schema: MaintenanceRecordSchema },
      { name: MaintenanceReminder.name, schema: MaintenanceReminderSchema },
    ]),
    ScheduleModule.forRoot(),
    VehiclesModule,
    NotificationsModule,
    UsersModule,
  ],
  controllers: [MaintenanceController],
  providers: [MaintenanceService],
  exports: [MaintenanceService],
})
export class MaintenanceModule {}

