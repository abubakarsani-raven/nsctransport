import { Controller, Get, UseGuards } from '@nestjs/common';
import { TrackingService } from './tracking.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';

@Controller('tracking')
@UseGuards(JwtAuthGuard)
export class TrackingController {
  constructor(private trackingService: TrackingService) {}

  @Get('vehicles')
  async getVehicleLocations() {
    return this.trackingService.getVehicleLocations();
  }

  @Get('drivers')
  async getDriverLocations() {
    return this.trackingService.getDriverLocations();
  }
}

