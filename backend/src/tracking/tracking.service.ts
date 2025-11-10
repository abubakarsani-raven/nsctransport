import { Injectable } from '@nestjs/common';
import { TripsService } from '../trips/trips.service';
import { VehiclesService } from '../vehicles/vehicles.service';
import { UsersService } from '../users/users.service';

@Injectable()
export class TrackingService {
  constructor(
    private tripsService: TripsService,
    private vehiclesService: VehiclesService,
    private usersService: UsersService,
  ) {}

  async getVehicleLocations(): Promise<any[]> {
    const activeTrips = await this.tripsService.findActive();
    const vehicleLocations: Array<{
      vehicleId: string;
      plateNumber: string;
      location: { lat: number; lng: number };
      tripId: string;
    }> = [];

    for (const trip of activeTrips) {
      const vehicle = await this.vehiclesService.findById(trip.vehicleId.toString());
      if (vehicle && trip.route.length > 0) {
        const lastLocation = trip.route[trip.route.length - 1];
        vehicleLocations.push({
          vehicleId: (vehicle._id as any).toString(),
          plateNumber: vehicle.plateNumber,
          location: {
            lat: lastLocation.lat,
            lng: lastLocation.lng,
          },
          tripId: (trip._id as any).toString(),
        });
      }
    }

    return vehicleLocations;
  }

  async getDriverLocations(): Promise<any[]> {
    const activeTrips = await this.tripsService.findActive();
    const driverLocations: Array<{
      driverId: string;
      driverName: string;
      location: { lat: number; lng: number };
      tripId: string;
    }> = [];

    for (const trip of activeTrips) {
      const driver = await this.usersService.findById(trip.driverId.toString());
      if (driver && trip.route.length > 0) {
        const lastLocation = trip.route[trip.route.length - 1];
        driverLocations.push({
          driverId: (driver._id as any).toString(),
          driverName: driver.name,
          location: {
            lat: lastLocation.lat,
            lng: lastLocation.lng,
          },
          tripId: (trip._id as any).toString(),
        });
      }
    }

    return driverLocations;
  }
}

