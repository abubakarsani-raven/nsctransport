import { Controller, Get, Post, Put, Delete, Body, Param, UseGuards, Request, Query } from '@nestjs/common';
import { VehiclesService } from './vehicles.service';
import { VehicleDistanceService } from './vehicle-distance.service';
import { CreateVehicleDto } from './dto/create-vehicle.dto';
import { AssignPermanentlyDto } from './dto/assign-permanently.dto';
import { UpdatePermanentAssignmentDto } from './dto/update-permanent-assignment.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { UserRole } from '../users/schemas/user.schema';
import { VehicleStatus } from './schemas/vehicle.schema';

@Controller('vehicles')
@UseGuards(JwtAuthGuard)
export class VehiclesController {
  constructor(
    private vehiclesService: VehiclesService,
    private vehicleDistanceService: VehicleDistanceService,
  ) {}

  @Get()
  async findAll() {
    return this.vehiclesService.findAll();
  }

  @Get(':id')
  async findOne(@Param('id') id: string) {
    return this.vehiclesService.findById(id);
  }

  @Post()
  @UseGuards(RolesGuard)
  @Roles(UserRole.ADMIN, UserRole.TRANSPORT_OFFICER)
  async create(@Body() createVehicleDto: CreateVehicleDto) {
    return this.vehiclesService.create(createVehicleDto);
  }

  @Put(':id/status')
  @UseGuards(RolesGuard)
  @Roles(UserRole.ADMIN, UserRole.TRANSPORT_OFFICER)
  async updateStatus(@Param('id') id: string, @Body('status') status: VehicleStatus) {
    return this.vehiclesService.updateStatus(id, status);
  }

  @Put(':id')
  @UseGuards(RolesGuard)
  @Roles(UserRole.ADMIN, UserRole.TRANSPORT_OFFICER)
  async update(@Param('id') id: string, @Body() updateVehicleDto: any) {
    return this.vehiclesService.update(id, updateVehicleDto);
  }

  @Delete(':id')
  @UseGuards(RolesGuard)
  @Roles(UserRole.ADMIN)
  async delete(@Param('id') id: string) {
    await this.vehiclesService.delete(id);
    return { message: 'Vehicle deleted successfully' };
  }

  @Post(':id/assign-permanently')
  @UseGuards(RolesGuard)
  @Roles(UserRole.ADMIN, UserRole.TRANSPORT_OFFICER)
  async assignPermanently(@Param('id') id: string, @Body() assignDto: AssignPermanentlyDto) {
    return this.vehiclesService.assignPermanently(id, assignDto);
  }

  @Put(':id/permanent-assignment')
  @UseGuards(RolesGuard)
  @Roles(UserRole.ADMIN, UserRole.TRANSPORT_OFFICER)
  async updatePermanentAssignment(@Param('id') id: string, @Body() updateDto: UpdatePermanentAssignmentDto) {
    return this.vehiclesService.updatePermanentAssignment(id, updateDto);
  }

  @Delete(':id/permanent-assignment')
  @UseGuards(RolesGuard)
  @Roles(UserRole.ADMIN, UserRole.TRANSPORT_OFFICER)
  async removePermanentAssignment(@Param('id') id: string) {
    return this.vehiclesService.removePermanentAssignment(id);
  }

  @Get('permanently-assigned')
  async findPermanentlyAssigned() {
    return this.vehiclesService.findPermanentlyAssigned();
  }

  @Get('permanently-assigned/:userId')
  async findPermanentlyAssignedByUser(@Param('userId') userId: string) {
    return this.vehiclesService.findPermanentlyAssignedByUser(userId);
  }

  @Get('my-assigned')
  async getMyAssignedVehicle(@Request() req) {
    const userId = req.user._id.toString();
    return this.vehiclesService.findPermanentlyAssignedByUser(userId);
  }

  @Get(':id/distance')
  async getVehicleDistance(@Param('id') id: string) {
    const totalDistance = await this.vehicleDistanceService.getTotalDistance(id);
    const vehicle = await this.vehiclesService.findById(id);
    return {
      totalDistance,
      vehicle: vehicle ? {
        _id: vehicle._id,
        plateNumber: vehicle.plateNumber,
        make: vehicle.make,
        model: vehicle.model,
        lastOdometerUpdate: vehicle.lastOdometerUpdate,
      } : null,
    };
  }

  @Get(':id/distance/history')
  async getDistanceHistory(
    @Param('id') id: string,
    @Query('startDate') startDate?: string,
    @Query('endDate') endDate?: string,
  ) {
    return this.vehicleDistanceService.getDistanceHistory(
      id,
      startDate ? new Date(startDate) : undefined,
      endDate ? new Date(endDate) : undefined,
    );
  }

  @Post(':id/distance/manual')
  @UseGuards(RolesGuard)
  @Roles(UserRole.ADMIN, UserRole.TRANSPORT_OFFICER)
  async logManualDistance(
    @Param('id') id: string,
    @Body() dto: { distance: number; notes?: string },
    @Request() req,
  ) {
    return this.vehicleDistanceService.logDistance(
      id,
      dto.distance,
      'manual',
      undefined,
      req.user._id.toString(),
      dto.notes,
    );
  }
}

