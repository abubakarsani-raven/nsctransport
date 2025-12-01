import { Controller, Get, Post, Body, Param, UseGuards, Request } from '@nestjs/common';
import { TripsService } from './trips.service';
import { UpdateLocationDto } from './dto/update-location.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { UserRole } from '../users/schemas/user.schema';

@Controller('trips')
@UseGuards(JwtAuthGuard)
export class TripsController {
  constructor(private tripsService: TripsService) {}

  @Post('start')
  async startTrip(@Body('tripId') tripId: string, @Request() req) {
    // Pass driverId to verify authorization - only the assigned driver can start the trip
    return this.tripsService.startTrip(tripId, req.user._id.toString());
  }

  @Post(':id/location')
  async updateLocation(
    @Param('id') tripId: string,
    @Body() locationDto: UpdateLocationDto,
    @Request() req,
  ) {
    return this.tripsService.updateLocation(tripId, req.user._id.toString(), locationDto);
  }

  @Post(':id/complete')
  async completeTrip(@Param('id') tripId: string, @Request() req) {
    return this.tripsService.completeTrip(tripId, req.user._id.toString());
  }

  @Get('active')
  async getActiveTrips() {
    return this.tripsService.findActive();
  }

  @Get(':id/tracking')
  async getTrackingData(@Param('id') id: string, @Request() req) {
    return this.tripsService.getTrackingDataForUser(
      id,
      req.user._id.toString(),
      (req.user.roles || []) as UserRole[],
    );
  }

  @Get('driver/upcoming')
  async getUpcomingTrips(@Request() req) {
    return this.tripsService.findUpcomingByDriver(req.user._id.toString());
  }

  @Get('driver/active')
  async getActiveTrip(@Request() req) {
    const trips = await this.tripsService.findActiveByDriver(req.user._id.toString());
    return trips.length > 0 ? trips[0] : null;
  }

  @Get('driver/completed')
  async getCompletedTrips(@Request() req) {
    return this.tripsService.findCompletedByDriver(req.user._id.toString());
  }

  // Admin/system utility endpoint to cancel all active trips and free vehicles.
  // Restricted to transport/admin leadership roles.
  @Post('admin/cancel-all-active')
  @UseGuards(RolesGuard)
  @Roles(UserRole.ADMIN, UserRole.DGS, UserRole.DDGS, UserRole.AD_TRANSPORT, UserRole.TRANSPORT_OFFICER)
  async cancelAllActiveTrips() {
    return this.tripsService.cancelAllActiveTrips();
  }

  @Post(':id/location/batch')
  async batchUpdateLocation(
    @Param('id') tripId: string,
    @Body() body: { locations: Array<{ lat: number; lng: number; timestamp: string }> },
    @Request() req,
  ) {
    return this.tripsService.batchUpdateLocation(tripId, req.user._id.toString(), body.locations);
  }

  @Get(':id/metrics')
  async getTripMetrics(@Param('id') id: string) {
    return this.tripsService.getTripMetrics(id);
  }
}

