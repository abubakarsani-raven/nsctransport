import { Controller, Get, Post, Put, Body, Param, UseGuards, Request, NotFoundException, BadRequestException } from '@nestjs/common';
import { Types } from 'mongoose';
import { VehicleRequestService } from './vehicle/vehicle-request.service';
import { IctRequestService } from './ict/ict-request.service';
import { StoreRequestService } from './store/store-request.service';
import { CreateRequestDto } from './vehicle/dto/create-request.dto';
import { UpdateRequestDto } from './vehicle/dto/update-request.dto';
import { ApproveRequestDto } from './vehicle/dto/approve-request.dto';
import { RejectRequestDto } from './vehicle/dto/reject-request.dto';
import { SendBackForCorrectionDto } from './vehicle/dto/send-back-for-correction.dto';
import { CancelRequestDto } from './vehicle/dto/cancel-request.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { UserRole } from '../users/schemas/user.schema';

@Controller('requests')
@UseGuards(JwtAuthGuard)
export class RequestsController {
  constructor(
    private vehicleRequestService: VehicleRequestService,
    private ictRequestService: IctRequestService,
    private storeRequestService: StoreRequestService,
  ) {}

  @Post()
  @UseGuards(RolesGuard)
  @Roles(UserRole.STAFF)
  async create(@Body() createRequestDto: CreateRequestDto, @Request() req) {
    return this.vehicleRequestService.create(createRequestDto, req.user._id.toString());
  }

  @Get()
  async findAll(@Request() req) {
    return this.vehicleRequestService.findAll(req.user);
  }

  @Get('history')
  async history(@Request() req) {
    const userId = req.user._id.toString();
    
    // Get history from all request types
    const [vehicleHistory, ictHistory, storeHistory] = await Promise.all([
      this.vehicleRequestService.findHistoryForUser(userId),
      this.ictRequestService.findHistoryForUser(userId),
      this.storeRequestService.findHistoryForUser(userId),
    ]);

    // Helper to extract ID from populated or non-populated references
    const extractId = (ref: any): string => {
      if (ref === undefined || ref === null) {
        return '';
      }
      if (typeof ref === 'object' && ref !== null && !(ref instanceof Date)) {
        return ref._id?.toString() || ref.id?.toString() || String(ref);
      }
      return String(ref);
    };

    // Format ICT and Store history to match Vehicle history format
    const formatHistoryEntries = (requests: any[], requestType: string) => {
      const entries: any[] = [];
      for (const request of requests) {
        const requestId = request._id?.toString();
        const requester = request.requesterId;
        const requesterName = typeof requester === 'object' && requester !== null && 'name' in requester 
          ? (requester as any).name 
          : undefined;

        // Check if user is related to this request
        const requesterId = extractId(request.requesterId);
        const supervisorId = request.supervisorId ? extractId(request.supervisorId) : undefined;
        const isRequester = requesterId === userId;
        const isSupervisor = supervisorId && supervisorId === userId;
        const isRelated = isRequester || isSupervisor;

        if (!Array.isArray(request.actionHistory)) {
          continue;
        }

        // If user is related to the request, include ALL actions on that request
        // Otherwise, only include actions performed by the user
        for (const action of request.actionHistory) {
          const performedBy = action?.performedBy;
          const performerId = performedBy ? extractId(performedBy) : undefined;
          const includeEntry = isRelated || performerId === userId;
          if (!includeEntry) {
            continue;
          }

          entries.push({
            requestId,
            requestType,
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
      return entries;
    };

    // Format all histories
    const formattedIctHistory = formatHistoryEntries(ictHistory, 'ict');
    const formattedStoreHistory = formatHistoryEntries(storeHistory, 'store');

    // Combine all histories
    const allHistory = [
      ...vehicleHistory.map((entry: any) => ({ ...entry, requestType: 'vehicle' })),
      ...formattedIctHistory,
      ...formattedStoreHistory,
    ];

    // Sort by performedAt descending
    allHistory.sort((a, b) => {
      const dateA = a.performedAt ? new Date(a.performedAt).getTime() : 0;
      const dateB = b.performedAt ? new Date(b.performedAt).getTime() : 0;
      return dateB - dateA;
    });

    return allHistory.slice(0, 100); // Limit to 100 most recent entries
  }

  @Get(':id')
  async findOne(@Param('id') id: string) {
    // Prevent route conflicts with /requests/vehicle, /requests/ict, /requests/store
    // NestJS should match more specific routes first, but this is a safety check
    if (id === 'vehicle' || id === 'ict' || id === 'store' || id === 'history') {
      throw new NotFoundException(`Route /requests/${id} is handled by a different controller. Please use the specific endpoint.`);
    }
    
    // Validate that id is a valid ObjectId
    if (!Types.ObjectId.isValid(id)) {
      throw new BadRequestException('Invalid request ID format');
    }
    
    return this.vehicleRequestService.findById(id);
  }

  @Put(':id')
  @UseGuards(RolesGuard)
  @Roles(UserRole.STAFF)
  async update(@Param('id') id: string, @Body() updateDto: UpdateRequestDto, @Request() req) {
    // Prevent route conflicts
    if (id === 'vehicle' || id === 'ict' || id === 'store' || id === 'history') {
      throw new NotFoundException(`Route /requests/${id} is handled by a different controller`);
    }
    
    // Validate that id is a valid ObjectId
    if (!Types.ObjectId.isValid(id)) {
      throw new BadRequestException('Invalid request ID format');
    }
    
    return this.vehicleRequestService.update(id, req.user._id.toString(), updateDto);
  }

  @Put(':id/approve')
  async approve(@Param('id') id: string, @Body() approveDto: ApproveRequestDto, @Request() req) {
    // Prevent route conflicts
    if (id === 'vehicle' || id === 'ict' || id === 'store' || id === 'history') {
      throw new NotFoundException(`Route /requests/${id} is handled by a different controller`);
    }
    
    // Validate that id is a valid ObjectId
    if (!Types.ObjectId.isValid(id)) {
      throw new BadRequestException('Invalid request ID format');
    }
    
    return this.vehicleRequestService.approve(id, req.user._id.toString(), approveDto);
  }

  @Put(':id/reject')
  async reject(@Param('id') id: string, @Body() rejectDto: RejectRequestDto, @Request() req) {
    // Prevent route conflicts
    if (id === 'vehicle' || id === 'ict' || id === 'store' || id === 'history') {
      throw new NotFoundException(`Route /requests/${id} is handled by a different controller`);
    }
    
    // Validate that id is a valid ObjectId
    if (!Types.ObjectId.isValid(id)) {
      throw new BadRequestException('Invalid request ID format');
    }
    
    return this.vehicleRequestService.reject(id, req.user._id.toString(), rejectDto);
  }

  @Put(':id/resubmit')
  @UseGuards(RolesGuard)
  @Roles(UserRole.STAFF)
  async resubmit(@Param('id') id: string, @Request() req) {
    // Prevent route conflicts
    if (id === 'vehicle' || id === 'ict' || id === 'store' || id === 'history') {
      throw new NotFoundException(`Route /requests/${id} is handled by a different controller`);
    }
    
    // Validate that id is a valid ObjectId
    if (!Types.ObjectId.isValid(id)) {
      throw new BadRequestException('Invalid request ID format');
    }
    
    return this.vehicleRequestService.resubmit(id, req.user._id.toString());
  }

  @Put(':id/send-back-for-correction')
  async sendBackForCorrection(
    @Param('id') id: string,
    @Body() correctionDto: SendBackForCorrectionDto,
    @Request() req,
  ) {
    // Prevent route conflicts
    if (id === 'vehicle' || id === 'ict' || id === 'store' || id === 'history') {
      throw new NotFoundException(`Route /requests/${id} is handled by a different controller`);
    }
    
    // Validate that id is a valid ObjectId
    if (!Types.ObjectId.isValid(id)) {
      throw new BadRequestException('Invalid request ID format');
    }
    
    return this.vehicleRequestService.sendBackForCorrection(id, req.user._id.toString(), correctionDto);
  }

  @Put(':id/cancel')
  @UseGuards(RolesGuard)
  @Roles(UserRole.STAFF)
  async cancel(
    @Param('id') id: string,
    @Body() cancelDto: CancelRequestDto,
    @Request() req,
  ) {
    // Prevent route conflicts
    if (id === 'vehicle' || id === 'ict' || id === 'store' || id === 'history') {
      throw new NotFoundException(`Route /requests/${id} is handled by a different controller`);
    }
    
    // Validate that id is a valid ObjectId
    if (!Types.ObjectId.isValid(id)) {
      throw new BadRequestException('Invalid request ID format');
    }
    
    return this.vehicleRequestService.cancel(id, req.user._id.toString(), cancelDto.cancellationReason);
  }
}

