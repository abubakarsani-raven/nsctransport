import { Controller, Get, Post, Put, Body, Param, UseGuards, Request } from '@nestjs/common';
import { IctRequestService } from './ict-request.service';
import { CreateIctRequestDto } from './dto/create-ict-request.dto';
import { UpdateIctRequestDto } from './dto/update-ict-request.dto';
import { ApproveRequestDto } from './dto/approve-request.dto';
import { RejectRequestDto } from './dto/reject-request.dto';
import { SendBackForCorrectionDto } from './dto/send-back-for-correction.dto';
import { CancelRequestDto } from './dto/cancel-request.dto';
import { JwtAuthGuard } from '../../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../../auth/guards/roles.guard';
import { Roles } from '../../auth/decorators/roles.decorator';
import { UserRole } from '../../users/schemas/user.schema';

@Controller('requests/ict')
@UseGuards(JwtAuthGuard)
export class IctRequestController {
  constructor(private ictRequestService: IctRequestService) {}

  @Post()
  @UseGuards(RolesGuard)
  @Roles(UserRole.STAFF)
  async create(@Body() createDto: CreateIctRequestDto, @Request() req) {
    return this.ictRequestService.create(createDto, req.user._id.toString());
  }

  @Get()
  async findAll(@Request() req) {
    return this.ictRequestService.findAll(req.user);
  }

  @Get('history')
  async history(@Request() req) {
    return this.ictRequestService.findHistoryForUser(req.user._id.toString());
  }

  @Get(':id')
  async findOne(@Param('id') id: string) {
    return this.ictRequestService.findById(id);
  }

  @Put(':id/approve')
  async approve(@Param('id') id: string, @Body() approveDto: ApproveRequestDto, @Request() req) {
    return this.ictRequestService.approve(id, req.user._id.toString(), approveDto);
  }

  @Put(':id/reject')
  async reject(@Param('id') id: string, @Body() rejectDto: RejectRequestDto, @Request() req) {
    return this.ictRequestService.reject(id, req.user._id.toString(), rejectDto);
  }

  @Put(':id/resubmit')
  @UseGuards(RolesGuard)
  @Roles(UserRole.STAFF)
  async resubmit(@Param('id') id: string, @Request() req) {
    return this.ictRequestService.resubmit(id, req.user._id.toString());
  }

  @Put(':id/send-back-for-correction')
  async sendBackForCorrection(
    @Param('id') id: string,
    @Body() correctionDto: SendBackForCorrectionDto,
    @Request() req,
  ) {
    return this.ictRequestService.sendBackForCorrection(id, req.user._id.toString(), correctionDto);
  }

  @Put(':id/cancel')
  @UseGuards(RolesGuard)
  @Roles(UserRole.STAFF)
  async cancel(
    @Param('id') id: string,
    @Body() cancelDto: CancelRequestDto,
    @Request() req,
  ) {
    return this.ictRequestService.cancel(id, req.user._id.toString(), cancelDto.cancellationReason);
  }
}

