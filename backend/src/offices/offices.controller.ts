import { Controller, Get, Post, Put, Delete, Body, Param, UseGuards } from '@nestjs/common';
import { OfficesService } from './offices.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { UserRole } from '../users/schemas/user.schema';

@Controller('offices')
@UseGuards(JwtAuthGuard)
export class OfficesController {
  constructor(private officesService: OfficesService) {}

  @Get()
  async findAll() {
    return this.officesService.findAll();
  }

  @Get(':id')
  async findOne(@Param('id') id: string) {
    return this.officesService.findById(id);
  }

  @Post()
  @UseGuards(RolesGuard)
  @Roles(UserRole.ADMIN)
  async create(@Body() createOfficeDto: any) {
    return this.officesService.create(createOfficeDto);
  }

  @Put(':id')
  @UseGuards(RolesGuard)
  @Roles(UserRole.ADMIN)
  async update(@Param('id') id: string, @Body() updateOfficeDto: any) {
    return this.officesService.update(id, updateOfficeDto);
  }

  @Delete(':id')
  @UseGuards(RolesGuard)
  @Roles(UserRole.ADMIN)
  async delete(@Param('id') id: string) {
    await this.officesService.delete(id);
    return { message: 'Office deleted successfully' };
  }
}

