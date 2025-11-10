import { Injectable, NotFoundException, BadRequestException } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model, isValidObjectId } from 'mongoose';
import { Cron, CronExpression } from '@nestjs/schedule';
import { MaintenanceRecord, MaintenanceRecordDocument } from './schemas/maintenance-record.schema';
import { MaintenanceReminder, MaintenanceReminderDocument } from './schemas/maintenance-reminder.schema';
import { CreateMaintenanceRecordDto } from './dto/create-maintenance-record.dto';
import { CreateReminderDto } from './dto/create-reminder.dto';
import { UpdateMaintenanceRecordDto } from './dto/update-maintenance-record.dto';
import { VehiclesService } from '../vehicles/vehicles.service';
import { VehicleStatus } from '../vehicles/schemas/vehicle.schema';
import { NotificationsService } from '../notifications/notifications.service';
import { NotificationType } from '../notifications/schemas/notification.schema';
import { UsersService } from '../users/users.service';
import { UserRole } from '../users/schemas/user.schema';

@Injectable()
export class MaintenanceService {
  constructor(
    @InjectModel(MaintenanceRecord.name) private maintenanceRecordModel: Model<MaintenanceRecordDocument>,
    @InjectModel(MaintenanceReminder.name) private maintenanceReminderModel: Model<MaintenanceReminderDocument>,
    private vehiclesService: VehiclesService,
    private notificationsService: NotificationsService,
    private usersService: UsersService,
  ) {}

  async getRecordsByVehicle(vehicleId: string): Promise<MaintenanceRecordDocument[]> {
    if (!isValidObjectId(vehicleId)) {
      throw new BadRequestException('Invalid vehicle ID');
    }
    return this.maintenanceRecordModel.find({ vehicleId })
      .populate('performedBy', 'name email')
      .sort({ performedAt: -1 })
      .exec();
  }

  async getRemindersByVehicle(vehicleId: string): Promise<MaintenanceReminderDocument[]> {
    if (!isValidObjectId(vehicleId)) {
      throw new BadRequestException('Invalid vehicle ID');
    }
    return this.maintenanceReminderModel.find({ vehicleId })
      .sort({ nextReminderDate: 1 })
      .exec();
  }

  async createRecord(vehicleId: string, createDto: CreateMaintenanceRecordDto): Promise<MaintenanceRecordDocument> {
    if (!isValidObjectId(vehicleId)) {
      throw new BadRequestException('Invalid vehicle ID');
    }

    // Validate date relationship
    if (createDto.availableUntil && createDto.availableUntil < createDto.performedAt) {
      throw new BadRequestException('Available Until date must be greater than or equal to Performed At date');
    }

    const vehicle = await this.vehiclesService.findById(vehicleId);
    if (!vehicle) {
      throw new NotFoundException('Vehicle not found');
    }

    const record = new this.maintenanceRecordModel({
      ...createDto,
      vehicleId,
    });

    const savedRecord = await record.save();

    // Auto-update vehicle status to MAINTENANCE if "available until" is in the future
    if (createDto.availableUntil && new Date(createDto.availableUntil) > new Date()) {
      await this.vehiclesService.updateStatus(vehicleId, VehicleStatus.MAINTENANCE);
    }

    // Update reminder's last performed date if there's a matching reminder
    await this.updateReminderAfterMaintenance(vehicleId, createDto.maintenanceType, createDto.performedAt);

    return savedRecord.populate('performedBy', 'name email');
  }

  async updateRecord(id: string, updateDto: UpdateMaintenanceRecordDto): Promise<MaintenanceRecordDocument> {
    if (!isValidObjectId(id)) {
      throw new BadRequestException('Invalid record ID');
    }

    // Get existing record to check date relationships
    const existingRecord = await this.maintenanceRecordModel.findById(id).exec();
    if (!existingRecord) {
      throw new NotFoundException('Maintenance record not found');
    }

    // Validate date relationship
    const performedAt = updateDto.performedAt || existingRecord.performedAt;
    const availableUntil = updateDto.availableUntil !== undefined ? updateDto.availableUntil : existingRecord.availableUntil;
    
    if (availableUntil && performedAt && availableUntil < performedAt) {
      throw new BadRequestException('Available Until date must be greater than or equal to Performed At date');
    }

    const record = await this.maintenanceRecordModel.findByIdAndUpdate(id, updateDto, { new: true })
      .populate('performedBy', 'name email')
      .exec();

    if (!record) {
      throw new NotFoundException('Maintenance record not found');
    }

    // Update vehicle status if availableUntil changed
    if (updateDto.availableUntil !== undefined) {
      const now = new Date();
      const availableUntil = new Date(updateDto.availableUntil);
      const vehicle = await this.vehiclesService.findById(record.vehicleId.toString());

      if (vehicle) {
        if (availableUntil > now) {
          await this.vehiclesService.updateStatus(record.vehicleId.toString(), VehicleStatus.MAINTENANCE);
        } else if (vehicle.status === VehicleStatus.MAINTENANCE) {
          // Check if there are other active maintenance records
          const activeRecords = await this.maintenanceRecordModel.find({
            vehicleId: record.vehicleId,
            availableUntil: { $gt: now },
          }).exec();

          if (activeRecords.length === 0) {
            await this.vehiclesService.updateStatus(record.vehicleId.toString(), VehicleStatus.AVAILABLE);
          }
        }
      }
    }

    return record;
  }

  async deleteRecord(id: string): Promise<void> {
    if (!isValidObjectId(id)) {
      throw new BadRequestException('Invalid record ID');
    }

    const record = await this.maintenanceRecordModel.findById(id).exec();
    if (!record) {
      throw new NotFoundException('Maintenance record not found');
    }

    await this.maintenanceRecordModel.findByIdAndDelete(id).exec();

    // Check if vehicle status should be updated
    const vehicle = await this.vehiclesService.findById(record.vehicleId.toString());
    if (vehicle && vehicle.status === VehicleStatus.MAINTENANCE) {
      const now = new Date();
      const activeRecords = await this.maintenanceRecordModel.find({
        vehicleId: record.vehicleId,
        availableUntil: { $gt: now },
      }).exec();

      if (activeRecords.length === 0) {
        await this.vehiclesService.updateStatus(record.vehicleId.toString(), VehicleStatus.AVAILABLE);
      }
    }
  }

  async createReminder(vehicleId: string, createDto: CreateReminderDto): Promise<MaintenanceReminderDocument> {
    if (!isValidObjectId(vehicleId)) {
      throw new BadRequestException('Invalid vehicle ID');
    }

    const vehicle = await this.vehiclesService.findById(vehicleId);
    if (!vehicle) {
      throw new NotFoundException('Vehicle not found');
    }

    // Calculate next reminder date
    const nextReminderDate = createDto.lastPerformedDate
      ? new Date(createDto.lastPerformedDate.getTime() + createDto.reminderIntervalDays * 24 * 60 * 60 * 1000)
      : new Date(Date.now() + createDto.reminderIntervalDays * 24 * 60 * 60 * 1000);

    const reminder = new this.maintenanceReminderModel({
      ...createDto,
      vehicleId,
      nextReminderDate,
      isActive: createDto.isActive !== undefined ? createDto.isActive : true,
    });

    return reminder.save();
  }

  async updateReminder(id: string, updateDto: Partial<CreateReminderDto>): Promise<MaintenanceReminderDocument> {
    if (!isValidObjectId(id)) {
      throw new BadRequestException('Invalid reminder ID');
    }

    const reminder = await this.maintenanceReminderModel.findById(id).exec();
    if (!reminder) {
      throw new NotFoundException('Maintenance reminder not found');
    }

    // Recalculate next reminder date if interval or last performed date changed
    if (updateDto.reminderIntervalDays !== undefined || updateDto.lastPerformedDate !== undefined) {
      const intervalDays = updateDto.reminderIntervalDays ?? reminder.reminderIntervalDays;
      const lastPerformed = updateDto.lastPerformedDate ?? reminder.lastPerformedDate;

      if (lastPerformed) {
        reminder.nextReminderDate = new Date(lastPerformed.getTime() + intervalDays * 24 * 60 * 60 * 1000);
      } else {
        reminder.nextReminderDate = new Date(Date.now() + intervalDays * 24 * 60 * 60 * 1000);
      }
    }

    Object.assign(reminder, updateDto);
    return reminder.save();
  }

  async deleteReminder(id: string): Promise<void> {
    if (!isValidObjectId(id)) {
      throw new BadRequestException('Invalid reminder ID');
    }

    const result = await this.maintenanceReminderModel.findByIdAndDelete(id).exec();
    if (!result) {
      throw new NotFoundException('Maintenance reminder not found');
    }
  }

  async getUpcomingReminders(daysAhead: number = 7): Promise<MaintenanceReminderDocument[]> {
    const now = new Date();
    const futureDate = new Date(now.getTime() + daysAhead * 24 * 60 * 60 * 1000);

    return this.maintenanceReminderModel.find({
      isActive: true,
      nextReminderDate: { $gte: now, $lte: futureDate },
    })
      .populate('vehicleId', 'plateNumber make model')
      .sort({ nextReminderDate: 1 })
      .exec();
  }

  private async updateReminderAfterMaintenance(
    vehicleId: string,
    maintenanceType: string,
    performedAt: Date,
  ): Promise<void> {
    const reminders = await this.maintenanceReminderModel.find({
      vehicleId,
      maintenanceType,
      isActive: true,
    }).exec();

    for (const reminder of reminders) {
      reminder.lastPerformedDate = performedAt;
      reminder.nextReminderDate = new Date(
        performedAt.getTime() + reminder.reminderIntervalDays * 24 * 60 * 60 * 1000,
      );
      await reminder.save();
    }
  }

  @Cron(CronExpression.EVERY_DAY_AT_MIDNIGHT)
  async checkAndUpdateVehicleStatus(): Promise<void> {
    const now = new Date();
    const records = await this.maintenanceRecordModel.find({
      availableUntil: { $lte: now },
    }).exec();

    const vehicleIds = [...new Set(records.map(r => r.vehicleId.toString()))];

    for (const vehicleId of vehicleIds) {
      const vehicle = await this.vehiclesService.findById(vehicleId);
      if (vehicle && vehicle.status === VehicleStatus.MAINTENANCE) {
        // Check if there are any active maintenance records
        const activeRecords = await this.maintenanceRecordModel.find({
          vehicleId,
          availableUntil: { $gt: now },
        }).exec();

        if (activeRecords.length === 0) {
          await this.vehiclesService.updateStatus(vehicleId, VehicleStatus.AVAILABLE);
        }
      }
    }
  }

  @Cron(CronExpression.EVERY_DAY_AT_9AM)
  async checkReminders(): Promise<void> {
    const now = new Date();
    const tomorrow = new Date(now.getTime() + 24 * 60 * 60 * 1000);

    const dueReminders = await this.maintenanceReminderModel.find({
      isActive: true,
      nextReminderDate: { $gte: now, $lte: tomorrow },
    })
      .populate('vehicleId')
      .exec();

    for (const reminder of dueReminders) {
      const vehicle = reminder.vehicleId as any;
      if (!vehicle) continue;

      await this.notifyDriversForReminder(reminder, vehicle);
    }
  }

  private async notifyDriversForReminder(
    reminder: MaintenanceReminderDocument,
    vehicle: any,
  ): Promise<void> {
    const maintenanceTypeLabel = reminder.customTypeName || 
      reminder.maintenanceType.replace(/_/g, ' ').replace(/\b\w/g, l => l.toUpperCase());

    const message = `Vehicle ${vehicle.plateNumber} (${vehicle.make} ${vehicle.model}) requires ${maintenanceTypeLabel} maintenance. Next reminder date: ${reminder.nextReminderDate.toLocaleDateString()}`;

    // Get assigned driver if vehicle has permanent assignment
    if (vehicle.permanentlyAssignedDriverId) {
      const driver = await this.usersService.findById(vehicle.permanentlyAssignedDriverId.toString());
      if (driver) {
        await this.notificationsService.sendNotification(
          (driver._id as any).toString(),
          NotificationType.MAINTENANCE_REMINDER,
          'Vehicle Maintenance Reminder',
          `Vehicle ${vehicle.plateNumber} is due for maintenance.`,
        );
      }
    } else {
      // Notify all drivers if no specific assignment
      const drivers = await this.usersService.findByRole(UserRole.DRIVER);

      for (const driver of drivers) {
        await this.notificationsService.sendNotification(
          (driver._id as any).toString(),
          NotificationType.MAINTENANCE_REMINDER,
          'Vehicle Maintenance Reminder',
          `Vehicle ${vehicle.plateNumber} is due for maintenance.`,
        );
      }
    }
  }
}

