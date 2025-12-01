import { Controller, Get, Post, Put, Body, Param, UseGuards, Request, Patch } from '@nestjs/common';
import { VehicleRequestService } from './vehicle-request.service';
import { CreateRequestDto } from './dto/create-request.dto';
import { UpdateRequestDto } from './dto/update-request.dto';
import { ApproveRequestDto } from './dto/approve-request.dto';
import { RejectRequestDto } from './dto/reject-request.dto';
import { SendBackForCorrectionDto } from './dto/send-back-for-correction.dto';
import { CancelRequestDto } from './dto/cancel-request.dto';
import { JwtAuthGuard } from '../../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../../auth/guards/roles.guard';
import { Roles } from '../../auth/decorators/roles.decorator';
import { UserRole } from '../../users/schemas/user.schema';

@Controller('requests/vehicle')
@UseGuards(JwtAuthGuard)
export class VehicleRequestController {
  constructor(private vehicleRequestService: VehicleRequestService) {}

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
    return this.vehicleRequestService.findHistoryForUser(req.user._id.toString());
  }

  @Get(':id')
  async findOne(@Param('id') id: string) {
    return this.vehicleRequestService.findById(id);
  }

  @Put(':id')
  @UseGuards(RolesGuard)
  @Roles(UserRole.STAFF)
  async update(@Param('id') id: string, @Body() updateDto: UpdateRequestDto, @Request() req) {
    return this.vehicleRequestService.update(id, req.user._id.toString(), updateDto);
  }

  @Put(':id/approve')
  async approve(@Param('id') id: string, @Body() approveDto: ApproveRequestDto, @Request() req) {
    return this.vehicleRequestService.approve(id, req.user._id.toString(), approveDto);
  }

  @Put(':id/reject')
  async reject(@Param('id') id: string, @Body() rejectDto: RejectRequestDto, @Request() req) {
    return this.vehicleRequestService.reject(id, req.user._id.toString(), rejectDto);
  }

  @Put(':id/resubmit')
  @UseGuards(RolesGuard)
  @Roles(UserRole.STAFF)
  async resubmit(@Param('id') id: string, @Request() req) {
    return this.vehicleRequestService.resubmit(id, req.user._id.toString());
  }

  @Put(':id/send-back-for-correction')
  async sendBackForCorrection(
    @Param('id') id: string,
    @Body() correctionDto: SendBackForCorrectionDto,
    @Request() req,
  ) {
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
    return this.vehicleRequestService.cancel(id, req.user._id.toString(), cancelDto.cancellationReason);
  }

  /**
   * TEMPORARY ENDPOINT: Add coordinates to an existing vehicle request
   * This endpoint is for migrating existing requests to include coordinates
   * TODO: Remove this endpoint after migration is complete
   */
  @Patch('add-coordinates')
  @UseGuards(RolesGuard)
  @Roles(UserRole.ADMIN, UserRole.TRANSPORT_OFFICER)
  async addCoordinates(
    @Body() body: { requestId: string; coordinates: { lat: number; lng: number } },
    @Request() req,
  ) {
    return this.vehicleRequestService.addCoordinates(body.requestId, body.coordinates);
  }

  /**
   * TEMPORARY ENDPOINT: Batch add coordinates to multiple vehicle requests
   * This endpoint is for migrating existing requests to include coordinates
   * TODO: Remove this endpoint after migration is complete
   */
  @Patch('batch-add-coordinates')
  @UseGuards(RolesGuard)
  @Roles(UserRole.ADMIN, UserRole.TRANSPORT_OFFICER)
  async batchAddCoordinates(
    @Body() body: { requests: Array<{ requestId: string; coordinates: { lat: number; lng: number } }> },
    @Request() req,
  ) {
    return this.vehicleRequestService.batchAddCoordinates(body.requests);
  }
}

