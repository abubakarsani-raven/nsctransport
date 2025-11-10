import { Injectable, NotFoundException, BadRequestException, ForbiddenException } from '@nestjs/common';
import { VehicleRequestService } from '../requests/vehicle/vehicle-request.service';
import { VehiclesService } from '../vehicles/vehicles.service';
import { UsersService } from '../users/users.service';
import { TripsService } from '../trips/trips.service';
import { NotificationsService } from '../notifications/notifications.service';
import { NotificationType } from '../notifications/schemas/notification.schema';
import { RequestStatus } from '../requests/vehicle/schemas/vehicle-request.schema';
import { VehicleStatus } from '../vehicles/schemas/vehicle.schema';
import { AssignDriverVehicleDto } from './dto/assign-driver-vehicle.dto';
import { UserDocument } from '../users/schemas/user.schema';
import { VehicleDocument } from '../vehicles/schemas/vehicle.schema';
import { OfficesService } from '../offices/offices.service';
import { VehicleRequestStage } from '../workflow/workflow-definition';
import { WorkflowAction } from '../workflow/schemas/workflow-actions.enum';
import { UserRole } from '../users/schemas/user.schema';

@Injectable()
export class AssignmentsService {
  constructor(
    private vehicleRequestService: VehicleRequestService,
    private vehiclesService: VehiclesService,
    private usersService: UsersService,
    private tripsService: TripsService,
    private notificationsService: NotificationsService,
    private officesService: OfficesService,
  ) {}

  async getAvailableDrivers(): Promise<UserDocument[]> {
    const drivers = await this.usersService.findDrivers();
    // Filter out drivers who are already assigned to active trips
    const availableDrivers: UserDocument[] = [];
    for (const driver of drivers) {
      const driverId = (driver._id as any).toString();
      const activeTrips = await this.tripsService.findActiveByDriver(driverId);
      if (activeTrips.length === 0) {
        availableDrivers.push(driver);
      }
    }
    return availableDrivers;
  }

  async getAvailableVehicles(): Promise<VehicleDocument[]> {
    const vehicles = await this.vehiclesService.findAvailable();
    // Filter out vehicles that are assigned to active trips
    const availableVehicles: VehicleDocument[] = [];
    for (const vehicle of vehicles) {
      const vehicleId = (vehicle._id as any).toString();
      const activeTrips = await this.tripsService.findActiveByVehicle(vehicleId);
      if (activeTrips.length === 0) {
        availableVehicles.push(vehicle);
      }
    }
    return availableVehicles;
  }

  async assignDriverAndVehicle(
    requestId: string,
    assignDto: AssignDriverVehicleDto,
    transportOfficerId: string,
  ): Promise<any> {
    const normalizedRequestId = this.normalizeId(requestId);
    const driverId = this.normalizeId(assignDto.driverId);
    const vehicleId = this.normalizeId(assignDto.vehicleId);
    const pickupOfficeId = this.normalizeId(assignDto.pickupOfficeId);

    const request = await this.vehicleRequestService.findById(normalizedRequestId);

    // Check if the assigner is DGS or Transport Officer
    const assigner = await this.usersService.findById(transportOfficerId);
    if (!assigner) {
      throw new NotFoundException('Assigner not found');
    }
    const assignerRoles = assigner.roles || [];
    const isDGS = assignerRoles.includes(UserRole.DGS);
    const isTransportOfficer = assignerRoles.includes(UserRole.TRANSPORT_OFFICER);

    // Check if request is in the correct stage for assignment
    // Allow assignment if:
    // 1. CurrentStage is TRANSPORT_OFFICER_ASSIGNMENT (normal flow)
    // 2. Status is AD_TRANSPORT_APPROVED (normal flow)
    // 3. CurrentStage is DGS_REVIEW and assigner is DGS (DGS skipping)
    // Normalize values to handle case sensitivity and whitespace
    const normalizedCurrentStage = request.currentStage?.toString().toLowerCase().trim();
    const normalizedStatus = request.status?.toString().toLowerCase().trim();
    const isInAssignmentStage = 
      normalizedCurrentStage === VehicleRequestStage.TRANSPORT_OFFICER_ASSIGNMENT.toLowerCase() ||
      normalizedStatus === RequestStatus.AD_TRANSPORT_APPROVED.toLowerCase() ||
      (normalizedCurrentStage === VehicleRequestStage.DGS_REVIEW.toLowerCase() && isDGS);
    
    if (!isInAssignmentStage) {
      throw new BadRequestException(
        `Request must be approved by AD Transport before assignment. Current stage: ${request.currentStage}, Status: ${request.status}`
      );
    }

    // Verify assigner has permission
    if (!isTransportOfficer && !isDGS) {
      throw new ForbiddenException('Only Transport Officer or DGS can assign drivers and vehicles');
    }

    // Verify driver exists and is available
    const driver = await this.usersService.findById(driverId);
    if (!driver) {
      throw new NotFoundException('Driver not found');
    }

    const availableDrivers = await this.getAvailableDrivers();
    const isDriverAvailable = availableDrivers.some((d) => (d._id as any).toString() === driverId);
    if (!isDriverAvailable) {
      throw new BadRequestException('Driver is not available');
    }

    // Verify vehicle exists and is available
    const vehicle = await this.vehiclesService.findById(vehicleId);
    if (!vehicle) {
      throw new NotFoundException('Vehicle not found');
    }

    // Check if vehicle is permanently assigned
    if (vehicle.status === VehicleStatus.PERMANENTLY_ASSIGNED) {
      throw new BadRequestException('Cannot assign permanently assigned vehicle to temporary trips');
    }

    const availableVehicles = await this.getAvailableVehicles();
    const isVehicleAvailable = availableVehicles.some((v) => (v._id as any).toString() === vehicleId);
    if (!isVehicleAvailable) {
      throw new BadRequestException('Vehicle is not available');
    }

    // Check vehicle capacity
    if (vehicle.capacity < request.passengerCount) {
      throw new BadRequestException('Vehicle capacity is less than required passenger count');
    }

    // Verify pickup office exists
    const pickupOffice = await this.officesService.findById(pickupOfficeId);
    if (!pickupOffice) {
      throw new NotFoundException('Pickup office not found');
    }

    // Update request
    request.assignedDriverId = driverId;
    request.assignedVehicleId = vehicleId;
    request.pickupOffice = pickupOfficeId;
    request.currentStage = VehicleRequestStage.ASSIGNED;
    request.status = RequestStatus.TRANSPORT_OFFICER_ASSIGNED;

    // Add to approval chain
    request.approvalChain.push({
      approverId: transportOfficerId,
      status: RequestStatus.TRANSPORT_OFFICER_ASSIGNED,
      timestamp: new Date(),
      comments: `Driver ${driver.name} and Vehicle ${vehicle.plateNumber} assigned. Pickup: ${pickupOffice.name}`,
    });

    // Record action history
    if (!request.actionHistory) {
      request.actionHistory = [];
    }
    // Record the stage from which assignment was made (DGS_REVIEW if DGS skipped, otherwise TRANSPORT_OFFICER_ASSIGNMENT)
    const assignmentStage = normalizedCurrentStage === VehicleRequestStage.DGS_REVIEW.toLowerCase() 
      ? VehicleRequestStage.DGS_REVIEW 
      : VehicleRequestStage.TRANSPORT_OFFICER_ASSIGNMENT;
    request.actionHistory.push({
      action: WorkflowAction.ASSIGN,
      performedBy: transportOfficerId,
      performedAt: new Date(),
      stage: assignmentStage,
      notes: `Driver ${driver.name} and Vehicle ${vehicle.plateNumber} assigned. Pickup: ${pickupOffice.name}${isDGS ? ' (DGS skipped intermediate approvals)' : ''}`,
      metadata: {
        driverId,
        vehicleId,
        pickupOfficeId,
      },
    });

    request.markModified('approvalChain');
    request.markModified('actionHistory');

    await request.save();

    // Update vehicle status
    await this.vehiclesService.updateStatus(vehicleId, VehicleStatus.ASSIGNED);

    // Create trip
    await this.tripsService.createFromRequest(request);

    // Notify driver
    await this.notificationsService.sendNotification(
      driverId,
      NotificationType.DRIVER_ASSIGNED,
      'New Trip Assigned',
      `You have been assigned to a trip for request ${(request._id as any).toString()}`,
      (request._id as any).toString(),
    );

    // Notify requester
    const requesterId = this.normalizeId(request.requesterId);
    const requester = await this.usersService.findById(requesterId);
    if (requester) {
      await this.notificationsService.sendNotification(
        (requester._id as any).toString(),
        NotificationType.DRIVER_ASSIGNED,
        'Driver Assigned',
        `A driver has been assigned to your request ${(request._id as any).toString()}`,
        (request._id as any).toString(),
      );
    }

    // Notify participants about driver and vehicle assignment
    const participantIds = request.participantIds || [];
    if (participantIds.length > 0) {
      await this.notificationsService.sendNotificationToMultipleUsers(
        participantIds.map(id => id.toString()),
        NotificationType.DRIVER_ASSIGNED,
        'Driver and Vehicle Assigned',
        `Driver ${driver.name} and vehicle ${vehicle.plateNumber} have been assigned to your trip. Pickup location: ${pickupOffice.name}.`,
        (request._id as any).toString(),
      );
    }

    await request.populate([
      { path: 'assignedDriverId', select: 'name email phone employeeId' },
      { path: 'assignedVehicleId', select: 'plateNumber make model capacity' },
      { path: 'pickupOffice', select: 'name address coordinates' },
    ]);

    return request;
  }

  private normalizeId(value: any): string {
    if (value == null) {
      return value;
    }
    if (typeof value === 'string') {
      return value;
    }
    if (typeof value === 'object') {
      if ('_id' in value && value._id) {
        return value._id.toString();
      }
      if ('id' in value && value.id) {
        return value.id.toString();
      }
    }
    return value.toString();
  }

  async swapDriver(
    requestId: string,
    newDriverId: string,
    transportOfficerId: string,
  ): Promise<any> {
    const request = await this.vehicleRequestService.findById(requestId);

    // Check if request is in the assigned stage (driver and vehicle already assigned)
    // Allow swap if currentStage is ASSIGNED or status is TRANSPORT_OFFICER_ASSIGNED
    const isAssigned = 
      request.currentStage === VehicleRequestStage.ASSIGNED ||
      request.status === RequestStatus.TRANSPORT_OFFICER_ASSIGNED;
    
    if (!isAssigned) {
      throw new BadRequestException('Can only swap driver before trip starts');
    }

    // Check if trip start date has passed
    const now = new Date();
    if (new Date(request.startDate) <= now) {
      throw new BadRequestException('Cannot swap driver after trip start date');
    }

    // Verify new driver exists and is available
    const newDriver = await this.usersService.findById(newDriverId);
    if (!newDriver) {
      throw new NotFoundException('Driver not found');
    }

    const availableDrivers = await this.getAvailableDrivers();
    const isDriverAvailable = availableDrivers.some((d) => (d._id as any).toString() === newDriverId);
    if (!isDriverAvailable) {
      throw new BadRequestException('New driver is not available');
    }

    const oldDriverId = request.assignedDriverId;
    request.assignedDriverId = newDriverId;

    // Add to approval chain
    request.approvalChain.push({
      approverId: transportOfficerId,
      status: request.status,
      timestamp: new Date(),
      comments: `Driver swapped from ${oldDriverId} to ${newDriverId}`,
    });

    await request.save();

    // Update trip if it exists
    const trip = await this.tripsService.findByRequestId(requestId);
    if (trip) {
      await this.tripsService.updateDriver(requestId, newDriverId);
    }

    // Notify new driver
    await this.notificationsService.sendNotification(
      newDriverId,
      NotificationType.DRIVER_ASSIGNED,
      'Trip Reassignment',
      `You have been reassigned to a trip for request ${(request._id as any).toString()}`,
      (request._id as any).toString(),
    );

    // Notify old driver
    if (oldDriverId) {
      const oldDriver = await this.usersService.findById(oldDriverId);
      if (oldDriver) {
        await this.notificationsService.sendNotification(
          oldDriverId,
          NotificationType.DRIVER_ASSIGNED,
          'Trip Reassignment',
          `You have been unassigned from the trip for request ${(request._id as any).toString()}`,
          (request._id as any).toString(),
        );
      }
    }

    // Notify participants about driver swap
    const participantIds = request.participantIds || [];
    if (participantIds.length > 0) {
      await this.notificationsService.sendNotificationToMultipleUsers(
        participantIds.map(id => id.toString()),
        NotificationType.DRIVER_ASSIGNED,
        'Driver Changed',
        `The driver for your trip has been changed to ${newDriver.name}.`,
        (request._id as any).toString(),
      );
    }

    return request;
  }
}

