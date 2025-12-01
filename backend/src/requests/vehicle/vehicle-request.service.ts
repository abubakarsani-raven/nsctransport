import { Injectable, NotFoundException, BadRequestException, ForbiddenException } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model } from 'mongoose';
import { VehicleRequest, VehicleRequestDocument, RequestStatus } from './schemas/vehicle-request.schema';
import { CreateRequestDto } from './dto/create-request.dto';
import { UpdateRequestDto } from './dto/update-request.dto';
import { ApproveRequestDto } from './dto/approve-request.dto';
import { RejectRequestDto } from './dto/reject-request.dto';
import { SendBackForCorrectionDto } from './dto/send-back-for-correction.dto';
import { UsersService } from '../../users/users.service';
import { UserRole } from '../../users/schemas/user.schema';
import { NotificationsService } from '../../notifications/notifications.service';
import { NotificationType } from '../../notifications/schemas/notification.schema';
import { MapsService } from '../../maps/maps.service';
import { OfficesService } from '../../offices/offices.service';
import { EventEmitter2 } from '@nestjs/event-emitter';
import { HistoryUpdatedEvent, RequestUpdatedEvent } from '../../events/events';
import { WorkflowService } from '../../workflow/workflow.service';
import { WorkflowAction } from '../../workflow/schemas/workflow-actions.enum';
import { VehicleRequestStage } from '../../workflow/workflow-definition';

@Injectable()
export class VehicleRequestService {
  constructor(
    @InjectModel(VehicleRequest.name) private requestModel: Model<VehicleRequestDocument>,
    private usersService: UsersService,
    private notificationsService: NotificationsService,
    private mapsService: MapsService,
    private officesService: OfficesService,
    private eventEmitter: EventEmitter2,
    private workflowService: WorkflowService,
  ) {}

  /**
   * Estimate fuel consumption in litres based on distance (km) and a simple km-per-litre value.
   * This is intentionally conservative and can be refined later per-vehicle.
   */
  private calculateEstimatedFuelLitres(distanceKm?: number, kmPerLitre = 10): number | undefined {
    if (distanceKm === undefined || distanceKm === null) {
      return undefined;
    }
    if (distanceKm <= 0 || kmPerLitre <= 0) {
      return undefined;
    }
    const litres = distanceKm / kmPerLitre;
    // Round to 2 decimal places for nicer display
    return Math.round(litres * 100) / 100;
  }

  /**
   * Map workflow stage to status for backward compatibility
   */
  private mapStageToStatus(stage: string): RequestStatus {
    const stageMap: Record<string, RequestStatus> = {
      [VehicleRequestStage.SUBMITTED]: RequestStatus.PENDING,
      [VehicleRequestStage.SUPERVISOR_REVIEW]: RequestStatus.PENDING, // Waiting for supervisor approval
      [VehicleRequestStage.DGS_REVIEW]: RequestStatus.SUPERVISOR_APPROVED, // Supervisor approved, waiting for DGS
      [VehicleRequestStage.DDGS_REVIEW]: RequestStatus.DGS_APPROVED, // DGS approved, waiting for DDGS
      [VehicleRequestStage.AD_TRANSPORT_REVIEW]: RequestStatus.DDGS_APPROVED, // DDGS approved, waiting for AD Transport
      [VehicleRequestStage.TRANSPORT_OFFICER_ASSIGNMENT]: RequestStatus.AD_TRANSPORT_APPROVED, // AD Transport approved, waiting for TO
      [VehicleRequestStage.ASSIGNED]: RequestStatus.TRANSPORT_OFFICER_ASSIGNED, // Driver and vehicle assigned
      [VehicleRequestStage.IN_PROGRESS]: RequestStatus.IN_PROGRESS, // Trip in progress
      [VehicleRequestStage.COMPLETED]: RequestStatus.COMPLETED,
      [VehicleRequestStage.RETURNED]: RequestStatus.RETURNED,
      [VehicleRequestStage.REJECTED]: RequestStatus.REJECTED,
      [VehicleRequestStage.NEEDS_CORRECTION]: RequestStatus.NEEDS_CORRECTION,
      [VehicleRequestStage.CANCELLED]: RequestStatus.CANCELLED,
    };
    return stageMap[stage] || RequestStatus.PENDING;
  }

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

  private isUserRelatedToRequest(request: VehicleRequestDocument, userId: string): boolean {
    const normalizedUserId = userId.toString();
    const requesterId = this.extractId(request.requesterId);
    if (requesterId === normalizedUserId) {
      return true;
    }

    const supervisorId = request.supervisorId ? this.extractId(request.supervisorId) : undefined;
    if (supervisorId && supervisorId === normalizedUserId) {
      return true;
    }

    if (Array.isArray(request.approvalChain)) {
      for (const entry of request.approvalChain as any[]) {
        const approverId = entry?.approverId ? this.extractId(entry.approverId) : undefined;
        if (approverId && approverId === normalizedUserId) {
          return true;
        }
      }
    }

    return false;
  }

  async findHistoryForUser(userId: string): Promise<any[]> {
    const normalizedUserId = userId.toString();
    const requests = await this.requestModel
      .find({
        $or: [
          { requesterId: normalizedUserId },
          { supervisorId: normalizedUserId },
          { 'actionHistory.performedBy': normalizedUserId },
          { 'approvalChain.approverId': normalizedUserId },
        ],
      })
      .select([
        'requesterId',
        'supervisorId',
        'currentStage',
        'status',
        'purpose',
        'destination',
        'startDate',
        'endDate',
        'actionHistory',
        'approvalChain',
      ])
      .populate('requesterId', 'name email department')
      .populate('actionHistory.performedBy', 'name email')
      .lean();

    const historyEntries: any[] = [];

    for (const request of requests) {
      const requestId = request._id?.toString();
      const requester = request.requesterId;
      const requesterName = typeof requester === 'object' && requester !== null && 'name' in requester 
        ? (requester as any).name 
        : undefined;
      
      // Check if user is related to this request (works with lean documents)
      const requesterId = this.extractId(request.requesterId);
      const supervisorId = request.supervisorId ? this.extractId(request.supervisorId) : undefined;
      const isRequester = requesterId === normalizedUserId;
      const isSupervisor = supervisorId && supervisorId === normalizedUserId;
      let isInApprovalChain = false;
      if (Array.isArray(request.approvalChain)) {
        for (const entry of request.approvalChain as any[]) {
          const approverId = entry?.approverId ? this.extractId(entry.approverId) : undefined;
          if (approverId && approverId === normalizedUserId) {
            isInApprovalChain = true;
            break;
          }
        }
      }
      const isRelated = isRequester || isSupervisor || isInApprovalChain;

      if (!Array.isArray(request.actionHistory)) {
        continue;
      }

      // If user is related to the request, include ALL actions on that request
      // Otherwise, only include actions performed by the user
      for (const action of request.actionHistory) {
        const performedBy = action?.performedBy;
        const performerId = performedBy ? this.extractId(performedBy) : undefined;
        const includeEntry = isRelated || performerId === normalizedUserId;
        if (!includeEntry) {
          continue;
        }

        historyEntries.push({
          requestId,
          status: request.status,
          currentStage: request.currentStage,
          action: action?.action,
          stage: action?.stage,
          notes: action?.notes,
          performedAt: action?.performedAt,
          performedBy: performerId
            ? {
                id: performerId,
                name:
                  typeof performedBy === 'object' && performedBy !== null && 'name' in performedBy
                    ? (performedBy as any).name || (performedBy as any).fullName || (performedBy as any).email
                    : undefined,
              }
            : null,
          requester: requesterName
            ? {
                name: requesterName,
              }
            : null,
          summary: action?.metadata?.summary,
          metadata: action?.metadata || null,
        });
      }
    }

    historyEntries.sort((a, b) => {
      const dateA = a.performedAt ? new Date(a.performedAt).getTime() : 0;
      const dateB = b.performedAt ? new Date(b.performedAt).getTime() : 0;
      return dateB - dateA;
    });

    return historyEntries.slice(0, 100);
  }

  /**
   * Add action to action history
   */
  private addActionHistory(
    request: VehicleRequestDocument,
    action: WorkflowAction,
    performedBy: string,
    stage: string,
    notes?: string,
    metadata?: any,
  ): void {
    request.actionHistory.push({
      action,
      performedBy,
      performedAt: new Date(),
      stage,
      notes,
      metadata,
    } as any);

    // Also add to approval chain for backward compatibility
    request.approvalChain.push({
      approverId: performedBy,
      status: stage,
      timestamp: new Date(),
      comments: notes,
    } as any);

    if ((request as any)._id) {
      this.eventEmitter.emit(
        'history.updated',
        new HistoryUpdatedEvent(((request as any)._id).toString()),
      );
    }
  }

  async create(createRequestDto: CreateRequestDto, requesterId: string): Promise<VehicleRequestDocument> {
    // Validate dates
    const startDate = new Date(createRequestDto.startDate);
    const endDate = new Date(createRequestDto.endDate);
    const now = new Date();
    const oneHourFromNow = new Date(now.getTime() + 60 * 60 * 1000);

    if (startDate < oneHourFromNow) {
      throw new BadRequestException('Start date must be at least 1 hour in the future');
    }

    if (endDate <= startDate) {
      throw new BadRequestException('End date must be after start date');
    }

    // Get origin office coordinates
    const originOffice = await this.officesService.findById(createRequestDto.originOffice);
    if (!originOffice) {
      throw new NotFoundException('Origin office not found');
    }

    // Calculate estimated distance if destination coordinates are provided
    // Use destinationCoordinates if provided, otherwise use coordinates
    const destCoords = createRequestDto.destinationCoordinates || createRequestDto.coordinates;
    let estimatedDistance: number | undefined;
    if (destCoords && originOffice.coordinates) {
      try {
        const distanceResult = await this.mapsService.calculateDistance(
          originOffice.coordinates,
          destCoords,
        );
        estimatedDistance = distanceResult.distance;
      } catch (error) {
        console.error('Failed to calculate distance:', error);
      }
    }

    // Get requester info
    const requester = await this.usersService.findById(requesterId);
    if (!requester) {
      throw new NotFoundException('Requester not found');
    }

    // Get requester roles (default to STAFF if empty)
    const requesterRoles = requester.roles && requester.roles.length > 0 
      ? requester.roles 
      : [UserRole.STAFF];
    
    // Check if requester has STAFF role
    if (!requesterRoles.includes(UserRole.STAFF)) {
      throw new BadRequestException('Only staff members can create requests');
    }

    // Determine supervisorId to store
    let supervisorIdToStore: string | undefined;
    if (!requester.isSupervisor) {
      supervisorIdToStore = createRequestDto.supervisorId || requester.supervisorId;
      if (!supervisorIdToStore) {
        throw new BadRequestException('Supervisor must be selected or assigned for non-supervisor staff members');
      }
      
      // Validate supervisor
      const supervisor = await this.usersService.findById(supervisorIdToStore);
      if (!supervisor) {
        throw new NotFoundException('Selected supervisor not found');
      }
      if (supervisor.department !== requester.department) {
        throw new BadRequestException('Selected supervisor must be from the same department');
      }
      if (!supervisor.isSupervisor) {
        throw new BadRequestException('Selected user is not a supervisor');
      }
    }

    // Determine initial stage based on requester role
    // Non-supervisor: goes to SUPERVISOR_REVIEW
    // Supervisor: goes directly to DGS_REVIEW (skips supervisor)
    let initialStage: string;
    let initialStatus: RequestStatus;
    
    if (!requester.isSupervisor) {
      initialStage = VehicleRequestStage.SUPERVISOR_REVIEW;
      initialStatus = RequestStatus.PENDING; // At supervisor review, status is pending
    } else {
      initialStage = VehicleRequestStage.DGS_REVIEW;
      initialStatus = RequestStatus.PENDING; // At DGS review, status is pending
    }

    // Validate and process participant IDs
    let participantIds: string[] = [];
    if (createRequestDto.participantIds && createRequestDto.participantIds.length > 0) {
      // Validate that all participant IDs are valid users
      for (const participantId of createRequestDto.participantIds) {
        const participant = await this.usersService.findById(participantId);
        if (!participant) {
          throw new NotFoundException(`Participant with ID ${participantId} not found`);
        }
        // Don't add requester as participant (they're already the requester)
        if (participantId !== requesterId) {
          participantIds.push(participantId);
        }
      }
      // Remove duplicates
      participantIds = [...new Set(participantIds)];
    }

    // Build request object with workflow stage
    const requestData: any = {
      originOffice: createRequestDto.originOffice,
      destination: createRequestDto.destination,
      startDate,
      endDate,
      purpose: createRequestDto.purpose,
      passengerCount: createRequestDto.passengerCount,
      requesterId,
      currentStage: initialStage,
      status: initialStatus,
      estimatedDistance,
      estimatedFuelLitres: this.calculateEstimatedFuelLitres(estimatedDistance),
      actionHistory: [],
      correctionHistory: [],
      approvalChain: [],
    };

    // Set destinationCoordinates if provided
    if (createRequestDto.destinationCoordinates) {
      requestData.destinationCoordinates = createRequestDto.destinationCoordinates;
      // Automatically set coordinates to destinationCoordinates
      requestData.coordinates = createRequestDto.destinationCoordinates;
    } else if (createRequestDto.coordinates) {
      // If only coordinates is provided (without destinationCoordinates), use it for coordinates
      requestData.coordinates = createRequestDto.coordinates;
      // Also set destinationCoordinates to the same value
      requestData.destinationCoordinates = createRequestDto.coordinates;
    }

    if (supervisorIdToStore) {
      requestData.supervisorId = supervisorIdToStore;
    }

    if (participantIds.length > 0) {
      requestData.participantIds = participantIds;
    }

    const request = new this.requestModel(requestData);
    const savedRequest = await request.save();

    // Add creation action to history
    this.addActionHistory(
      savedRequest,
      WorkflowAction.APPROVE, // Creation moves request to first review stage
      requesterId,
      initialStage,
      'Request created and submitted',
    );

    // Determine next approver based on requester role
    let nextApprover: any = null;
    if (!requester.isSupervisor) {
      nextApprover = await this.usersService.findById(supervisorIdToStore!);
    } else {
      // Supervisor: goes directly to DGS
      const allUsers = await this.usersService.findAll();
      const dgsUsers = allUsers.filter(u => {
        const roles = u.roles && u.roles.length > 0 ? u.roles : [UserRole.STAFF];
        return roles.includes(UserRole.DGS);
      });
      nextApprover = dgsUsers[0];
    }

    // Send notification to next approver
    if (nextApprover) {
      await this.notificationsService.sendNotification(
        (nextApprover._id as any).toString(),
        NotificationType.REQUEST_CREATED,
        'New Vehicle Request',
        `A new vehicle request has been submitted by ${requester.name}`,
        (savedRequest._id as any).toString(),
      );
    }

    // Notify participants about the new request
    if (participantIds.length > 0) {
      await this.notificationsService.sendNotificationToMultipleUsers(
        participantIds,
        NotificationType.REQUEST_CREATED,
        'Vehicle Request Created',
        `You have been added as a participant to a vehicle request from ${requester.name}. Trip scheduled from ${startDate.toLocaleDateString()} to ${endDate.toLocaleDateString()}.`,
        (savedRequest._id as any).toString(),
      );
    }

    await savedRequest.save();
    this.eventEmitter.emit('request.updated', new RequestUpdatedEvent());

    return savedRequest;
  }

  async findAll(user: any): Promise<VehicleRequestDocument[]> {
    const userRoles = user.roles && user.roles.length > 0 
      ? user.roles 
      : [UserRole.STAFF];
    
    const isSupervisor = user.isSupervisor === true;
    
    // If user is ADMIN, return all vehicle requests (no filtering by stage or requester)
    if (userRoles.includes(UserRole.ADMIN)) {
      // Return all vehicle requests - VehicleRequest model only contains vehicle requests
      // No need to filter by requestType since this service uses the VehicleRequest model
      return this.requestModel
        .find({})
        .populate('requesterId', 'name email phone department')
        .populate('supervisorId', 'name email role')
        .populate('assignedDriverId', 'name email phone employeeId')
        .populate('assignedVehicleId', 'plateNumber make model capacity')
        .populate('pickupOffice', 'name address coordinates')
        .populate('actionHistory.performedBy', 'name email role')
        .populate('correctionHistory.requestedBy', 'name email')
        .populate('approvalChain.approverId', 'name email role')
        .populate('rejectedBy', 'name email')
        .populate('correctedBy', 'name email')
        .populate('cancelledBy', 'name email')
        .sort({ createdAt: -1 })
        .exec();
    }
    
    let query: any = {};
    const stages: string[] = [];

    // Get stages user can act on based on roles
    for (const role of userRoles) {
      const roleStages = this.getStagesForRole(role, isSupervisor);
      stages.push(...roleStages);
    }

    // If user has STAFF role, include their own requests
    if (userRoles.includes(UserRole.STAFF)) {
      const uniqueStages = [...new Set(stages)];
      const queryConditions: any[] = [{ requesterId: user._id }];
      
      if (isSupervisor) {
        queryConditions.push(
          {
            supervisorId: user._id,
            currentStage: VehicleRequestStage.SUPERVISOR_REVIEW,
          },
          {
            supervisorId: user._id,
            currentStage: VehicleRequestStage.SUBMITTED,
          },
        );
      }
      
      if (uniqueStages.length > 0) {
        queryConditions.push({ currentStage: { $in: uniqueStages } });
      }
      
      if (queryConditions.length > 1) {
        query.$or = queryConditions;
      } else {
        query = queryConditions[0];
      }
    } else {
      const uniqueStages = [...new Set(stages)];
      if (uniqueStages.length > 0) {
        query.currentStage = { $in: uniqueStages };
      }
    }

    return this.requestModel
      .find(query)
      .populate('requesterId', 'name email phone department')
      .populate('supervisorId', 'name email role')
      .populate('assignedDriverId', 'name email phone employeeId')
      .populate('assignedVehicleId', 'plateNumber make model capacity')
      .populate('pickupOffice', 'name address coordinates')
      .populate('actionHistory.performedBy', 'name email role')
      .populate('correctionHistory.requestedBy', 'name email')
      .populate('approvalChain.approverId', 'name email role')
      .populate('rejectedBy', 'name email')
      .populate('correctedBy', 'name email')
      .populate('cancelledBy', 'name email')
      .sort({ createdAt: -1 })
      .exec();
  }

  /**
   * Get stages a role can act on
   */
  private getStagesForRole(role: UserRole, isSupervisor: boolean): string[] {
    const stages: string[] = [];
    
    switch (role) {
      case UserRole.DGS:
        // DGS can assist with supervisor review (when supervisor unavailable) and owns the DGS review stage.
        // DGS can also assign vehicles (skip to Transport Officer)
        stages.push(
          VehicleRequestStage.SUPERVISOR_REVIEW,
          VehicleRequestStage.DGS_REVIEW,
          VehicleRequestStage.SUBMITTED,
          VehicleRequestStage.TRANSPORT_OFFICER_ASSIGNMENT,
        );
        break;
      case UserRole.DDGS:
        stages.push(VehicleRequestStage.DDGS_REVIEW);
        break;
      case UserRole.AD_TRANSPORT:
        stages.push(VehicleRequestStage.AD_TRANSPORT_REVIEW);
        break;
      case UserRole.TRANSPORT_OFFICER:
        stages.push(VehicleRequestStage.TRANSPORT_OFFICER_ASSIGNMENT);
        break;
      case UserRole.DRIVER:
        stages.push(VehicleRequestStage.ASSIGNED, VehicleRequestStage.IN_PROGRESS);
        break;
    }
    
    return stages;
  }

  async findById(id: string): Promise<VehicleRequestDocument> {
    // First, load without populating correctionHistory to avoid validation errors
    const request = await this.requestModel
      .findById(id)
      .populate('requesterId', 'name email phone department')
      .populate('supervisorId', 'name email role')
      .populate('assignedDriverId', 'name email phone employeeId')
      .populate('assignedVehicleId', 'plateNumber make model capacity')
      .populate('pickupOffice', 'name address coordinates')
      .populate('actionHistory.performedBy', 'name email role')
      .populate('approvalChain.approverId', 'name email role')
      .populate('rejectedBy', 'name email')
      .populate('correctedBy', 'name email')
      .populate('cancelledBy', 'name email')
      .exec();
      
    if (!request) {
      throw new NotFoundException('Request not found');
    }
    
    // Clean up invalid correctionHistory entries before populating
    this.cleanupInvalidCorrectionHistory(request);
    
    // If we cleaned up entries, save immediately to persist the cleanup
    if (request.isModified('correctionHistory')) {
      try {
        await request.save();
      } catch (error) {
        // If save fails due to validation, try to clean up more aggressively
        console.warn(`Warning: Failed to save cleaned correctionHistory for request ${id}, attempting aggressive cleanup`);
        this.cleanupInvalidCorrectionHistoryAggressive(request);
        await request.save();
      }
    }
    
    // Now populate correctionHistory.requestedBy safely
    await request.populate('correctionHistory.requestedBy', 'name email');
    
    return request;
  }

  /**
   * Helper method to clean up invalid correctionHistory entries
   */
  private cleanupInvalidCorrectionHistory(request: VehicleRequestDocument): void {
    if (!request.correctionHistory || request.correctionHistory.length === 0) {
      return;
    }

    const originalLength = request.correctionHistory.length;
    
    // Filter out invalid entries
    const validEntries = request.correctionHistory.filter((entry: any) => {
      if (!entry) {
        return false;
      }

      const requestedBy = entry.requestedBy;
      
      // If requestedBy is undefined, null, or empty, remove the entry
      if (!requestedBy) {
        return false;
      }

      // If it's an object (populated), check if it has _id
      if (typeof requestedBy === 'object' && requestedBy !== null) {
        // Check if it's a valid populated object with _id
        if (requestedBy._id !== undefined && requestedBy._id !== null) {
          return true;
        }
        // If it has id instead of _id
        if (requestedBy.id !== undefined && requestedBy.id !== null) {
          return true;
        }
        // If it's an empty object
        return false;
      }

      // If it's a string, check if it's not empty and is a valid ObjectId format
      if (typeof requestedBy === 'string') {
        const trimmed = requestedBy.trim();
        if (trimmed.length === 0) {
          return false;
        }
        // Basic ObjectId format check (24 hex characters)
        if (trimmed.length === 24 && /^[0-9a-fA-F]{24}$/.test(trimmed)) {
          return true;
        }
        // If it's not a valid ObjectId format, it might still be valid if it references a user
        // For now, we'll accept any non-empty string
        return true;
      }

      // If it's a number (ObjectId as number - shouldn't happen but handle it)
      if (typeof requestedBy === 'number') {
        return true;
      }

      // Otherwise, it's invalid
      return false;
    });

    // If we removed any entries, update the request
    if (validEntries.length < originalLength) {
      request.correctionHistory = validEntries;
      request.markModified('correctionHistory');
    }
  }

  /**
   * Aggressive cleanup - removes entries that fail validation
   */
  private cleanupInvalidCorrectionHistoryAggressive(request: VehicleRequestDocument): void {
    if (!request.correctionHistory || request.correctionHistory.length === 0) {
      return;
    }

    // Convert to plain objects and filter
    const validEntries = request.correctionHistory
      .map((entry: any) => {
        try {
          // Try to convert to plain object
          const plainEntry = entry.toObject ? entry.toObject() : entry;
          
          // Validate required fields
          if (!plainEntry.stage || !plainEntry.requestedBy || !plainEntry.requestedAt) {
            return null;
          }
          
          // Ensure requestedBy is a string (ObjectId)
          if (typeof plainEntry.requestedBy === 'object') {
            // If it's a populated object, extract the ID
            plainEntry.requestedBy = plainEntry.requestedBy._id?.toString() || plainEntry.requestedBy.id?.toString();
          }
          
          // Ensure requestedBy is a valid string
          if (!plainEntry.requestedBy || typeof plainEntry.requestedBy !== 'string') {
            return null;
          }
          
          return plainEntry;
        } catch (error) {
          // If we can't process this entry, remove it
          return null;
        }
      })
      .filter((entry: any) => entry !== null);

    request.correctionHistory = validEntries as any;
    request.markModified('correctionHistory');
  }

  async update(id: string, requesterId: string, updateDto: UpdateRequestDto): Promise<VehicleRequestDocument> {
    const request = await this.findById(id);

    const requestRequesterId = this.extractId(request.requesterId);
    const requesterIdStr = String(requesterId);

    if (requestRequesterId !== requesterIdStr) {
      throw new ForbiddenException('You can only update your own requests');
    }

    const currentStage = this.workflowService.getCurrentStage(request);
    
    // Only allow updates when needs correction or rejected
    if (currentStage !== VehicleRequestStage.NEEDS_CORRECTION && 
        currentStage !== VehicleRequestStage.REJECTED) {
      throw new BadRequestException('Request can only be updated when it needs correction or has been rejected');
    }

    // Update provided fields
    if (updateDto.originOffice !== undefined) {
      request.originOffice = updateDto.originOffice;
    }
    if (updateDto.destination !== undefined) {
      request.destination = updateDto.destination;
    }
    // Update destinationCoordinates and coordinates together
    if (updateDto.destinationCoordinates !== undefined) {
      request.destinationCoordinates = updateDto.destinationCoordinates;
      // Automatically update coordinates to match destinationCoordinates
      request.coordinates = updateDto.destinationCoordinates;
    } else if (updateDto.coordinates !== undefined) {
      // If only coordinates is provided, update both fields
      request.coordinates = updateDto.coordinates;
      request.destinationCoordinates = updateDto.coordinates;
    }
    if (updateDto.startDate !== undefined) {
      request.startDate = new Date(updateDto.startDate);
    }
    if (updateDto.endDate !== undefined) {
      request.endDate = new Date(updateDto.endDate);
    }
    if (updateDto.purpose !== undefined) {
      request.purpose = updateDto.purpose;
    }
    if (updateDto.passengerCount !== undefined) {
      request.passengerCount = updateDto.passengerCount;
    }
    if (updateDto.supervisorId !== undefined) {
      if (updateDto.supervisorId) {
        const supervisor = await this.usersService.findById(updateDto.supervisorId);
        if (!supervisor) {
          throw new NotFoundException('Supervisor not found');
        }
        if (!supervisor.isSupervisor) {
          throw new BadRequestException('Selected user is not a supervisor');
        }
        const requester = await this.usersService.findById(requesterId);
        if (requester && supervisor.department !== requester.department) {
          throw new BadRequestException('Selected supervisor must be from the same department');
        }
      }
      request.supervisorId = updateDto.supervisorId || undefined;
    }

    // Recalculate distance if destination or coordinates changed
    // Use destinationCoordinates if provided, otherwise use coordinates, or existing values
    const destinationCoords = updateDto.destinationCoordinates ||
      updateDto.coordinates ||
      request.destinationCoordinates ||
      request.coordinates;

    if (
      (updateDto.destination !== undefined ||
        updateDto.destinationCoordinates !== undefined ||
        updateDto.coordinates !== undefined) &&
      destinationCoords
    ) {
      try {
        const originOfficeId =
          updateDto.originOffice !== undefined
            ? updateDto.originOffice
            : request.originOffice.toString();
        const originOffice = await this.officesService.findById(originOfficeId);
        if (originOffice && originOffice.coordinates) {
          const distanceResult = await this.mapsService.calculateDistance(
            originOffice.coordinates,
            destinationCoords,
          );
          request.estimatedDistance = distanceResult.distance;
          request.estimatedFuelLitres = this.calculateEstimatedFuelLitres(
            request.estimatedDistance,
          );
        }
      } catch (error) {
        console.error('[RequestsService] Error calculating distance:', error);
      }
    }

    const updatedRequest = await request.save();

    await updatedRequest.populate('requesterId', 'name email phone department');
    await updatedRequest.populate('supervisorId', 'name email role');
    await updatedRequest.populate('assignedDriverId', 'name email phone employeeId');
    await updatedRequest.populate('assignedVehicleId', 'plateNumber make model capacity');
    await updatedRequest.populate('actionHistory.performedBy', 'name email role');
    await updatedRequest.populate('correctionHistory.requestedBy', 'name email');
    await updatedRequest.populate('approvalChain.approverId', 'name email role');
    await updatedRequest.populate('rejectedBy', 'name email');
    await updatedRequest.populate('correctedBy', 'name email');
    await updatedRequest.populate('cancelledBy', 'name email');

    this.eventEmitter.emit('request.updated', new RequestUpdatedEvent());

    return updatedRequest;
  }

  async approve(id: string, approverId: string, approveDto: ApproveRequestDto): Promise<VehicleRequestDocument> {
    const request = await this.findById(id);
    const approver = await this.usersService.findById(approverId);
    if (!approver) {
      throw new NotFoundException('Approver not found');
    }

    const currentStage = this.workflowService.getCurrentStage(request);

    // Cannot approve if needs correction
    if (currentStage === VehicleRequestStage.NEEDS_CORRECTION) {
      throw new BadRequestException('Request needs correction and must be resubmitted first');
    }

    // Execute workflow transition
    const { nextStage, transitionContext } = await this.workflowService.executeTransition(
      request,
      approver,
      WorkflowAction.APPROVE,
      { comments: approveDto.comments },
    );

    // Update request stage and status
    request.currentStage = nextStage;
    request.status = this.mapStageToStatus(nextStage);

    // Add to action history
    this.addActionHistory(
      request,
      WorkflowAction.APPROVE,
      (approver._id as any).toString(),
      currentStage,
      approveDto.comments,
    );

    // Mark arrays as modified
    request.markModified('actionHistory');
    request.markModified('approvalChain');

    const updatedRequest = await request.save();

    // Get requester for notification
    const requester = await this.usersService.findById(this.extractId(request.requesterId));

    // Notify requester
    if (requester) {
      await this.notificationsService.sendNotification(
        (requester._id as any).toString(),
        NotificationType.REQUEST_APPROVED,
        'Request Approved',
        `Your vehicle request has been approved by ${approver.name}`,
        (updatedRequest._id as any).toString(),
      );
    }

    // Notify next approver if not final stage
    if (!this.workflowService.isTerminal(nextStage) && nextStage !== VehicleRequestStage.TRANSPORT_OFFICER_ASSIGNMENT) {
      const nextApprover = await this.getNextApproverForStage(nextStage);
      if (nextApprover) {
        await this.notificationsService.sendNotification(
          (nextApprover._id as any).toString(),
          NotificationType.REQUEST_CREATED,
          'Vehicle Request Pending Approval',
          `A vehicle request is pending your approval`,
          (updatedRequest._id as any).toString(),
        );
      }
    }

    this.eventEmitter.emit('request.updated', new RequestUpdatedEvent());

    return updatedRequest;
  }

  async reject(id: string, approverId: string, rejectDto: RejectRequestDto): Promise<VehicleRequestDocument> {
    const request = await this.findById(id);
    const approver = await this.usersService.findById(approverId);
    if (!approver) {
      throw new NotFoundException('Approver not found');
    }

    const currentStage = this.workflowService.getCurrentStage(request);

    // Cannot reject if needs correction
    if (currentStage === VehicleRequestStage.NEEDS_CORRECTION) {
      throw new BadRequestException('Request needs correction and must be resubmitted first');
    }

    // Execute workflow transition
    const { nextStage } = await this.workflowService.executeTransition(
      request,
      approver,
      WorkflowAction.REJECT,
      { rejectionReason: rejectDto.rejectionReason },
    );

    // Update request stage and status
    request.currentStage = nextStage;
    request.status = this.mapStageToStatus(nextStage);

    // Add to action history
    this.addActionHistory(
      request,
      WorkflowAction.REJECT,
      (approver._id as any).toString(),
      currentStage,
      rejectDto.rejectionReason,
    );

    // Backward compatibility fields
    request.rejectionReason = rejectDto.rejectionReason;
    request.rejectedAt = new Date();
    request.rejectedBy = (approver._id as any).toString();

    request.markModified('actionHistory');
    request.markModified('approvalChain');

    const updatedRequest = await request.save();

    // Notify requester
    const requester = await this.usersService.findById(this.extractId(request.requesterId));
    if (requester) {
      await this.notificationsService.sendNotification(
        (requester._id as any).toString(),
        NotificationType.REQUEST_REJECTED,
        'Request Rejected',
        `Your vehicle request has been rejected: ${rejectDto.rejectionReason}`,
        (updatedRequest._id as any).toString(),
      );
    }

    this.eventEmitter.emit('request.updated', new RequestUpdatedEvent());

    return updatedRequest;
  }

  async sendBackForCorrection(
    id: string,
    approverId: string,
    correctionDto: SendBackForCorrectionDto,
  ): Promise<VehicleRequestDocument> {
    const request = await this.findById(id);
    const approver = await this.usersService.findById(approverId);
    if (!approver) {
      throw new NotFoundException('Approver not found');
    }

    const currentStage = this.workflowService.getCurrentStage(request);

    // Check if user can send back
    if (!(await this.workflowService.canSendBack(approver, request))) {
      throw new ForbiddenException('You do not have permission to send back this request for correction');
    }

    // Cannot send back if already rejected or needs correction
    if (currentStage === VehicleRequestStage.REJECTED) {
      throw new BadRequestException('Cannot send rejected request back for correction');
    }
    if (currentStage === VehicleRequestStage.NEEDS_CORRECTION) {
      throw new BadRequestException('Request already needs correction');
    }

    // Cannot send back at terminal stages
    const terminalStages = [
      VehicleRequestStage.COMPLETED,
      VehicleRequestStage.IN_PROGRESS,
      VehicleRequestStage.RETURNED,
      VehicleRequestStage.TRANSPORT_OFFICER_ASSIGNMENT,
    ];
    if (terminalStages.includes(currentStage as VehicleRequestStage)) {
      throw new BadRequestException(`Cannot send back request at ${currentStage} stage`);
    }

    // Execute workflow transition
    const { nextStage } = await this.workflowService.executeTransition(
      request,
      approver,
      WorkflowAction.SEND_BACK,
      { correctionNote: correctionDto.correctionNote },
    );

    // Update request stage and status
    request.currentStage = nextStage;
    request.status = this.mapStageToStatus(nextStage);

    // Add to action history
    this.addActionHistory(
      request,
      WorkflowAction.SEND_BACK,
      (approver._id as any).toString(),
      currentStage,
      correctionDto.correctionNote,
    );

    // Add to correction history - ensure all required fields are properly set
    // Ensure correctionHistory array exists
    if (!request.correctionHistory) {
      request.correctionHistory = [];
    }
    
    // Create correction entry with all required fields
    const correctionRequestedBy = (approver._id as any).toString();
    const correctionNoteText = correctionDto.correctionNote || 'No correction note provided';
    
    const correctionEntry = {
      stage: currentStage,
      requestedBy: correctionRequestedBy,
      requestedAt: new Date(),
      correctionNote: correctionNoteText,
      resubmissionCount: 1,
    };
    
    request.correctionHistory.push(correctionEntry as any);

    // Backward compatibility fields
    request.correctionNote = correctionDto.correctionNote;
    request.correctedAt = new Date();
    request.correctedBy = (approver._id as any).toString();
    request.sentBackToStatus = this.mapStageToStatus(currentStage) as any;

    request.markModified('actionHistory');
    request.markModified('correctionHistory');
    request.markModified('approvalChain');

    const updatedRequest = await request.save();

    // Notify requester
    const requester = await this.usersService.findById(this.extractId(request.requesterId));
    if (requester) {
      await this.notificationsService.sendNotification(
        (requester._id as any).toString(),
        NotificationType.REQUEST_NEEDS_CORRECTION,
        'Request Needs Correction',
        `Your vehicle request has been sent back for correction: ${correctionDto.correctionNote}`,
        (updatedRequest._id as any).toString(),
      );
    }

    this.eventEmitter.emit('request.updated', new RequestUpdatedEvent());

    return updatedRequest;
  }

  async cancel(id: string, requesterId: string, cancellationReason: string): Promise<VehicleRequestDocument> {
    const request = await this.findById(id);
    const requester = await this.usersService.findById(requesterId);
    if (!requester) {
      throw new NotFoundException('Requester not found');
    }

    const currentStage = this.workflowService.getCurrentStage(request);

    // Check if user can cancel
    if (!(await this.workflowService.canCancel(request, requester))) {
      throw new ForbiddenException('You do not have permission to cancel this request');
    }

    // Execute workflow transition
    const { nextStage } = await this.workflowService.executeTransition(
      request,
      requester,
      WorkflowAction.CANCEL,
      { cancellationReason },
    );

    // Update request stage and status
    request.currentStage = nextStage;
    request.status = this.mapStageToStatus(nextStage);

    // Add to action history
    this.addActionHistory(
      request,
      WorkflowAction.CANCEL,
      requesterId,
      currentStage,
      cancellationReason,
    );

    // Set cancellation fields
    request.cancellationReason = cancellationReason;
    request.cancelledAt = new Date();
    request.cancelledBy = requesterId;

    request.markModified('actionHistory');
    request.markModified('approvalChain');

    const updatedRequest = await request.save();

    // Notify relevant parties (supervisor, approvers in the chain)
    const notifyList: any[] = [];
    
    if (request.supervisorId) {
      const supervisor = await this.usersService.findById(this.extractId(request.supervisorId));
      if (supervisor) notifyList.push(supervisor);
    }

    // Notify approvers who have acted on the request
    for (const action of request.actionHistory) {
      const approver = await this.usersService.findById(action.performedBy);
      if (approver && !notifyList.find(u => this.extractId(u._id) === this.extractId(approver._id))) {
        notifyList.push(approver);
      }
    }

    for (const user of notifyList) {
      await this.notificationsService.sendNotification(
        (user._id as any).toString(),
        NotificationType.REQUEST_REJECTED, // Use rejected type for cancellation
        'Request Cancelled',
        `Vehicle request has been cancelled by ${requester.name}: ${cancellationReason}`,
        (updatedRequest._id as any).toString(),
      );
    }

    this.eventEmitter.emit('request.updated', new RequestUpdatedEvent());

    return updatedRequest;
  }

  async resubmit(id: string, requesterId: string): Promise<VehicleRequestDocument> {
    const request = await this.findById(id);

    const requestRequesterId = this.extractId(request.requesterId);
    const requesterIdStr = String(requesterId);

    if (requestRequesterId !== requesterIdStr) {
      throw new ForbiddenException('You can only resubmit your own requests');
    }

    const currentStage = this.workflowService.getCurrentStage(request);

    if (currentStage !== VehicleRequestStage.REJECTED && 
        currentStage !== VehicleRequestStage.NEEDS_CORRECTION) {
      throw new BadRequestException('Only rejected or needs correction requests can be resubmitted');
    }

    // Get latest correction entry if exists
    let latestCorrection: any = null;
    if (request.correctionHistory && request.correctionHistory.length > 0) {
      latestCorrection = request.correctionHistory[request.correctionHistory.length - 1];
      // Update resubmission count
      if (latestCorrection) {
        latestCorrection.resubmissionCount = (latestCorrection.resubmissionCount || 0) + 1;
        latestCorrection.resolvedAt = new Date();
      }
    }

    // Execute workflow transition
    const { nextStage } = await this.workflowService.executeTransition(
      request,
      await this.usersService.findById(requesterId),
      WorkflowAction.RESUBMIT,
    );

    // Update request stage and status
    request.currentStage = nextStage;
    request.status = this.mapStageToStatus(nextStage);

    // Add to action history
    this.addActionHistory(
      request,
      WorkflowAction.RESUBMIT,
      requesterId,
      currentStage,
      'Request resubmitted after correction',
    );

    // Clear backward compatibility fields
    if (currentStage === VehicleRequestStage.NEEDS_CORRECTION) {
      request.correctionNote = undefined;
      request.correctedAt = undefined;
      request.correctedBy = undefined;
      request.sentBackToStatus = undefined;
    } else {
      request.rejectionReason = undefined;
      request.rejectedAt = undefined;
      request.rejectedBy = undefined;
    }

    request.resubmittedAt = new Date();

    request.markModified('actionHistory');
    request.markModified('correctionHistory');
    request.markModified('approvalChain');

    const updatedRequest = await request.save();

    // Determine who to notify (supervisor or approver at correction stage)
    let notifyTarget: any = null;
    
    if (request.supervisorId && !request.requesterId || this.extractId(request.requesterId) !== this.extractId(request.supervisorId)) {
      notifyTarget = await this.usersService.findById(this.extractId(request.supervisorId));
    } else if (latestCorrection) {
      notifyTarget = await this.usersService.findById(latestCorrection.requestedBy);
    }

    if (notifyTarget) {
      const correctionNote = latestCorrection?.correctionNote || '';
      const message = correctionNote
        ? `A vehicle request has been corrected and resubmitted. Correction note: "${correctionNote}". It is pending your review.`
        : `A vehicle request has been corrected and resubmitted. It is pending your review.`;
      
      await this.notificationsService.sendNotification(
        (notifyTarget._id as any).toString(),
        NotificationType.REQUEST_RESUBMITTED,
        'Request Resubmitted',
        message,
        (updatedRequest._id as any).toString(),
      );
    }
    
    // Also notify approvers who have already worked on the request
    if (request.actionHistory && request.actionHistory.length > 0) {
      const approverIds = new Set<string>();
      for (const action of request.actionHistory) {
        if (action.performedBy && action.action !== WorkflowAction.CANCEL) {
          approverIds.add(action.performedBy);
        }
      }
      
      for (const approverId of approverIds) {
        if (approverId !== notifyTarget?._id?.toString()) {
          const approver = await this.usersService.findById(approverId);
          if (approver) {
            await this.notificationsService.sendNotification(
              (approver._id as any).toString(),
              NotificationType.REQUEST_RESUBMITTED,
              'Request Resubmitted',
              'A vehicle request has been corrected and resubmitted. It is pending review again.',
              (updatedRequest._id as any).toString(),
            );
          }
        }
      }
    }

    this.eventEmitter.emit('request.updated', new RequestUpdatedEvent());

    return updatedRequest;
  }

  /**
   * Get next approver for a stage
   */
  private async getNextApproverForStage(stage: string): Promise<any> {
    switch (stage) {
      case VehicleRequestStage.SUPERVISOR_REVIEW:
        const dgsUsers = await this.usersService.findByRole(UserRole.DGS);
        return dgsUsers[0];
      case VehicleRequestStage.DGS_REVIEW:
        const ddgsUsers = await this.usersService.findByRole(UserRole.DDGS);
        return ddgsUsers[0];
      case VehicleRequestStage.DDGS_REVIEW:
        const adTransportUsers = await this.usersService.findByRole(UserRole.AD_TRANSPORT);
        return adTransportUsers[0];
      case VehicleRequestStage.AD_TRANSPORT_REVIEW:
        const transportOfficers = await this.usersService.findByRole(UserRole.TRANSPORT_OFFICER);
        return transportOfficers[0];
      default:
        return null;
    }
  }

  /**
   * Temporary method to add coordinates to an existing vehicle request
   * @param requestId - The ID of the vehicle request
   * @param coordinates - The coordinates to add (lat, lng)
   * @returns The updated vehicle request
   */
  async addCoordinates(requestId: string, coordinates: { lat: number; lng: number }): Promise<VehicleRequestDocument> {
    const request = await this.requestModel.findById(requestId);
    if (!request) {
      throw new NotFoundException('Vehicle request not found');
    }

    // Set both coordinates and destinationCoordinates to the same value
    request.coordinates = coordinates;
    request.destinationCoordinates = coordinates;
    return request.save();
  }

  /**
   * Temporary method to batch add coordinates to multiple vehicle requests
   * @param requests - Array of requestId and coordinates pairs
   * @returns Summary of successful and failed updates
   */
  async batchAddCoordinates(
    requests: Array<{ requestId: string; coordinates: { lat: number; lng: number } }>,
  ): Promise<{ success: number; failed: number; errors: any[] }> {
    let success = 0;
    let failed = 0;
    const errors: any[] = [];

    for (const item of requests) {
      try {
        await this.addCoordinates(item.requestId, item.coordinates);
        success++;
      } catch (error) {
        failed++;
        errors.push({
          requestId: item.requestId,
          error: error.message,
        });
      }
    }

    return { success, failed, errors };
  }
}

