import { Injectable, NotFoundException, BadRequestException } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model } from 'mongoose';
import { Trip, TripDocument, TripStatus } from './schemas/trip.schema';
import { VehicleRequest, VehicleRequestDocument, RequestStatus } from '../requests/vehicle/schemas/vehicle-request.schema';
import { VehicleRequestService } from '../requests/vehicle/vehicle-request.service';
import { MapsService } from '../maps/maps.service';
import { OfficesService } from '../offices/offices.service';
import { NotificationsService } from '../notifications/notifications.service';
import { UsersService } from '../users/users.service';
import { NotificationType } from '../notifications/schemas/notification.schema';
import { UpdateLocationDto } from './dto/update-location.dto';
import { SchedulerRegistry } from '@nestjs/schedule';
import { Cron, CronExpression } from '@nestjs/schedule';
import { VehicleRequestStage } from '../workflow/workflow-definition';
import { WorkflowAction } from '../workflow/schemas/workflow-actions.enum';

@Injectable()
export class TripsService {
  constructor(
    @InjectModel(Trip.name) private tripModel: Model<TripDocument>,
    private vehicleRequestService: VehicleRequestService,
    private mapsService: MapsService,
    private officesService: OfficesService,
    private notificationsService: NotificationsService,
    private usersService: UsersService,
    private schedulerRegistry: SchedulerRegistry,
  ) {}

  /**
   * Helper to extract ID from populated or non-populated reference
   */
  private extractId(ref: any): string {
    if (ref === undefined || ref === null) {
      return '';
    }
    if (typeof ref === 'object' && ref !== null && !(ref instanceof Date)) {
      return ref._id?.toString() || ref.id?.toString() || String(ref);
    }
    return String(ref);
  }

  async createFromRequest(request: VehicleRequestDocument): Promise<TripDocument> {
    const requestId = (request._id as any).toString();
    const existingTrip = await this.tripModel.findOne({ requestId }).exec();
    if (existingTrip) {
      return existingTrip;
    }

    const pickupOfficeId =
      this.resolveOfficeId((request as any).pickupOffice) ??
      this.resolveOfficeId(request.originOffice);
    if (!pickupOfficeId) {
      throw new NotFoundException('Pickup office not found');
    }

    const pickupOffice = await this.officesService.findById(pickupOfficeId);
    if (!pickupOffice) {
      throw new NotFoundException('Pickup office not found');
    }

    // Get destination address
    let destinationAddress = request.destination;
    if (request.destinationCoordinates) {
      try {
        destinationAddress = await this.mapsService.reverseGeocode(
          request.destinationCoordinates.lat,
          request.destinationCoordinates.lng,
        );
      } catch (error) {
        console.error('Failed to reverse geocode destination:', error);
      }
    }

    const trip = new this.tripModel({
      requestId,
      driverId: request.assignedDriverId,
      vehicleId: request.assignedVehicleId,
      startLocation: {
        lat: pickupOffice.coordinates.lat,
        lng: pickupOffice.coordinates.lng,
        address: pickupOffice.address,
      },
      endLocation: {
        lat: request.destinationCoordinates?.lat || 0,
        lng: request.destinationCoordinates?.lng || 0,
        address: destinationAddress,
      },
      status: TripStatus.PENDING,
    });

    const savedTrip = await trip.save();

    // Schedule auto-start job
    this.scheduleTripStart((savedTrip._id as any).toString(), new Date(request.startDate));

    return savedTrip;
  }

  private scheduleTripStart(tripId: string, startDate: Date): void {
    const now = new Date();
    if (startDate <= now) {
      // Start immediately if start date has passed
      this.startTrip(tripId).catch(console.error);
      return;
    }

    const delay = startDate.getTime() - now.getTime();
    const timeout = setTimeout(() => {
      this.startTrip(tripId).catch(console.error);
    }, delay);

    this.schedulerRegistry.addTimeout(`trip-${tripId}`, timeout);
  }

  @Cron(CronExpression.EVERY_MINUTE)
  async checkScheduledTrips(): Promise<void> {
    const now = new Date();
    const pendingTrips = await this.tripModel
      .find({ status: TripStatus.PENDING })
      .populate('requestId')
      .exec();

    for (const trip of pendingTrips) {
      const requestId = this.extractId(trip.requestId);
      if (!requestId) continue;
      
      const request = await this.vehicleRequestService.findById(requestId);
      if (request && new Date(request.startDate) <= now) {
        await this.startTrip((trip._id as any).toString());
      }
    }
  }

  async startTrip(tripId: string): Promise<TripDocument> {
    const trip = await this.tripModel.findById(tripId).exec();
    if (!trip) {
      throw new NotFoundException('Trip not found');
    }

    if (trip.status !== TripStatus.PENDING) {
      throw new BadRequestException('Trip is not in pending status');
    }

    trip.status = TripStatus.IN_PROGRESS;
    trip.startTime = new Date();

    // Update request status
    const requestId = this.extractId(trip.requestId);
    if (!requestId) {
      throw new NotFoundException('Request ID not found in trip');
    }
    const request = await this.vehicleRequestService.findById(requestId);
    if (request) {
      request.status = RequestStatus.IN_PROGRESS;
      request.currentStage = VehicleRequestStage.IN_PROGRESS;
      if (!request.actionHistory) {
        request.actionHistory = [];
      }
      request.actionHistory.push({
        action: WorkflowAction.START_TRIP,
        performedBy: trip.driverId.toString(),
        performedAt: new Date(),
        stage: VehicleRequestStage.ASSIGNED,
        notes: 'Trip started automatically.',
      });
      request.markModified('actionHistory');
      await request.save();
    }

    const updatedTrip = await trip.save();

    // Notify driver
    const driver = await this.usersService.findById(trip.driverId.toString());
    if (driver) {
      await this.notificationsService.sendNotification(
        trip.driverId.toString(),
        NotificationType.TRIP_STARTED,
        'Trip Started',
        `Your trip for request ${(trip.requestId as any).toString()} has started`,
        (trip._id as any).toString(),
      );
    }

    // Notify participants that trip has started
    if (request) {
      const participantIds = request.participantIds || [];
      if (participantIds.length > 0) {
        await this.notificationsService.sendNotificationToMultipleUsers(
          participantIds.map(id => id.toString()),
          NotificationType.TRIP_STARTED,
          'Trip Started',
          `The trip you are participating in has started. Driver: ${driver?.name || 'N/A'}.`,
          (request._id as any).toString(),
        );
      }
    }

    return updatedTrip;
  }

  async updateLocation(tripId: string, driverId: string, locationDto: UpdateLocationDto): Promise<TripDocument> {
    const trip = await this.tripModel.findById(tripId).exec();
    if (!trip) {
      throw new NotFoundException('Trip not found');
    }

    if (trip.driverId.toString() !== driverId) {
      throw new BadRequestException('You are not authorized to update this trip');
    }

    // Allow location updates for trips in progress or completed (for return tracking)
    if (trip.status !== TripStatus.IN_PROGRESS && trip.status !== TripStatus.COMPLETED) {
      throw new BadRequestException('Trip is not in progress or completed');
    }

    // Add location to route
    trip.route.push({
      lat: locationDto.lat,
      lng: locationDto.lng,
      timestamp: new Date(),
    });

    // Update current location
    trip.startLocation = {
      ...trip.startLocation,
      lat: locationDto.lat,
      lng: locationDto.lng,
    };

    // Check if driver has returned to origin (within 50m) after trip is completed
    if (trip.status === TripStatus.COMPLETED) {
      const requestId = this.extractId(trip.requestId);
      if (!requestId) {
        throw new NotFoundException('Request ID not found in trip');
      }
      const request = await this.vehicleRequestService.findById(requestId);
      if (request) {
        const startOfficeId =
          this.resolveOfficeId((request as any).pickupOffice) ??
          this.resolveOfficeId(request.originOffice);
        if (startOfficeId) {
          const startOffice = await this.officesService.findById(startOfficeId);
          if (startOffice) {
          const distance = this.calculateDistance(
            { lat: locationDto.lat, lng: locationDto.lng },
              startOffice.coordinates,
          );
            if (distance <= 0.05) {
              // 50 meters in kilometers
            await this.markAsReturned(tripId);
            return trip;
            }
          }
          }
      }
    }

    return trip.save();
  }

  async completeTrip(tripId: string, driverId: string): Promise<TripDocument> {
    const trip = await this.tripModel.findById(tripId).exec();
    if (!trip) {
      throw new NotFoundException('Trip not found');
    }

    if (trip.driverId.toString() !== driverId) {
      throw new BadRequestException('You are not authorized to complete this trip');
    }

    if (trip.status !== TripStatus.IN_PROGRESS) {
      throw new BadRequestException('Trip is not in progress');
    }

    trip.status = TripStatus.COMPLETED;
    trip.endTime = new Date();

    // Calculate distance and duration
    if (trip.route.length > 0) {
      trip.distance = this.calculateRouteDistance(trip.route);
      if (trip.startTime) {
        trip.duration = (trip.endTime.getTime() - trip.startTime.getTime()) / (1000 * 60); // minutes
      }
    }

    // Update request
    const requestId = this.extractId(trip.requestId);
    if (!requestId) {
      throw new NotFoundException('Request ID not found in trip');
    }
    const request = await this.vehicleRequestService.findById(requestId);
    if (request) {
      request.status = RequestStatus.COMPLETED;
      request.actualDistance = trip.distance;
      request.actualTime = trip.duration;
      request.currentStage = VehicleRequestStage.COMPLETED;
      if (!request.actionHistory) {
        request.actionHistory = [];
      }
      request.actionHistory.push({
        action: WorkflowAction.COMPLETE_TRIP,
        performedBy: driverId,
        performedAt: new Date(),
        stage: VehicleRequestStage.IN_PROGRESS,
        notes: 'Trip completed.',
      });
      request.markModified('actionHistory');
      await request.save();
    }

    const updatedTrip = await trip.save();

    // Notify requester
    if (request) {
      const requester = await this.usersService.findById(request.requesterId.toString());
      if (requester) {
        await this.notificationsService.sendNotification(
          request.requesterId.toString(),
          NotificationType.TRIP_COMPLETED,
          'Trip Completed',
          `Your trip for request ${(request._id as any).toString()} has been completed`,
          (trip._id as any).toString(),
        );
      }

      // Notify participants that trip has been completed
      const participantIds = request.participantIds || [];
      if (participantIds.length > 0) {
        await this.notificationsService.sendNotificationToMultipleUsers(
          participantIds.map(id => id.toString()),
          NotificationType.TRIP_COMPLETED,
          'Trip Completed',
          `The trip you are participating in has been completed.`,
          (request._id as any).toString(),
        );
      }
    }

    return updatedTrip;
  }

  async markAsReturned(tripId: string): Promise<TripDocument> {
    const trip = await this.tripModel.findById(tripId).exec();
    if (!trip) {
      throw new NotFoundException('Trip not found');
    }

    trip.status = TripStatus.RETURNED;
    trip.returnTime = new Date();

    // Update request
    const requestId = this.extractId(trip.requestId);
    if (!requestId) {
      throw new NotFoundException('Request ID not found in trip');
    }
    const request = await this.vehicleRequestService.findById(requestId);
    if (request) {
      request.status = RequestStatus.RETURNED;
      request.currentStage = VehicleRequestStage.RETURNED;
      if (!request.actionHistory) {
        request.actionHistory = [];
      }
      request.actionHistory.push({
        action: WorkflowAction.RETURN_VEHICLE,
        performedBy: trip.driverId.toString(),
        performedAt: new Date(),
        stage: VehicleRequestStage.COMPLETED,
        notes: 'Vehicle returned to pickup location.',
      });
      request.markModified('actionHistory');
      await request.save();
    }

    const updatedTrip = await trip.save();

    // Notify requester
    if (request) {
      const requester = await this.usersService.findById(request.requesterId.toString());
      if (requester) {
        await this.notificationsService.sendNotification(
          request.requesterId.toString(),
          NotificationType.TRIP_RETURNED,
          'Trip Returned',
          `Your trip for request ${(request._id as any).toString()} has returned`,
          (trip._id as any).toString(),
        );
      }

      // Notify participants that trip has returned
      const participantIds = request.participantIds || [];
      if (participantIds.length > 0) {
        await this.notificationsService.sendNotificationToMultipleUsers(
          participantIds.map(id => id.toString()),
          NotificationType.TRIP_RETURNED,
          'Trip Returned',
          `The trip you are participating in has returned to the pickup location.`,
          (request._id as any).toString(),
        );
      }
    }

    return updatedTrip;
  }

  async findActive(): Promise<TripDocument[]> {
    return this.tripModel.find({ status: TripStatus.IN_PROGRESS }).exec();
  }

  async findActiveByDriver(driverId: string): Promise<TripDocument[]> {
    return this.tripModel.find({ driverId, status: TripStatus.IN_PROGRESS }).exec();
  }

  async findActiveByVehicle(vehicleId: string): Promise<TripDocument[]> {
    return this.tripModel.find({ vehicleId, status: TripStatus.IN_PROGRESS }).exec();
  }

  async findByRequestId(requestId: string): Promise<TripDocument | null> {
    return this.tripModel.findOne({ requestId }).exec();
  }

  async getTrackingData(tripId: string): Promise<TripDocument> {
    const trip = await this.tripModel.findById(tripId).exec();
    if (!trip) {
      throw new NotFoundException('Trip not found');
    }
    return trip;
  }

  async updateDriver(requestId: string, newDriverId: string): Promise<void> {
    await this.tripModel.updateOne({ requestId }, { driverId: newDriverId }).exec();
  }

  private calculateDistance(point1: { lat: number; lng: number }, point2: { lat: number; lng: number }): number {
    const R = 6371; // Earth's radius in kilometers
    const dLat = this.toRad(point2.lat - point1.lat);
    const dLon = this.toRad(point2.lng - point1.lng);
    const a =
      Math.sin(dLat / 2) * Math.sin(dLat / 2) +
      Math.cos(this.toRad(point1.lat)) *
        Math.cos(this.toRad(point2.lat)) *
        Math.sin(dLon / 2) *
        Math.sin(dLon / 2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    return R * c;
  }

  private toRad(degrees: number): number {
    return degrees * (Math.PI / 180);
  }

  private calculateRouteDistance(route: Array<{ lat: number; lng: number }>): number {
    let totalDistance = 0;
    for (let i = 1; i < route.length; i++) {
      totalDistance += this.calculateDistance(route[i - 1], route[i]);
    }
    return totalDistance;
  }

  private resolveOfficeId(office: any): string | null {
    if (!office) {
      return null;
    }

    if (typeof office === 'string') {
      return office;
    }

    if (typeof office === 'object') {
      const idValue = office._id ?? office.id;
      if (!idValue) {
        return null;
      }
      return typeof idValue === 'string' ? idValue : idValue.toString();
    }

    return null;
  }
}

