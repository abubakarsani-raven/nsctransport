import { Controller, Get, Post, Put, Body, Param, UseGuards, Request } from '@nestjs/common';
import { AssignmentsService } from './assignments.service';
import { AssignDriverVehicleDto } from './dto/assign-driver-vehicle.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { UserRole } from '../users/schemas/user.schema';

@Controller('assignments')
@UseGuards(JwtAuthGuard)
export class AssignmentsController {
  constructor(private assignmentsService: AssignmentsService) {}

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

  @Post('assign')
  @UseGuards(RolesGuard)
  @Roles(UserRole.TRANSPORT_OFFICER)
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

