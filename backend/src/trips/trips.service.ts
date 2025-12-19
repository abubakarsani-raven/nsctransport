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
import { UserRole } from '../users/schemas/user.schema';
import { NotificationType } from '../notifications/schemas/notification.schema';
import { UpdateLocationDto } from './dto/update-location.dto';
import { SchedulerRegistry } from '@nestjs/schedule';
import { Cron, CronExpression } from '@nestjs/schedule';
import { VehicleRequestStage } from '../workflow/workflow-definition';
import { WorkflowAction } from '../workflow/schemas/workflow-actions.enum';
import { VehicleDistanceService } from '../vehicles/vehicle-distance.service';
import { EventEmitter2 } from '@nestjs/event-emitter';
import { LocationUpdatedEvent } from '../events/events';
import { VehiclesService } from '../vehicles/vehicles.service';
import { VehicleStatus } from '../vehicles/schemas/vehicle.schema';

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
    private vehicleDistanceService: VehicleDistanceService,
    private eventEmitter: EventEmitter2,
    private vehiclesService: VehiclesService,
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

    // Get destination address and coordinates
    let destinationAddress = request.destination;
    let destinationLat = request.destinationCoordinates?.lat || 0;
    let destinationLng = request.destinationCoordinates?.lng || 0;

    // If coordinates are provided, reverse geocode to get address
    if (request.destinationCoordinates) {
      try {
        destinationAddress = await this.mapsService.reverseGeocode(
          request.destinationCoordinates.lat,
          request.destinationCoordinates.lng,
        );
        destinationLat = request.destinationCoordinates.lat;
        destinationLng = request.destinationCoordinates.lng;
      } catch (error) {
        console.error('Failed to reverse geocode destination:', error);
      }
    } else if (request.destination && request.destination.trim().length > 0) {
      // If coordinates are not provided but address is, geocode the address
      try {
        const geocoded = await this.mapsService.geocodeAddress(request.destination);
        destinationLat = geocoded.lat;
        destinationLng = geocoded.lng;
        destinationAddress = request.destination; // Use the original address
        console.log(`Geocoded destination "${request.destination}" to (${destinationLat}, ${destinationLng})`);
      } catch (error) {
        console.error('Failed to geocode destination address:', error);
        // If geocoding fails, coordinates will remain 0, and client will need to geocode
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
        name: pickupOffice.name,
        officeId: pickupOfficeId,
      },
      endLocation: {
        lat: destinationLat,
        lng: destinationLng,
        address: destinationAddress,
      },
      status: TripStatus.PENDING,
    });

    const savedTrip = await trip.save();

    // DISABLED: Auto-start scheduling - trips should only be started by drivers manually
    // This ensures trips enter IN_PROGRESS status only when driver starts them
    // this.scheduleTripStart((savedTrip._id as any).toString(), new Date(request.startDate));

    return savedTrip;
  }

  // DISABLED: Auto-start scheduling - trips should only be started by drivers manually
  // private scheduleTripStart(tripId: string, startDate: Date): void {
  //   const now = new Date();
  //   if (startDate <= now) {
  //     // Start immediately if start date has passed
  //     this.startTrip(tripId).catch(console.error);
  //     return;
  //   }

  //   const delay = startDate.getTime() - now.getTime();
  //   const timeout = setTimeout(() => {
  //     this.startTrip(tripId).catch(console.error);
  //   }, delay);

  //   this.schedulerRegistry.addTimeout(`trip-${tripId}`, timeout);
  // }

  // DISABLED: Auto-start cron job - trips should only be started by drivers manually
  // This ensures trips enter IN_PROGRESS status only when driver starts them
  // @Cron(CronExpression.EVERY_MINUTE)
  // async checkScheduledTrips(): Promise<void> {
  //   const now = new Date();
  //   const pendingTrips = await this.tripModel
  //     .find({ status: TripStatus.PENDING })
  //     .populate('requestId')
  //     .exec();

  //   for (const trip of pendingTrips) {
  //     const requestId = this.extractId(trip.requestId);
  //     if (!requestId) continue;
      
  //     const request = await this.vehicleRequestService.findById(requestId);
  //     if (request && new Date(request.startDate) <= now) {
  //       await this.startTrip((trip._id as any).toString());
  //     }
  //   }
  // }

  async startTrip(tripId: string, driverId?: string): Promise<TripDocument> {
    const trip = await this.tripModel.findById(tripId).exec();
    if (!trip) {
      throw new NotFoundException('Trip not found');
    }

    // If driverId is provided, verify the driver is authorized to start this trip
    if (driverId && trip.driverId.toString() !== driverId) {
      throw new BadRequestException('You are not authorized to start this trip');
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
        notes: driverId ? 'Trip started by driver.' : 'Trip started.',
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
            const savedTrip = await trip.save();
            // Emit location update event for WebSocket broadcasting
            this.eventEmitter.emit(
              'location.updated',
              new LocationUpdatedEvent(tripId, driverId, {
                lat: locationDto.lat,
                lng: locationDto.lng,
                timestamp: new Date(),
              }),
            );
            return savedTrip;
            }
          }
          }
      }
    }

    const savedTrip = await trip.save();
    
    // Emit location update event for WebSocket broadcasting
    // This enables real-time tracking for admin/staff apps
    this.eventEmitter.emit(
      'location.updated',
      new LocationUpdatedEvent(tripId, driverId, {
        lat: locationDto.lat,
        lng: locationDto.lng,
        timestamp: new Date(),
      }),
    );
    
    return savedTrip;
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

    // Calculate duration (always calculate if we have startTime)
    if (trip.startTime) {
      trip.duration = (trip.endTime.getTime() - trip.startTime.getTime()) / (1000 * 60); // minutes
    }

    // Calculate distance and average speed from route
    if (trip.route.length > 0) {
      trip.distance = this.calculateRouteDistance(trip.route);
      
      // Calculate average speed (km/h) if we have both duration and distance
      if (trip.duration && trip.duration > 0 && trip.distance && trip.distance > 0) {
        const hours = trip.duration / 60; // Convert minutes to hours
        trip.averageSpeed = trip.distance / hours;
      }

      // Log distance to vehicle
      if (trip.distance && trip.distance > 0) {
        try {
          await this.vehicleDistanceService.logDistance(
            trip.vehicleId.toString(),
            trip.distance,
            'trip',
            tripId,
            driverId,
          );
        } catch (error) {
          // Log error but don't fail trip completion
          console.error('Failed to log vehicle distance:', error);
        }
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
      request.averageSpeed = trip.averageSpeed; // Save average speed to request
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
      const requesterId = this.extractId(request.requesterId);
      const requester = await this.usersService.findById(requesterId);
      if (requester) {
        await this.notificationsService.sendNotification(
          requesterId,
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
          participantIds.map(id => this.extractId(id)),
          NotificationType.TRIP_COMPLETED,
          'Trip Completed',
          `The trip you are participating in has been completed.`,
          (request._id as any).toString(),
        );
      }

      // Notify DGS users
      const dgsUsers = await this.usersService.findByRole(UserRole.DGS);
      if (dgsUsers.length > 0) {
        await this.notificationsService.sendNotificationToMultipleUsers(
          dgsUsers.map(user => (user._id as any).toString()),
          NotificationType.TRIP_COMPLETED,
          'Trip Completed',
          `Trip for request ${(request._id as any).toString()} has been completed by driver.`,
          (trip._id as any).toString(),
        );
      }

      // Notify Transport Officer (if assigned to the request)
      // Note: Transport Officer assignment is typically in the approval chain or request metadata
      // For now, we'll notify all Transport Officers
      const transportOfficers = await this.usersService.findByRole(UserRole.TRANSPORT_OFFICER);
      if (transportOfficers.length > 0) {
        await this.notificationsService.sendNotificationToMultipleUsers(
          transportOfficers.map(user => (user._id as any).toString()),
          NotificationType.TRIP_COMPLETED,
          'Trip Completed',
          `Trip for request ${(request._id as any).toString()} has been completed by driver.`,
          (trip._id as any).toString(),
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
      const requesterId = this.extractId(request.requesterId);
      const requester = await this.usersService.findById(requesterId);
      if (requester) {
        await this.notificationsService.sendNotification(
          requesterId,
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
          participantIds.map(id => this.extractId(id)),
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
    const trips = await this.tripModel.find({ status: TripStatus.IN_PROGRESS }).exec();
    console.log(
      `[TripsService] findActive -> count=${trips.length}, ids=${trips.map(t => (t._id as any).toString()).join(', ')}`,
    );
    return trips;
  }

  /**
   * Admin utility: cancel all active or pending trips and mark vehicles available.
   * This is intended for emergency/system reset scenarios.
   */
  async cancelAllActiveTrips(): Promise<{ cancelledTrips: number }> {
    // Treat both IN_PROGRESS and PENDING as "active" for the purposes of this reset
    const activeTrips = await this.tripModel
      .find({ status: { $in: [TripStatus.IN_PROGRESS, TripStatus.PENDING] } })
      .exec();

    if (!activeTrips.length) {
      return { cancelledTrips: 0 };
    }

    for (const trip of activeTrips) {
      // Mark trip as returned (no dedicated CANCELLED status on Trip)
      trip.status = TripStatus.RETURNED;
      trip.returnTime = new Date();

      // Best-effort: mark related request as cancelled in workflow
      const requestId = this.extractId(trip.requestId);
      if (requestId) {
        try {
          const request = await this.vehicleRequestService.findById(requestId);
          if (request) {
            request.status = RequestStatus.CANCELLED;
            request.currentStage = VehicleRequestStage.CANCELLED;
            if (!request.actionHistory) {
              request.actionHistory = [];
            }
            // Use a null performedBy to avoid invalid ObjectId casts
            request.actionHistory.push({
              action: WorkflowAction.CANCEL,
              performedBy: null,
              performedAt: new Date(),
              stage: request.currentStage,
              notes: 'Bulk system cancellation of active trips',
            } as any);
            request.markModified('actionHistory');
            await request.save();
          }
        } catch (err) {
          // Log and continue – we still want to free vehicles/trips
          console.error('Failed to mark request as cancelled for trip', trip._id, err);
        }
      }

      // Mark vehicle as available again (ignoring maintenance/permanent assignment rules here)
      const vehicleId = this.extractId(trip.vehicleId);
      if (vehicleId) {
        try {
          await this.vehiclesService.updateStatus(vehicleId, VehicleStatus.AVAILABLE);
        } catch (err) {
          console.error('Failed to set vehicle available for trip', trip._id, err);
        }
      }

      await trip.save();
    }

    return { cancelledTrips: activeTrips.length };
  }

  async findActiveByDriver(driverId: string): Promise<TripDocument[]> {
    const trips = await this.tripModel.find({ driverId, status: TripStatus.IN_PROGRESS }).exec();
    console.log(
      `[TripsService] findActiveByDriver driverId=${driverId} -> count=${trips.length}, ids=${trips.map(t => (t._id as any).toString()).join(', ')}`,
    );
    return trips;
  }

  async findCompletedByDriver(driverId: string): Promise<TripDocument[]> {
    return this.tripModel
      .find({
        driverId,
        status: { $in: [TripStatus.COMPLETED, TripStatus.RETURNED] },
      })
      .populate('requestId', 'destination startDate endDate requesterId participantIds assignedVehicleId actionHistory')
      .populate('requestId.requesterId', 'name email phone department')
      .populate('requestId.assignedVehicleId', 'make model plateNumber capacity year')
      .populate('vehicleId', 'make model plateNumber capacity year')
      .populate('requestId.participantIds', 'name email phone department')
      .sort({ endTime: -1 }) // Most recent first
      .exec();
  }

  async findUpcomingByDriver(driverId: string): Promise<TripDocument[]> {
    const now = new Date();
    const base = await this.tripModel
      .find({
        driverId,
        status: TripStatus.PENDING,
      })
      .populate('requestId')
      .exec();

    const filtered = base.filter((trip) => {
      const request = trip.requestId as any;
      if (request && request.startDate) {
        return new Date(request.startDate) > now;
      }
      return false;
    });

    console.log(
      `[TripsService] findUpcomingByDriver driverId=${driverId} -> pending=${base.length}, upcoming=${filtered.length}, ids=${filtered.map(t => (t._id as any).toString()).join(', ')}`,
    );

    return filtered;
  }

  async findActiveByVehicle(vehicleId: string): Promise<TripDocument[]> {
    return this.tripModel.find({ vehicleId, status: TripStatus.IN_PROGRESS }).exec();
  }

  async findByRequestId(requestId: string): Promise<TripDocument | null> {
    return this.tripModel.findOne({ requestId }).exec();
  }

  /**
   * Find trips for a driver whose planned/actual time window overlaps the given [startDate, endDate].
   * A trip is considered overlapping if:
   *  - Its actual [startTime, endTime] window intersects [startDate, endDate], OR
   *  - It is pending and its request's [startDate, endDate] window intersects [startDate, endDate].
   */
  async findByDriverAndTimeWindow(
    driverId: string,
    startDate: Date,
    endDate: Date,
  ): Promise<TripDocument[]> {
    // First, find trips for this driver
    const trips = await this.tripModel
      .find({ driverId })
      .populate('requestId', 'startDate endDate')
      .exec();

    const windowStart = startDate.getTime();
    const windowEnd = endDate.getTime();

    return trips.filter((trip) => {
      // Determine this trip's time window
      let tripStart: number | null = null;
      let tripEnd: number | null = null;

      if (trip.startTime && trip.endTime) {
        tripStart = trip.startTime.getTime();
        tripEnd = trip.endTime.getTime();
      } else {
        const req: any = trip.requestId;
        if (req && req.startDate && req.endDate) {
          tripStart = new Date(req.startDate).getTime();
          tripEnd = new Date(req.endDate).getTime();
        }
      }

      if (tripStart == null || tripEnd == null) {
        return false;
      }

      // Overlap if existingStart < end && existingEnd > start
      return tripStart < windowEnd && tripEnd > windowStart;
    });
  }

  /**
   * Same as findByDriverAndTimeWindow but for vehicles.
   */
  async findByVehicleAndTimeWindow(
    vehicleId: string,
    startDate: Date,
    endDate: Date,
  ): Promise<TripDocument[]> {
    const trips = await this.tripModel
      .find({ vehicleId })
      .populate('requestId', 'startDate endDate')
      .exec();

    const windowStart = startDate.getTime();
    const windowEnd = endDate.getTime();

    return trips.filter((trip) => {
      let tripStart: number | null = null;
      let tripEnd: number | null = null;

      if (trip.startTime && trip.endTime) {
        tripStart = trip.startTime.getTime();
        tripEnd = trip.endTime.getTime();
      } else {
        const req: any = trip.requestId;
        if (req && req.startDate && req.endDate) {
          tripStart = new Date(req.startDate).getTime();
          tripEnd = new Date(req.endDate).getTime();
        }
      }

      if (tripStart == null || tripEnd == null) {
        return false;
      }

      return tripStart < windowEnd && tripEnd > windowStart;
    });
  }

  async getTrackingDataForUser(
    tripId: string,
    userId: string,
    roles: UserRole[] = [],
  ): Promise<TripDocument> {
    const trip = await this.tripModel
      .findById(tripId)
      .populate(
        'requestId',
        'destination startDate endDate requesterId participantIds assignedVehicleId actionHistory',
      )
      .populate('requestId.requesterId', 'name email phone department')
      .populate('requestId.assignedVehicleId', 'make model plateNumber capacity year')
      .populate('vehicleId', 'make model plateNumber capacity year')
      .populate('requestId.participantIds', 'name email phone department')
      .exec();

    if (!trip) {
      throw new NotFoundException('Trip not found');
    }

    const isAssignedDriver = trip.driverId.toString() === userId;
    const isPrivilegedUser = roles.some((role) =>
      [
        UserRole.ADMIN,
        UserRole.DGS,
        UserRole.DDGS,
        UserRole.AD_TRANSPORT,
        UserRole.TRANSPORT_OFFICER,
      ].includes(role),
    );

    if (!isAssignedDriver && !isPrivilegedUser) {
      // Hide existence of the trip from unauthorized drivers
      throw new NotFoundException('Trip not found');
    }

    return trip;
  }

  async updateDriver(requestId: string, newDriverId: string): Promise<void> {
    await this.tripModel.updateOne({ requestId }, { driverId: newDriverId }).exec();
  }

  async batchUpdateLocation(
    tripId: string,
    driverId: string,
    locations: Array<{ lat: number; lng: number; timestamp: string }>,
  ): Promise<TripDocument> {
    const trip = await this.tripModel.findById(tripId).exec();
    if (!trip) {
      throw new NotFoundException('Trip not found');
    }

    if (trip.driverId.toString() !== driverId) {
      throw new BadRequestException('You are not authorized to update this trip');
    }

    if (trip.status !== TripStatus.IN_PROGRESS && trip.status !== TripStatus.COMPLETED) {
      throw new BadRequestException('Trip is not in progress or completed');
    }

    // Add all locations to route
    for (const loc of locations) {
      trip.route.push({
        lat: loc.lat,
        lng: loc.lng,
        timestamp: new Date(loc.timestamp),
      });
    }

    // Update current location to last location
    let lastLocation: { lat: number; lng: number; timestamp: Date } | null = null;
    if (locations.length > 0) {
      const lastLoc = locations[locations.length - 1];
      trip.startLocation = {
        ...trip.startLocation,
        lat: lastLoc.lat,
        lng: lastLoc.lng,
      };
      lastLocation = {
        lat: lastLoc.lat,
        lng: lastLoc.lng,
        timestamp: new Date(lastLoc.timestamp),
      };
    }

    const savedTrip = await trip.save();
    
    // Emit location update event for WebSocket broadcasting
    // This enables real-time tracking for admin/staff apps
    if (lastLocation) {
      this.eventEmitter.emit(
        'location.updated',
        new LocationUpdatedEvent(tripId, driverId, lastLocation),
      );
    }
    
    return savedTrip;
  }

  async getTripMetrics(tripId: string): Promise<any> {
    const trip = await this.tripModel.findById(tripId).exec();
    if (!trip) {
      throw new NotFoundException('Trip not found');
    }

    const distance = trip.distance || (trip.route.length > 0 ? this.calculateRouteDistance(trip.route) : 0);
    let duration = trip.duration || 0;
    let averageSpeed = trip.averageSpeed || 0;
    let maxSpeed = 0;

    // Calculate duration if not already stored
    if (duration === 0) {
      if (trip.startTime && trip.endTime) {
        duration = (trip.endTime.getTime() - trip.startTime.getTime()) / (1000 * 60); // minutes
      } else if (trip.startTime) {
        duration = (new Date().getTime() - trip.startTime.getTime()) / (1000 * 60); // minutes
      }
    }

    // Calculate average speed if not already stored
    if (averageSpeed === 0 && duration > 0 && distance > 0) {
      const hours = duration / 60;
      averageSpeed = hours > 0 ? distance / hours : 0;
    }

    // Calculate max speed from route
    if (trip.route.length >= 2) {
      for (let i = 1; i < trip.route.length; i++) {
        const segmentDistance = this.calculateDistance(trip.route[i - 1], trip.route[i]);
        const timeDiff = trip.route[i].timestamp.getTime() - trip.route[i - 1].timestamp.getTime();
        if (timeDiff > 0) {
          const hours = timeDiff / (1000 * 3600);
          const speed = hours > 0 ? segmentDistance / hours : 0;
          if (speed > maxSpeed) {
            maxSpeed = speed;
          }
        }
      }
    }

    return {
      distance,
      duration,
      averageSpeed,
      maxSpeed,
      routePoints: trip.route.length,
      startTime: trip.startTime,
      endTime: trip.endTime,
    };
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

