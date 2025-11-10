import { Controller, Get, Post, Put, Body, Param, UseGuards, Request } from '@nestjs/common';
import { StoreRequestService } from './store-request.service';
import { CreateStoreRequestDto } from './dto/create-store-request.dto';
import { UpdateStoreRequestDto } from './dto/update-store-request.dto';
import { ApproveRequestDto } from './dto/approve-request.dto';
import { RejectRequestDto } from './dto/reject-request.dto';
import { SendBackForCorrectionDto } from './dto/send-back-for-correction.dto';
import { CancelRequestDto } from './dto/cancel-request.dto';
import { JwtAuthGuard } from '../../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../../auth/guards/roles.guard';
import { Roles } from '../../auth/decorators/roles.decorator';
import { UserRole } from '../../users/schemas/user.schema';

@Controller('requests/store')
@UseGuards(JwtAuthGuard)
export class StoreRequestController {
  constructor(private storeRequestService: StoreRequestService) {}

  @Post()
  @UseGuards(RolesGuard)
  @Roles(UserRole.STAFF)
  async create(@Body() createDto: CreateStoreRequestDto, @Request() req) {
    return this.storeRequestService.create(createDto, req.user._id.toString());
  }

  @Get()
  async findAll(@Request() req) {
    return this.storeRequestService.findAll(req.user);
  }

  @Get('history')
  async history(@Request() req) {
    return this.storeRequestService.findHistoryForUser(req.user._id.toString());
  }

  @Get(':id')
  async findOne(@Param('id') id: string) {
    return this.storeRequestService.findById(id);
  }

  @Put(':id/approve')
  async approve(@Param('id') id: string, @Body() approveDto: ApproveRequestDto, @Request() req) {
    return this.storeRequestService.approve(id, req.user._id.toString(), approveDto);
  }

  @Put(':id/reject')
  async reject(@Param('id') id: string, @Body() rejectDto: RejectRequestDto, @Request() req) {
    return this.storeRequestService.reject(id, req.user._id.toString(), rejectDto);
  }

  @Put(':id/resubmit')
  @UseGuards(RolesGuard)
  @Roles(UserRole.STAFF)
  async resubmit(@Param('id') id: string, @Request() req) {
    return this.storeRequestService.resubmit(id, req.user._id.toString());
  }

  @Put(':id/send-back-for-correction')
  async sendBackForCorrection(
    @Param('id') id: string,
    @Body() correctionDto: SendBackForCorrectionDto,
    @Request() req,
  ) {
    return this.storeRequestService.sendBackForCorrection(id, req.user._id.toString(), correctionDto);
  }

  @Put(':id/cancel')
  @UseGuards(RolesGuard)
  @Roles(UserRole.STAFF)
  async cancel(
    @Param('id') id: string,
    @Body() cancelDto: CancelRequestDto,
    @Request() req,
  ) {
    return this.storeRequestService.cancel(id, req.user._id.toString(), cancelDto.cancellationReason);
  }
}

