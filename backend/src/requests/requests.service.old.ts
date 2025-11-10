import { Injectable, NotFoundException, BadRequestException, ForbiddenException } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model } from 'mongoose';
import { VehicleRequest, VehicleRequestDocument, RequestStatus } from './schemas/vehicle-request.schema';
import { CreateRequestDto } from './dto/create-request.dto';
import { UpdateRequestDto } from './dto/update-request.dto';
import { ApproveRequestDto } from './dto/approve-request.dto';
import { RejectRequestDto } from './dto/reject-request.dto';
import { SendBackForCorrectionDto } from './dto/send-back-for-correction.dto';
import { UsersService } from '../users/users.service';
import { UserRole } from '../users/schemas/user.schema';
import { NotificationsService } from '../notifications/notifications.service';
import { NotificationType } from '../notifications/schemas/notification.schema';
import { MapsService } from '../maps/maps.service';
import { OfficesService } from '../offices/offices.service';
import { EventEmitter2 } from '@nestjs/event-emitter';
import { HistoryUpdatedEvent, RequestUpdatedEvent } from '../events/events';

@Injectable()
export class RequestsService {
  constructor(
    @InjectModel(VehicleRequest.name) private requestModel: Model<VehicleRequestDocument>,
    private usersService: UsersService,
    private notificationsService: NotificationsService,
    private mapsService: MapsService,
    private officesService: OfficesService,
    private eventEmitter: EventEmitter2,
  ) {}

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
    let estimatedDistance: number | undefined;
    if (createRequestDto.destinationCoordinates) {
      try {
        const distanceResult = await this.mapsService.calculateDistance(
          originOffice.coordinates,
          createRequestDto.destinationCoordinates,
        );
        estimatedDistance = distanceResult.distance;
      } catch (error) {
        console.error('Failed to calculate distance:', error);
      }
    }

    // Get requester info first
    const requester = await this.usersService.findById(requesterId);
    if (!requester) {
      throw new NotFoundException('Requester not found');
    }

    // Determine supervisorId to store
    let supervisorIdToStore: string | undefined;
    if (!requester.isSupervisor) {
      // Non-supervisor: store the selected supervisor
      supervisorIdToStore = createRequestDto.supervisorId || requester.supervisorId;
      // Validate that supervisorId is provided for non-supervisor requesters
      if (!supervisorIdToStore) {
        throw new BadRequestException('Supervisor must be selected or assigned for non-supervisor staff members');
      }
    }
    // If requester is supervisor, supervisorId remains undefined (goes directly to DGS)

    // Build request object, ensuring supervisorId is set correctly
    const requestData: any = {
      originOffice: createRequestDto.originOffice,
      destination: createRequestDto.destination,
      startDate,
      endDate,
      purpose: createRequestDto.purpose,
      passengerCount: createRequestDto.passengerCount,
      requesterId,
      status: RequestStatus.PENDING,
      estimatedDistance,
    };

    // Add optional fields
    if (createRequestDto.destinationCoordinates) {
      requestData.destinationCoordinates = createRequestDto.destinationCoordinates;
    }

    // Set supervisorId explicitly (only for non-supervisor requesters)
    if (supervisorIdToStore) {
      requestData.supervisorId = supervisorIdToStore;
      console.log(`[RequestsService] Setting supervisorId: ${supervisorIdToStore} for requester: ${requesterId}`);
    } else {
      console.log(`[RequestsService] No supervisorId to store. Requester isSupervisor: ${requester.isSupervisor}, DTO supervisorId: ${createRequestDto.supervisorId}, Requester supervisorId: ${requester.supervisorId}`);
    }

    console.log(`[RequestsService] Creating request with data:`, JSON.stringify(requestData, null, 2));

    const request = new this.requestModel(requestData);

    const savedRequest = await request.save();
    console.log(`[RequestsService] Saved request ID: ${savedRequest._id}, supervisorId: ${savedRequest.supervisorId}`);

    // Get requester roles (default to STAFF if empty)
    const requesterRoles = requester.roles && requester.roles.length > 0 
      ? requester.roles 
      : [UserRole.STAFF];
    
    // Check if requester has STAFF role
    if (!requesterRoles.includes(UserRole.STAFF)) {
      throw new BadRequestException('Only staff members can create requests');
    }

    // Determine next approver based on requester role
    let nextApprover: any = null;
    if (!requester.isSupervisor) {
      // Non-supervisor: goes to supervisor
      // Use selected supervisorId from request if provided, otherwise use assigned supervisorId
      const supervisorId = createRequestDto.supervisorId || requester.supervisorId;
      if (supervisorId) {
        nextApprover = await this.usersService.findById(supervisorId);
        if (!nextApprover) {
          throw new NotFoundException('Selected supervisor not found');
        }
        // Validate that the supervisor is in the same department
        if (nextApprover.department !== requester.department) {
          throw new BadRequestException('Selected supervisor must be from the same department');
        }
        // Validate that the supervisor is actually a supervisor
        if (!nextApprover.isSupervisor) {
          throw new BadRequestException('Selected user is not a supervisor');
        }
      } else {
        throw new BadRequestException('Supervisor not selected or assigned to this staff member');
      }
    } else {
      // Supervisor: goes directly to DGS
      // Find users with DGS role (checking roles array)
      const allUsers = await this.usersService.findAll();
      const dgsUsers = allUsers.filter(u => {
        const roles = u.roles && u.roles.length > 0 ? u.roles : [UserRole.STAFF];
        return roles.includes(UserRole.DGS);
      });
      nextApprover = dgsUsers[0]; // Get first DGS user
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

    // Emit request updated event
    this.eventEmitter.emit('request.updated', new RequestUpdatedEvent());

    return savedRequest;
  }

  async findAll(user: any): Promise<VehicleRequestDocument[]> {
    // Get user roles (default to STAFF if empty)
    const userRoles = user.roles && user.roles.length > 0 
      ? user.roles 
      : [UserRole.STAFF];
    
    const isSupervisor = user.isSupervisor === true;
    let query: any = {};
    const allStatuses: RequestStatus[] = [];
    
    // Collect statuses from all user roles
    for (const role of userRoles) {
      const statuses = this.getPendingStatusesForRole(role);
      allStatuses.push(...statuses);
    }
    
    // If user has STAFF role, include their own requests
    if (userRoles.includes(UserRole.STAFF)) {
      // Combine: own requests OR requests pending approval from any role OR requests assigned to this supervisor
      const uniqueStatuses = [...new Set(allStatuses)];
      const queryConditions: any[] = [
        { requesterId: user._id }
      ];
      
      // If user is a supervisor, include requests assigned to them (only pending, not needs_correction)
      if (isSupervisor) {
        queryConditions.push({ 
          supervisorId: user._id, 
          status: RequestStatus.PENDING
        });
      }
      
      // Add status-based conditions if any
      if (uniqueStatuses.length > 0) {
        queryConditions.push({ status: { $in: uniqueStatuses } });
      }
      
      if (queryConditions.length > 1) {
        query.$or = queryConditions;
      } else {
        query = queryConditions[0];
      }
    } else {
      // For approvers without STAFF role, return requests pending their approval
      const uniqueStatuses = [...new Set(allStatuses)];
      if (uniqueStatuses.length > 0) {
        query.status = { $in: uniqueStatuses };
      }
      // Admin can see all (no query filter if no specific statuses)
    }

    return this.requestModel
      .find(query)
      .populate('requesterId', 'name email phone department')
      .populate('supervisorId', 'name email role')
      .populate('assignedDriverId', 'name email phone employeeId')
      .populate('assignedVehicleId', 'plateNumber make model capacity')
      .populate('approvalChain.approverId', 'name email role')
      .populate('rejectedBy', 'name email')
      .populate('correctedBy', 'name email')
      .sort({ createdAt: -1 })
      .exec();
  }

  async findById(id: string): Promise<VehicleRequestDocument> {
    const request = await this.requestModel
      .findById(id)
      .populate('requesterId', 'name email phone department')
      .populate('supervisorId', 'name email role')
      .populate('assignedDriverId', 'name email phone employeeId')
      .populate('assignedVehicleId', 'plateNumber make model capacity')
      .populate('approvalChain.approverId', 'name email role')
      .populate('rejectedBy', 'name email')
      .populate('correctedBy', 'name email')
      .exec();
    if (!request) {
      throw new NotFoundException('Request not found');
    }
    return request;
  }

  async update(id: string, requesterId: string, updateDto: UpdateRequestDto): Promise<VehicleRequestDocument> {
    const request = await this.findById(id);

    // Verify requester matches - handle both populated (object) and non-populated (string/ObjectId) cases
    let requestRequesterId: string;
    const requesterIdValue = request.requesterId as any;
    if (typeof requesterIdValue === 'object' && requesterIdValue !== null && !(requesterIdValue instanceof Date)) {
      // Populated - extract _id from the object
      requestRequesterId = requesterIdValue._id?.toString() ||
                            requesterIdValue.id?.toString() ||
                            String(requesterIdValue);
    } else {
      // Not populated - it's already a string/ObjectId
      requestRequesterId = String(requesterIdValue);
    }

    const requesterIdStr = String(requesterId);
    
    console.log('[RequestsService] Update validation:', {
      requestRequesterId,
      requesterIdStr,
      match: requestRequesterId === requesterIdStr,
      requesterIdType: typeof request.requesterId,
      requesterIdValue: request.requesterId,
    });

    if (requestRequesterId !== requesterIdStr) {
      throw new ForbiddenException('You can only update your own requests');
    }

    // Only allow updates when status is needs_correction or rejected
    if (request.status !== RequestStatus.NEEDS_CORRECTION && request.status !== RequestStatus.REJECTED) {
      throw new BadRequestException('Request can only be updated when it needs correction or has been rejected');
    }

    // Update provided fields
    if (updateDto.originOffice !== undefined) {
      request.originOffice = updateDto.originOffice;
    }
    if (updateDto.destination !== undefined) {
      request.destination = updateDto.destination;
    }
    if (updateDto.destinationCoordinates !== undefined) {
      request.destinationCoordinates = updateDto.destinationCoordinates;
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
      // Validate supervisor if provided
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

    // Recalculate distance if destination changed
    if (updateDto.destination !== undefined && updateDto.destinationCoordinates) {
      try {
        const originOfficeId = updateDto.originOffice !== undefined 
          ? updateDto.originOffice 
          : request.originOffice.toString();
        const originOffice = await this.officesService.findById(originOfficeId);
        if (originOffice && originOffice.coordinates) {
          const distanceResult = await this.mapsService.calculateDistance(
            originOffice.coordinates,
            updateDto.destinationCoordinates,
          );
          request.estimatedDistance = distanceResult.distance;
        }
      } catch (error) {
        console.error('[RequestsService] Error calculating distance:', error);
        // Don't fail the update if distance calculation fails
      }
    }

    const updatedRequest = await request.save();

    // Populate before returning
    await updatedRequest.populate('requesterId', 'name email phone department');
    await updatedRequest.populate('supervisorId', 'name email role');
    await updatedRequest.populate('assignedDriverId', 'name email phone employeeId');
    await updatedRequest.populate('assignedVehicleId', 'plateNumber make model capacity');
    await updatedRequest.populate('approvalChain.approverId', 'name email role');
    await updatedRequest.populate('rejectedBy', 'name email');
    await updatedRequest.populate('correctedBy', 'name email');

    // Emit request updated event
    this.eventEmitter.emit('request.updated', new RequestUpdatedEvent());

    return updatedRequest;
  }

  async approve(id: string, approverId: string, approveDto: ApproveRequestDto): Promise<VehicleRequestDocument> {
    const request = await this.findById(id);
    const approver = await this.usersService.findById(approverId);
    if (!approver) {
      throw new NotFoundException('Approver not found');
    }

    // Cannot approve if needs correction - must be resubmitted first
    if (request.status === RequestStatus.NEEDS_CORRECTION) {
      throw new BadRequestException('Request needs correction and must be resubmitted first');
    }

    // Check if user can approve this request
    this.validateApprovalPermission(request, approver);

    // Add to approval chain
    request.approvalChain.push({
      approverId: (approver._id as any).toString(),
      status: request.status,
      timestamp: new Date(),
      comments: approveDto.comments,
    });

    // Get approver roles (default to empty array if none)
    const approverRoles = approver.roles && approver.roles.length > 0 
      ? approver.roles 
      : [];
    
    // Determine next status based on approver type
    let nextStatus: RequestStatus;
    const isSupervisor = approver.isSupervisor === true;
    const hasDGSRole = approverRoles.includes(UserRole.DGS);
    
    if (request.status === RequestStatus.PENDING) {
      // If approver is DGS, skip supervisor approval
      if (hasDGSRole) {
        nextStatus = RequestStatus.DGS_APPROVED;
      } else if (isSupervisor) {
        // Supervisor approval moves to SUPERVISOR_APPROVED
        nextStatus = RequestStatus.SUPERVISOR_APPROVED;
      } else {
        // Fallback: use role-based logic
        const approverRole = approverRoles[0];
        nextStatus = this.getNextStatus(request.status, approverRole);
      }
    } else {
      // For other statuses, use role-based logic
      const approverRole = approverRoles[0];
      if (!approverRole) {
        throw new BadRequestException('Approver must have a role to approve requests at this stage');
      }
      nextStatus = this.getNextStatus(request.status, approverRole);
    }
    
    console.log(`[RequestsService] Approval: status ${request.status} -> ${nextStatus}, approver isSupervisor: ${isSupervisor}, hasDGSRole: ${hasDGSRole}, approverRoles: ${JSON.stringify(approverRoles)}`);
    request.status = nextStatus;

    const updatedRequest = await request.save();

    // Get requester for notification
    const requester = await this.usersService.findById(request.requesterId.toString());

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

    // Notify next approver if not final approval
    if (nextStatus !== RequestStatus.AD_TRANSPORT_APPROVED) {
      const nextApprover = await this.getNextApprover(nextStatus);
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

    // Emit request updated event
    this.eventEmitter.emit('request.updated', new RequestUpdatedEvent());

    return updatedRequest;
  }

  async reject(id: string, approverId: string, rejectDto: RejectRequestDto): Promise<VehicleRequestDocument> {
    const request = await this.findById(id);
    const approver = await this.usersService.findById(approverId);
    if (!approver) {
      throw new NotFoundException('Approver not found');
    }

    // Cannot reject if needs correction - must be resubmitted first
    if (request.status === RequestStatus.NEEDS_CORRECTION) {
      throw new BadRequestException('Request needs correction and must be resubmitted first');
    }

    // Check if user can reject this request
    this.validateApprovalPermission(request, approver);

    // Add to approval chain
    request.approvalChain.push({
      approverId: (approver._id as any).toString(),
      status: 'rejected',
      timestamp: new Date(),
      comments: rejectDto.rejectionReason,
    });

    request.status = RequestStatus.REJECTED;
    request.rejectionReason = rejectDto.rejectionReason;
    request.rejectedAt = new Date();
    request.rejectedBy = (approver._id as any).toString();

    const updatedRequest = await request.save();

    // Notify requester
    const requester = await this.usersService.findById(request.requesterId.toString());
    if (requester) {
      await this.notificationsService.sendNotification(
        (requester._id as any).toString(),
        NotificationType.REQUEST_REJECTED,
        'Request Rejected',
        `Your vehicle request has been rejected: ${rejectDto.rejectionReason}`,
        (updatedRequest._id as any).toString(),
      );
    }

    // Emit request updated event
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

    // Check if user can send back for correction (same permissions as approve/reject)
    this.validateApprovalPermission(request, approver);

    // Cannot send back if already rejected or needs correction
    if (request.status === RequestStatus.REJECTED) {
      throw new BadRequestException('Cannot send rejected request back for correction');
    }
    if (request.status === RequestStatus.NEEDS_CORRECTION) {
      throw new BadRequestException('Request already needs correction');
    }

    // Cannot send back at terminal stages
    const terminalStatuses = [
      RequestStatus.COMPLETED,
      RequestStatus.IN_PROGRESS,
      RequestStatus.RETURNED,
      RequestStatus.DRIVER_ACCEPTED,
      RequestStatus.TRANSPORT_OFFICER_ASSIGNED,
    ];
    if (terminalStatuses.includes(request.status)) {
      throw new BadRequestException(`Cannot send back request at ${request.status} stage`);
    }

    // Store the current status to resume from after correction
    const currentStatus = request.status;

    // Add correction entry to approval chain
    request.approvalChain.push({
      approverId: (approver._id as any).toString(),
      status: 'needs_correction',
      timestamp: new Date(),
      comments: correctionDto.correctionNote,
    });

    // Mark approvalChain as modified to ensure Mongoose tracks the change
    request.markModified('approvalChain');

    // Set status to needs correction
    request.status = RequestStatus.NEEDS_CORRECTION;
    request.correctionNote = correctionDto.correctionNote;
    request.correctedAt = new Date();
    request.correctedBy = (approver._id as any).toString();
    request.sentBackToStatus = currentStatus;

    console.log('[RequestsService] Sending back for correction - Setting status to:', RequestStatus.NEEDS_CORRECTION);
    console.log('[RequestsService] Correction note:', correctionDto.correctionNote);
    console.log('[RequestsService] Current status before correction:', currentStatus);
    console.log('[RequestsService] Fields to save:', {
      status: request.status,
      correctionNote: request.correctionNote,
      correctedAt: request.correctedAt,
      correctedBy: request.correctedBy,
      sentBackToStatus: request.sentBackToStatus,
      approvalChainLength: request.approvalChain.length,
    });
    
    try {
      const updatedRequest = await request.save();
      
      console.log('[RequestsService] Request saved successfully');
      console.log('[RequestsService] Request saved - Status:', updatedRequest.status);
      console.log('[RequestsService] Request saved - CorrectionNote:', updatedRequest.correctionNote);
      console.log('[RequestsService] Request saved - CorrectedAt:', updatedRequest.correctedAt);
      console.log('[RequestsService] Request saved - CorrectedBy:', updatedRequest.correctedBy);
      console.log('[RequestsService] Request saved - SentBackToStatus:', updatedRequest.sentBackToStatus);
      
      // Populate before returning to ensure all fields are included
      await updatedRequest.populate('supervisorId', 'name email role');
      await updatedRequest.populate('requesterId', 'name email role');
      await updatedRequest.populate('correctedBy', 'name email');
      
      console.log('[RequestsService] Request populated - Final status:', updatedRequest.status);

      // Notify requester
      // Handle both populated (object) and non-populated (string/ObjectId) requesterId
      let requesterId: string;
      const requesterIdValue = request.requesterId as any;
      if (typeof requesterIdValue === 'object' && requesterIdValue !== null && !(requesterIdValue instanceof Date)) {
        // Populated - extract _id from the object
        requesterId = requesterIdValue._id?.toString() || 
                      requesterIdValue.id?.toString() ||
                      String(requesterIdValue);
      } else {
        // Not populated - it's already a string/ObjectId
        requesterId = String(requesterIdValue);
      }
      const requester = await this.usersService.findById(requesterId);
      if (requester) {
        await this.notificationsService.sendNotification(
          (requester._id as any).toString(),
          NotificationType.REQUEST_NEEDS_CORRECTION,
          'Request Needs Correction',
          `Your vehicle request has been sent back for correction: ${correctionDto.correctionNote}`,
          (updatedRequest._id as any).toString(),
        );
      }

      // Emit request updated event
      this.eventEmitter.emit('request.updated', new RequestUpdatedEvent());

      return updatedRequest;
    } catch (error) {
      console.error('[RequestsService] Error saving correction:', error);
      throw error;
    }
  }

  async resubmit(id: string, requesterId: string): Promise<VehicleRequestDocument> {
    const request = await this.findById(id);

    // Verify requester matches - handle both populated (object) and non-populated (string/ObjectId) cases
    let requestRequesterId: string;
    const requesterIdValue = request.requesterId as any;
    if (typeof requesterIdValue === 'object' && requesterIdValue !== null && !(requesterIdValue instanceof Date)) {
      // Populated - extract _id from the object
      requestRequesterId = requesterIdValue._id?.toString() ||
                            requesterIdValue.id?.toString() ||
                            String(requesterIdValue);
    } else {
      // Not populated - it's already a string/ObjectId
      requestRequesterId = String(requesterIdValue);
    }

    const requesterIdStr = String(requesterId);
    
    console.log('[RequestsService] Resubmit validation:', {
      requestRequesterId,
      requesterIdStr,
      match: requestRequesterId === requesterIdStr,
      currentStatus: request.status,
    });

    if (requestRequesterId !== requesterIdStr) {
      throw new ForbiddenException('You can only resubmit your own requests');
    }

    if (request.status !== RequestStatus.REJECTED && request.status !== RequestStatus.NEEDS_CORRECTION) {
      throw new BadRequestException('Only rejected or needs correction requests can be resubmitted');
    }

    let correctionOrRejectionEntry;
    let correctionOrRejectionIndex;
    let resumeStatus: RequestStatus;

    if (request.status === RequestStatus.NEEDS_CORRECTION) {
      // Find the LATEST correction point in approval chain (most recent correction)
      // Search from the end to find the most recent correction entry
      let latestCorrectionIndex = -1;
      for (let i = request.approvalChain.length - 1; i >= 0; i--) {
        if (request.approvalChain[i].status === 'needs_correction') {
          latestCorrectionIndex = i;
          break;
        }
      }

      if (latestCorrectionIndex === -1) {
        throw new BadRequestException('Correction entry not found');
      }

      correctionOrRejectionEntry = request.approvalChain[latestCorrectionIndex];
      correctionOrRejectionIndex = latestCorrectionIndex;

      // Clear correction metadata fields (but keep entries in approval chain for audit trail)
      request.correctionNote = undefined;
      request.correctedAt = undefined;
      request.correctedBy = undefined;
      request.sentBackToStatus = undefined;
    } else {
      // Find the rejection point in approval chain
      correctionOrRejectionEntry = request.approvalChain
        .slice()
        .reverse()
        .find((entry) => entry.status === 'rejected');

      if (!correctionOrRejectionEntry) {
        throw new BadRequestException('Rejection entry not found');
      }

      correctionOrRejectionIndex = request.approvalChain.findIndex(
        (entry) => entry.approverId === correctionOrRejectionEntry.approverId && entry.status === 'rejected',
      );

      // Clear rejection fields
      request.rejectionReason = undefined;
      request.rejectedAt = undefined;
      request.rejectedBy = undefined;
    }

    // Always set status to PENDING when resubmitting (per plan requirements)
    request.status = RequestStatus.PENDING;
    request.resubmittedAt = new Date();

    // Mark approvalChain as modified if we're keeping all entries (which we are)
    // This ensures Mongoose tracks any changes
    request.markModified('approvalChain');

    console.log('[RequestsService] Before save - Status:', request.status);
    console.log('[RequestsService] Before save - ResubmittedAt:', request.resubmittedAt);
    
    const updatedRequest = await request.save();
    
    console.log('[RequestsService] After save - Status:', updatedRequest.status);
    console.log('[RequestsService] After save - ResubmittedAt:', updatedRequest.resubmittedAt);

    // Notify the assigned supervisor (primary notification)
    if (request.supervisorId) {
      // Handle both populated (object) and non-populated (string/ObjectId) cases
      let supervisorIdStr: string;
      const supervisorIdValue = request.supervisorId as any;
      if (typeof supervisorIdValue === 'object' && supervisorIdValue !== null && !(supervisorIdValue instanceof Date)) {
        supervisorIdStr = supervisorIdValue._id?.toString() ||
                          supervisorIdValue.id?.toString() ||
                          String(supervisorIdValue);
      } else {
        supervisorIdStr = String(supervisorIdValue);
      }
      
      const supervisor = await this.usersService.findById(supervisorIdStr);
      if (supervisor) {
        const correctionNote = request.approvalChain
          .slice()
          .reverse()
          .find((entry) => entry.status === 'needs_correction')?.comments || '';
        
        const notificationMessage = correctionNote
          ? `A vehicle request has been corrected and resubmitted. Correction note: "${correctionNote}". It is pending your review.`
          : `A vehicle request has been corrected and resubmitted. It is pending your review.`;
        
        await this.notificationsService.sendNotification(
          (supervisor._id as any).toString(),
          NotificationType.REQUEST_RESUBMITTED,
          'Request Resubmitted',
          notificationMessage,
          (updatedRequest._id as any).toString(),
        );
      }
    }

    // Also notify approvers who have already worked on the request
    // (those with entries in approval chain before the correction/rejection point)
    const approversToNotify = request.approvalChain
      .slice(0, correctionOrRejectionIndex)
      .filter((entry) => entry.status !== 'rejected' && entry.status !== 'needs_correction')
      .map((entry) => entry.approverId);

    // Remove duplicates and exclude supervisor (already notified above)
    const supervisorIdStr = request.supervisorId?.toString();
    const uniqueApproverIds = [...new Set(approversToNotify)].filter(
      (id) => id !== supervisorIdStr
    );

    // Get correction note for notification (if available)
    const correctionNote = request.approvalChain
      .slice()
      .reverse()
      .find((entry) => entry.status === 'needs_correction')?.comments || '';

    for (const approverId of uniqueApproverIds) {
      const approver = await this.usersService.findById(approverId);
      if (approver) {
        const notificationMessage = correctionNote
          ? `A vehicle request has been corrected and resubmitted. Correction note: "${correctionNote}". It is pending review again.`
          : `A vehicle request has been corrected and resubmitted. It is pending review again.`;
        
        await this.notificationsService.sendNotification(
          (approver._id as any).toString(),
          NotificationType.REQUEST_RESUBMITTED,
          'Request Resubmitted',
          notificationMessage,
          (updatedRequest._id as any).toString(),
        );
      }
    }

    // Notify the approver at correction/rejection point (if different from supervisor)
    const correctionOrRejectionApprover = await this.usersService.findById(correctionOrRejectionEntry.approverId);
    if (correctionOrRejectionApprover && correctionOrRejectionEntry.approverId !== supervisorIdStr) {
      const correctionNote = correctionOrRejectionEntry.comments || '';
      const notificationMessage = correctionNote
        ? `A vehicle request has been corrected and resubmitted. Correction note: "${correctionNote}". It is pending your review.`
        : `A vehicle request has been corrected and resubmitted. It is pending your review.`;
      
      await this.notificationsService.sendNotification(
        (correctionOrRejectionApprover._id as any).toString(),
        NotificationType.REQUEST_RESUBMITTED,
        'Request Resubmitted',
        notificationMessage,
        (updatedRequest._id as any).toString(),
      );
    }

    // Emit request updated event
    this.eventEmitter.emit('request.updated', new RequestUpdatedEvent());

    return updatedRequest;
  }

  private validateApprovalPermission(request: VehicleRequestDocument, approver: any): void {
    const requiredRole = this.getRequiredRoleForStatus(request.status);
    
    // Get approver roles (default to empty array if none)
    const approverRoles = approver.roles && approver.roles.length > 0 
      ? approver.roles 
      : [];
    
    // Special handling for PENDING status: allow supervisors or DGS
    if (request.status === RequestStatus.PENDING) {
      const isSupervisor = approver.isSupervisor === true;
      const hasDGSRole = approverRoles.includes(UserRole.DGS);
      
      // If approver is a supervisor, verify they are assigned to this request
      if (isSupervisor) {
        // Handle both populated (object) and non-populated (string/ObjectId) supervisorId
        let requestSupervisorId: string | undefined;
        if (request.supervisorId) {
          const supervisorIdValue = request.supervisorId as any;
          if (typeof supervisorIdValue === 'object' && supervisorIdValue !== null && !(supervisorIdValue instanceof Date)) {
            // Populated - extract _id from the object
            requestSupervisorId = supervisorIdValue._id?.toString() || 
                                  supervisorIdValue.id?.toString() ||
                                  String(supervisorIdValue);
          } else {
            // Not populated - it's already a string/ObjectId
            requestSupervisorId = String(supervisorIdValue);
          }
        }
        
        const approverId = (approver._id as any).toString();
        
        console.log('[RequestsService] Supervisor validation:', {
          requestSupervisorId,
          approverId,
          match: requestSupervisorId === approverId,
          supervisorIdType: typeof request.supervisorId,
          supervisorIdValue: request.supervisorId,
        });
        
        if (!requestSupervisorId || requestSupervisorId !== approverId) {
          throw new ForbiddenException('You can only approve requests assigned to you as supervisor');
        }
      }
      
      // DGS can approve any PENDING request (no supervisorId check needed)
      if (!isSupervisor && !hasDGSRole) {
        throw new ForbiddenException('You do not have permission to approve this request. Only supervisors assigned to this request or DGS can approve pending requests.');
      }
      return; // Early return for pending requests
    }
    
    // For other statuses, check role as before
    if (!approverRoles.includes(requiredRole)) {
      throw new ForbiddenException('You do not have permission to approve this request');
    }
  }

  private getRequiredRoleForStatus(status: RequestStatus): UserRole {
    switch (status) {
      case RequestStatus.PENDING:
        return UserRole.STAFF; // Supervisor or DGS
      case RequestStatus.SUPERVISOR_APPROVED:
        return UserRole.DGS;
      case RequestStatus.DGS_APPROVED:
        return UserRole.DDGS;
      case RequestStatus.DDGS_APPROVED:
        return UserRole.AD_TRANSPORT;
      case RequestStatus.AD_TRANSPORT_APPROVED:
        return UserRole.TRANSPORT_OFFICER;
      default:
        throw new BadRequestException('Invalid status for approval');
    }
  }

  private getNextStatus(currentStatus: RequestStatus, approverRole: UserRole): RequestStatus {
    switch (currentStatus) {
      case RequestStatus.PENDING:
        if (approverRole === UserRole.DGS) {
          return RequestStatus.DGS_APPROVED;
        }
        return RequestStatus.SUPERVISOR_APPROVED;
      case RequestStatus.SUPERVISOR_APPROVED:
        return RequestStatus.DGS_APPROVED;
      case RequestStatus.DGS_APPROVED:
        return RequestStatus.DDGS_APPROVED;
      case RequestStatus.DDGS_APPROVED:
        return RequestStatus.AD_TRANSPORT_APPROVED;
      default:
        throw new BadRequestException('Invalid status transition');
    }
  }

  private getStatusAfter(status: RequestStatus): RequestStatus {
    switch (status) {
      case RequestStatus.PENDING:
        return RequestStatus.SUPERVISOR_APPROVED;
      case RequestStatus.SUPERVISOR_APPROVED:
        return RequestStatus.DGS_APPROVED;
      case RequestStatus.DGS_APPROVED:
        return RequestStatus.DDGS_APPROVED;
      case RequestStatus.DDGS_APPROVED:
        return RequestStatus.AD_TRANSPORT_APPROVED;
      default:
        return RequestStatus.PENDING;
    }
  }

  private getPendingStatusesForRole(role: UserRole): RequestStatus[] {
    switch (role) {
      case UserRole.DGS:
        return [RequestStatus.PENDING, RequestStatus.SUPERVISOR_APPROVED];
      case UserRole.DDGS:
        return [RequestStatus.DGS_APPROVED];
      case UserRole.AD_TRANSPORT:
        return [RequestStatus.DDGS_APPROVED];
      case UserRole.TRANSPORT_OFFICER:
        return [RequestStatus.AD_TRANSPORT_APPROVED];
      default:
        return [];
    }
  }

  private async getNextApprover(status: RequestStatus): Promise<any> {
    switch (status) {
      case RequestStatus.SUPERVISOR_APPROVED:
        const dgsUsers = await this.usersService.findByRole(UserRole.DGS);
        return dgsUsers[0];
      case RequestStatus.DGS_APPROVED:
        const ddgsUsers = await this.usersService.findByRole(UserRole.DDGS);
        return ddgsUsers[0];
      case RequestStatus.DDGS_APPROVED:
        const adTransportUsers = await this.usersService.findByRole(UserRole.AD_TRANSPORT);
        return adTransportUsers[0];
      default:
        return null;
    }
  }

  private addActionToHistory(
    request: VehicleRequestDocument,
    action: string,
    performedBy: string,
    stage: RequestStatus,
    notes: string,
    metadata: any,
  ) {
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
}

