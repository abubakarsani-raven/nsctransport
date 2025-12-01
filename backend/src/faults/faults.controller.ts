import {
  Controller,
  Get,
  Post,
  Put,
  Delete,
  Body,
  Param,
  UseGuards,
  Request,
} from '@nestjs/common';
import { FaultsService } from './faults.service';
import { CreateFaultReportDto } from './dto/create-fault-report.dto';
import { UpdateFaultReportDto } from './dto/update-fault-report.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { UserRole } from '../users/schemas/user.schema';

@Controller('faults')
@UseGuards(JwtAuthGuard)
export class FaultsController {
  constructor(private faultsService: FaultsService) {}

  @Post()
  async create(@Body() createDto: CreateFaultReportDto, @Request() req) {
    return this.faultsService.create(createDto, req.user._id.toString());
  }

  @Get()
  @UseGuards(RolesGuard)
  @Roles(UserRole.ADMIN, UserRole.TRANSPORT_OFFICER)
  async findAll() {
    return this.faultsService.findAll();
  }

  @Get('my-reports')
  async getMyReports(@Request() req) {
    return this.faultsService.findByReporter(req.user._id.toString());
  }

  @Get('vehicle/:vehicleId')
  async getByVehicle(@Param('vehicleId') vehicleId: string) {
    return this.faultsService.findByVehicle(vehicleId);
  }

  @Get(':id')
  async findOne(@Param('id') id: string) {
    return this.faultsService.findById(id);
  }

  @Put(':id')
  @UseGuards(RolesGuard)
  @Roles(UserRole.ADMIN, UserRole.TRANSPORT_OFFICER)
  async update(
    @Param('id') id: string,
    @Body() updateDto: UpdateFaultReportDto,
    @Request() req,
  ) {
    return this.faultsService.update(id, updateDto, req.user._id.toString());
  }

  @Delete(':id')
  @UseGuards(RolesGuard)
  @Roles(UserRole.ADMIN)
  async delete(@Param('id') id: string) {
    return this.faultsService.delete(id);
  }
}

