import { Controller, Get, Post, Put, Delete, Body, Param, UseGuards } from '@nestjs/common';
import { MaintenanceService } from './maintenance.service';
import { CreateMaintenanceRecordDto } from './dto/create-maintenance-record.dto';
import { CreateReminderDto } from './dto/create-reminder.dto';
import { UpdateMaintenanceRecordDto } from './dto/update-maintenance-record.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { UserRole } from '../users/schemas/user.schema';

@Controller('maintenance')
@UseGuards(JwtAuthGuard)
export class MaintenanceController {
  constructor(private maintenanceService: MaintenanceService) {}

  @Get('vehicles/:vehicleId/records')
  async getRecordsByVehicle(@Param('vehicleId') vehicleId: string) {
    return this.maintenanceService.getRecordsByVehicle(vehicleId);
  }

  @Post('vehicles/:vehicleId/records')
  @UseGuards(RolesGuard)
  @Roles(UserRole.ADMIN, UserRole.TRANSPORT_OFFICER)
  async createRecord(
    @Param('vehicleId') vehicleId: string,
    @Body() createDto: CreateMaintenanceRecordDto,
  ) {
    return this.maintenanceService.createRecord(vehicleId, createDto);
  }

  @Put('records/:id')
  @UseGuards(RolesGuard)
  @Roles(UserRole.ADMIN, UserRole.TRANSPORT_OFFICER)
  async updateRecord(
    @Param('id') id: string,
    @Body() updateDto: UpdateMaintenanceRecordDto,
  ) {
    return this.maintenanceService.updateRecord(id, updateDto);
  }

  @Delete('records/:id')
  @UseGuards(RolesGuard)
  @Roles(UserRole.ADMIN, UserRole.TRANSPORT_OFFICER)
  async deleteRecord(@Param('id') id: string) {
    await this.maintenanceService.deleteRecord(id);
    return { message: 'Maintenance record deleted successfully' };
  }

  @Get('vehicles/:vehicleId/reminders')
  async getRemindersByVehicle(@Param('vehicleId') vehicleId: string) {
    return this.maintenanceService.getRemindersByVehicle(vehicleId);
  }

  @Post('vehicles/:vehicleId/reminders')
  @UseGuards(RolesGuard)
  @Roles(UserRole.ADMIN, UserRole.TRANSPORT_OFFICER)
  async createReminder(
    @Param('vehicleId') vehicleId: string,
    @Body() createDto: CreateReminderDto,
  ) {
    return this.maintenanceService.createReminder(vehicleId, createDto);
  }

  @Put('reminders/:id')
  @UseGuards(RolesGuard)
  @Roles(UserRole.ADMIN, UserRole.TRANSPORT_OFFICER)
  async updateReminder(
    @Param('id') id: string,
    @Body() updateDto: Partial<CreateReminderDto>,
  ) {
    return this.maintenanceService.updateReminder(id, updateDto);
  }

  @Delete('reminders/:id')
  @UseGuards(RolesGuard)
  @Roles(UserRole.ADMIN, UserRole.TRANSPORT_OFFICER)
  async deleteReminder(@Param('id') id: string) {
    await this.maintenanceService.deleteReminder(id);
    return { message: 'Maintenance reminder deleted successfully' };
  }

  @Get('reminders/upcoming')
  async getUpcomingReminders() {
    return this.maintenanceService.getUpcomingReminders(7);
  }
}

