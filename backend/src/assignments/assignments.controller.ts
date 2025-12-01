import { Controller, Get, Post, Put, Body, Param, UseGuards, Request } from '@nestjs/common';
import { AssignmentsService } from './assignments.service';
import { AssignDriverVehicleDto } from './dto/assign-driver-vehicle.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { UserRole } from '../users/schemas/user.schema';
import { VehicleRequestService } from '../requests/vehicle/vehicle-request.service';

@Controller('assignments')
@UseGuards(JwtAuthGuard)
export class AssignmentsController {
  constructor(
    private assignmentsService: AssignmentsService,
    private vehicleRequestService: VehicleRequestService,
  ) {}

  @Get('available-drivers')
  @UseGuards(RolesGuard)
  @Roles(UserRole.TRANSPORT_OFFICER)
  async getAvailableDrivers() {
    return this.assignmentsService.getAvailableDrivers();
  }

  @Get('available-vehicles')
  @UseGuards(RolesGuard)
  @Roles(UserRole.TRANSPORT_OFFICER)
  async getAvailableVehicles() {
    return this.assignmentsService.getAvailableVehicles();
  }

  /**
   * Get drivers who are available for a specific request's time window.
   */
  @Get('available-drivers/:requestId')
  @UseGuards(RolesGuard)
  @Roles(UserRole.TRANSPORT_OFFICER, UserRole.DGS)
  async getAvailableDriversForRequest(@Param('requestId') requestId: string) {
    const request = await this.vehicleRequestService.findById(requestId);
    if (!request.startDate || !request.endDate) {
      // Fallback: if dates are missing, use the existing \"now-based\" availability
      return this.assignmentsService.getAvailableDrivers();
    }
    const startDate = new Date(request.startDate);
    const endDate = new Date(request.endDate);
    return this.assignmentsService.getAvailableDriversForWindow(startDate, endDate);
  }

  /**
   * Get vehicles that are available (no overlapping trips and sufficient capacity)
   * for the given request's time window.
   */
  @Get('available-vehicles/:requestId')
  @UseGuards(RolesGuard)
  @Roles(UserRole.TRANSPORT_OFFICER, UserRole.DGS)
  async getAvailableVehiclesForRequest(@Param('requestId') requestId: string) {
    const request = await this.vehicleRequestService.findById(requestId);
    if (!request.startDate || !request.endDate) {
      return this.assignmentsService.getAvailableVehicles();
    }
    const startDate = new Date(request.startDate);
    const endDate = new Date(request.endDate);
    const passengerCount = request.passengerCount;
    return this.assignmentsService.getAvailableVehiclesForWindow(
      startDate,
      endDate,
      passengerCount,
    );
  }

  @Post('assign')
  @UseGuards(RolesGuard)
  @Roles(UserRole.TRANSPORT_OFFICER, UserRole.DGS)
  async assign(@Body() body: { requestId: string } & AssignDriverVehicleDto, @Request() req) {
    const { requestId, ...assignDto } = body;
    return this.assignmentsService.assignDriverAndVehicle(
      requestId,
      assignDto as AssignDriverVehicleDto,
      req.user._id.toString(),
    );
  }

  @Put(':requestId/swap-driver')
  @UseGuards(RolesGuard)
  @Roles(UserRole.TRANSPORT_OFFICER)
  async swapDriver(
    @Param('requestId') requestId: string,
    @Body('driverId') newDriverId: string,
    @Request() req,
  ) {
    return this.assignmentsService.swapDriver(requestId, newDriverId, req.user._id.toString());
  }
}

