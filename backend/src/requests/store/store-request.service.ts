import { Injectable, NotFoundException, BadRequestException, ForbiddenException } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model } from 'mongoose';
import { StoreRequest, StoreRequestDocument, StoreRequestStatus } from './schemas/store-request.schema';
import { CreateStoreRequestDto } from './dto/create-store-request.dto';
import { UpdateStoreRequestDto } from './dto/update-store-request.dto';
import { ApproveRequestDto } from './dto/approve-request.dto';
import { RejectRequestDto } from './dto/reject-request.dto';
import { SendBackForCorrectionDto } from './dto/send-back-for-correction.dto';
import { UsersService } from '../../users/users.service';
import { UserRole } from '../../users/schemas/user.schema';
import { NotificationsService } from '../../notifications/notifications.service';
import { NotificationType } from '../../notifications/schemas/notification.schema';
import { EventEmitter2 } from '@nestjs/event-emitter';
import { HistoryUpdatedEvent, RequestUpdatedEvent } from '../../events/events';
import { WorkflowAction } from '../../workflow/schemas/workflow-actions.enum';
import { StoreRequestStage, getStoreWorkflowStage, getStoreInitialStage, isStoreTerminalStage } from '../../workflow/store-workflow-definition';
import { RequestType } from '../base/request-type.enum';

@Injectable()
export class StoreRequestService {
  constructor(
    @InjectModel(StoreRequest.name) private requestModel: Model<StoreRequestDocument>,
    private usersService: UsersService,
    private notificationsService: NotificationsService,
    private eventEmitter: EventEmitter2,
  ) {}

  private mapStageToStatus(stage: string): StoreRequestStatus {
    const stageMap: Record<string, StoreRequestStatus> = {
      [StoreRequestStage.SUBMITTED]: StoreRequestStatus.PENDING,
      [StoreRequestStage.SUPERVISOR_REVIEW]: StoreRequestStatus.PENDING,
      [StoreRequestStage.STORE_OFFICER_REVIEW]: StoreRequestStatus.SUPERVISOR_APPROVED,
      [StoreRequestStage.APPROVED]: StoreRequestStatus.APPROVED,
      [StoreRequestStage.REJECTED]: StoreRequestStatus.REJECTED,
      [StoreRequestStage.NEEDS_CORRECTION]: StoreRequestStatus.NEEDS_CORRECTION,
      [StoreRequestStage.CANCELLED]: StoreRequestStatus.CANCELLED,
      [StoreRequestStage.FULFILLED]: StoreRequestStatus.FULFILLED,
    };
    return stageMap[stage] || StoreRequestStatus.PENDING;
  }

  private extractId(ref: any): string {
    if (ref === undefined || ref === null) return '';
    if (typeof ref === 'object' && ref !== null && !(ref instanceof Date)) {
      return ref._id?.toString() || ref.id?.toString() || String(ref);
    }
    return String(ref);
  }

  private addActionHistory(
    request: StoreRequestDocument,
    action: WorkflowAction,
    performedBy: string,
    stage: string,
    notes?: string,
  ) {
    if (!request.actionHistory) {
      request.actionHistory = [];
    }
    request.actionHistory.push({
      action,
      performedBy,
      performedAt: new Date(),
      stage,
      notes,
    } as any);

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

  async create(createDto: CreateStoreRequestDto, requesterId: string): Promise<StoreRequestDocument> {
    const requester = await this.usersService.findById(requesterId);
    if (!requester) {
      throw new NotFoundException('Requester not found');
    }

    const requesterRoles = requester.roles && requester.roles.length > 0 
      ? requester.roles 
      : [UserRole.STAFF];
    
    if (!requesterRoles.includes(UserRole.STAFF)) {
      throw new BadRequestException('Only staff members can create requests');
    }

    let supervisorIdToStore: string | undefined;
    if (!requester.isSupervisor) {
      supervisorIdToStore = createDto.supervisorId || requester.supervisorId;
      if (!supervisorIdToStore) {
        throw new BadRequestException('Supervisor must be selected or assigned');
      }
      
      const supervisor = await this.usersService.findById(supervisorIdToStore);
      if (!supervisor || !supervisor.isSupervisor) {
        throw new BadRequestException('Selected supervisor not found or invalid');
      }
    }

    const initialStage = StoreRequestStage.SUPERVISOR_REVIEW;
    const initialStatus = StoreRequestStatus.PENDING;

    const requestData: any = {
      requestType: RequestType.STORE,
      requesterId,
      itemName: createDto.itemName,
      category: createDto.category,
      quantity: createDto.quantity,
      unit: createDto.unit,
      specifications: createDto.specifications,
      purpose: createDto.purpose,
      urgency: createDto.urgency || 'normal',
      estimatedCost: createDto.estimatedCost,
      justification: createDto.justification,
      currentStage: initialStage,
      status: initialStatus,
      actionHistory: [],
      correctionHistory: [],
      approvalChain: [],
    };

    if (supervisorIdToStore) {
      requestData.supervisorId = supervisorIdToStore;
    }

    const request = new this.requestModel(requestData);
    const savedRequest = await request.save();

    this.addActionHistory(
      savedRequest,
      WorkflowAction.APPROVE,
      requesterId,
      initialStage,
      'Store request created',
    );

    let nextApprover: any = null;
    if (supervisorIdToStore) {
      nextApprover = await this.usersService.findById(supervisorIdToStore);
    }

    if (nextApprover) {
      await this.notificationsService.sendNotification(
        (nextApprover._id as any).toString(),
        NotificationType.REQUEST_CREATED,
        'New Store Request',
        `A new store request has been submitted by ${requester.name}`,
        (savedRequest._id as any).toString(),
      );
    }

    await savedRequest.save();
    this.eventEmitter.emit('request.updated', new RequestUpdatedEvent());

    return savedRequest;
  }

  async findAll(user: any): Promise<StoreRequestDocument[]> {
    const userRoles = user.roles && user.roles.length > 0 ? user.roles : [UserRole.STAFF];
    const isSupervisor = user.isSupervisor === true;
    let query: any = {};

    if (userRoles.includes(UserRole.STAFF)) {
      const queryConditions: any[] = [{ requesterId: user._id }];
      
      if (isSupervisor) {
        queryConditions.push({
          supervisorId: user._id,
          currentStage: StoreRequestStage.SUPERVISOR_REVIEW,
        });
      }
      
      if (userRoles.includes(UserRole.ADMIN)) {
        queryConditions.push({ currentStage: StoreRequestStage.STORE_OFFICER_REVIEW });
      }
      
      query = queryConditions.length > 1 ? { $or: queryConditions } : queryConditions[0];
    } else if (userRoles.includes(UserRole.ADMIN)) {
      query.currentStage = StoreRequestStage.STORE_OFFICER_REVIEW;
    }

    return this.requestModel
      .find(query)
      .populate('requesterId', 'name email phone department')
      .populate('supervisorId', 'name email role')
      .populate('actionHistory.performedBy', 'name email role')
      .populate('correctionHistory.requestedBy', 'name email')
      .populate('approvalChain.approverId', 'name email role')
      .sort({ createdAt: -1 })
      .exec();
  }

  async findById(id: string): Promise<StoreRequestDocument> {
    const request = await this.requestModel
      .findById(id)
      .populate('requesterId', 'name email phone department')
      .populate('supervisorId', 'name email role')
      .populate('actionHistory.performedBy', 'name email role')
      .populate('approvalChain.approverId', 'name email role')
      .exec();
      
    if (!request) {
      throw new NotFoundException('Store request not found');
    }
    
    return request;
  }

  async approve(id: string, approverId: string, approveDto: ApproveRequestDto): Promise<StoreRequestDocument> {
    const request = await this.findById(id);
    const approver = await this.usersService.findById(approverId);
    if (!approver) {
      throw new NotFoundException('Approver not found');
    }

    const currentStage = request.currentStage;

    if (currentStage === StoreRequestStage.NEEDS_CORRECTION) {
      throw new BadRequestException('Request needs correction and must be resubmitted first');
    }

    const workflowStage = getStoreWorkflowStage(currentStage);
    if (!workflowStage) {
      throw new BadRequestException('Invalid workflow stage');
    }

    let nextStage: string;
    if (currentStage === StoreRequestStage.SUPERVISOR_REVIEW) {
      nextStage = StoreRequestStage.STORE_OFFICER_REVIEW;
    } else if (currentStage === StoreRequestStage.STORE_OFFICER_REVIEW) {
      nextStage = StoreRequestStage.APPROVED;
    } else {
      throw new BadRequestException('Cannot approve at current stage');
    }

    request.currentStage = nextStage;
    request.status = this.mapStageToStatus(nextStage);

    this.addActionHistory(
      request,
      WorkflowAction.APPROVE,
      (approver._id as any).toString(),
      currentStage,
      approveDto.comments,
    );

    request.markModified('actionHistory');
    request.markModified('approvalChain');

    const updatedRequest = await request.save();

    const requester = await this.usersService.findById(this.extractId(request.requesterId));
    if (requester) {
      await this.notificationsService.sendNotification(
        (requester._id as any).toString(),
        NotificationType.REQUEST_APPROVED,
        'Store Request Approved',
        `Your store request has been approved by ${approver.name}`,
        (updatedRequest._id as any).toString(),
      );
    }

    this.eventEmitter.emit('request.updated', new RequestUpdatedEvent());
    return updatedRequest;
  }

  async reject(id: string, approverId: string, rejectDto: RejectRequestDto): Promise<StoreRequestDocument> {
    const request = await this.findById(id);
    const approver = await this.usersService.findById(approverId);
    if (!approver) {
      throw new NotFoundException('Approver not found');
    }

    request.currentStage = StoreRequestStage.REJECTED;
    request.status = StoreRequestStatus.REJECTED;
    request.rejectionReason = rejectDto.rejectionReason;
    request.rejectedAt = new Date();
    request.rejectedBy = (approver._id as any).toString();

    this.addActionHistory(
      request,
      WorkflowAction.REJECT,
      (approver._id as any).toString(),
      request.currentStage,
      rejectDto.rejectionReason,
    );

    request.markModified('actionHistory');
    const updatedRequest = await request.save();

    const requester = await this.usersService.findById(this.extractId(request.requesterId));
    if (requester) {
      await this.notificationsService.sendNotification(
        (requester._id as any).toString(),
        NotificationType.REQUEST_REJECTED,
        'Store Request Rejected',
        `Your store request has been rejected: ${rejectDto.rejectionReason}`,
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
  ): Promise<StoreRequestDocument> {
    const request = await this.findById(id);
    const approver = await this.usersService.findById(approverId);
    if (!approver) {
      throw new NotFoundException('Approver not found');
    }

    request.currentStage = StoreRequestStage.NEEDS_CORRECTION;
    request.status = StoreRequestStatus.NEEDS_CORRECTION;
    request.correctionNote = correctionDto.correctionNote;
    request.correctedAt = new Date();
    request.correctedBy = (approver._id as any).toString();

    if (!request.correctionHistory) {
      request.correctionHistory = [];
    }
    request.correctionHistory.push({
      stage: request.currentStage,
      requestedBy: (approver._id as any).toString(),
      requestedAt: new Date(),
      correctionNote: correctionDto.correctionNote,
      resubmissionCount: 1,
    } as any);

    this.addActionHistory(
      request,
      WorkflowAction.SEND_BACK,
      (approver._id as any).toString(),
      request.currentStage,
      correctionDto.correctionNote,
    );

    request.markModified('actionHistory');
    request.markModified('correctionHistory');
    const updatedRequest = await request.save();

    const requester = await this.usersService.findById(this.extractId(request.requesterId));
    if (requester) {
      await this.notificationsService.sendNotification(
        (requester._id as any).toString(),
        NotificationType.REQUEST_NEEDS_CORRECTION,
        'Store Request Needs Correction',
        `Your store request needs correction: ${correctionDto.correctionNote}`,
        (updatedRequest._id as any).toString(),
      );
    }

    this.eventEmitter.emit('request.updated', new RequestUpdatedEvent());
    return updatedRequest;
  }

  async resubmit(id: string, requesterId: string): Promise<StoreRequestDocument> {
    const request = await this.findById(id);
    
    if (this.extractId(request.requesterId) !== requesterId) {
      throw new ForbiddenException('Only the requester can resubmit');
    }

    if (request.currentStage !== StoreRequestStage.NEEDS_CORRECTION && 
        request.currentStage !== StoreRequestStage.REJECTED) {
      throw new BadRequestException('Request cannot be resubmitted at current stage');
    }

    request.currentStage = StoreRequestStage.SUPERVISOR_REVIEW;
    request.status = StoreRequestStatus.PENDING;
    request.resubmittedAt = new Date();

    this.addActionHistory(
      request,
      WorkflowAction.RESUBMIT,
      requesterId,
      StoreRequestStage.SUPERVISOR_REVIEW,
      'Request resubmitted',
    );

    request.markModified('actionHistory');
    const updatedRequest = await request.save();

    this.eventEmitter.emit('request.updated', new RequestUpdatedEvent());
    return updatedRequest;
  }

  async cancel(id: string, requesterId: string, cancellationReason: string): Promise<StoreRequestDocument> {
    const request = await this.findById(id);
    
    if (this.extractId(request.requesterId) !== requesterId) {
      throw new ForbiddenException('Only the requester can cancel');
    }

    if (isStoreTerminalStage(request.currentStage)) {
      throw new BadRequestException('Cannot cancel a request in terminal stage');
    }

    request.currentStage = StoreRequestStage.CANCELLED;
    request.status = StoreRequestStatus.CANCELLED;
    request.cancellationReason = cancellationReason;
    request.cancelledAt = new Date();
    request.cancelledBy = requesterId;

    this.addActionHistory(
      request,
      WorkflowAction.CANCEL,
      requesterId,
      request.currentStage,
      cancellationReason,
    );

    request.markModified('actionHistory');
    const updatedRequest = await request.save();

    this.eventEmitter.emit('request.updated', new RequestUpdatedEvent());
    return updatedRequest;
  }

  async findHistoryForUser(userId: string): Promise<any[]> {
    const requests = await this.requestModel
      .find({
        $or: [
          { requesterId: userId },
          { supervisorId: userId },
          { 'actionHistory.performedBy': userId },
        ],
      })
      .select([
        'requesterId',
        'supervisorId',
        'currentStage',
        'status',
        'item',
        'quantity',
        'actionHistory',
      ])
      .populate('requesterId', 'name email')
      .populate('supervisorId', 'name email')
      .populate('actionHistory.performedBy', 'name email')
      .sort({ createdAt: -1 })
      .lean()
      .exec();

    return requests;
  }
}

