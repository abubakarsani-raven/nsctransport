import { Controller, Get, Put, Param, Body, UseGuards, Delete } from '@nestjs/common';
import { UsersService } from './users.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { UserRole } from './schemas/user.schema';

@Controller('users')
@UseGuards(JwtAuthGuard)
export class UsersController {
  constructor(private usersService: UsersService) {}

  @Get('drivers')
  async getDrivers() {
    return this.usersService.findDrivers();
  }

  @Get('staff')
  async getStaff() {
    return this.usersService.findStaff();
  }

  @Get('supervisors/:department')
  async getSupervisorsByDepartment(@Param('department') department: string) {
    return this.usersService.findSupervisorsByDepartment(department);
  }

  @Get('bootstrap-admin')
  async bootstrapAdmin() {
    // Find the first user and add admin role if they don't have it
    const users = await this.usersService.findAll();
    if (users.length === 0) {
      return { message: 'No users found' };
    }
    
    const firstUser = users[0];
    const currentRoles = firstUser.roles && firstUser.roles.length > 0 ? firstUser.roles : [];
    
    if (!currentRoles.includes(UserRole.ADMIN)) {
      const updatedRoles = [...currentRoles, UserRole.ADMIN];
      const userId = (firstUser._id as any).toString();
      await this.usersService.update(userId, { roles: updatedRoles });
      return { 
        message: 'Admin role added to first user', 
        userId: firstUser._id,
        email: firstUser.email,
        roles: updatedRoles 
      };
    }
    
    return { 
      message: 'First user already has admin role',
      userId: firstUser._id,
      email: firstUser.email,
      roles: currentRoles 
    };
  }

  @Get()
  @UseGuards(RolesGuard)
  @Roles(UserRole.ADMIN)
  async getAllUsers() {
    return this.usersService.findAll();
  }

  @Put(':id/supervisor')
  @UseGuards(RolesGuard)
  @Roles(UserRole.ADMIN)
  async assignSupervisor(@Param('id') userId: string, @Body('supervisorId') supervisorId: string) {
    return this.usersService.assignSupervisor(userId, supervisorId);
  }

  @Put(':id')
  @UseGuards(RolesGuard)
  @Roles(UserRole.ADMIN)
  async updateUser(@Param('id') userId: string, @Body() updateUserDto: any) {
    return this.usersService.update(userId, updateUserDto);
  }
}

