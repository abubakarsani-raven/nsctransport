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
    return this.tripsService.startTrip(tripId);
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
  async getTrackingData(@Param('id') id: string) {
    return this.tripsService.getTrackingData(id);
  }
}

