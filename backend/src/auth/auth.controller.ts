import { Controller, Post, Body, Get, UseGuards, Request } from '@nestjs/common';
import { AuthService } from './auth.service';
import { LoginDto } from './dto/login.dto';
import { RegisterDto } from './dto/register.dto';
import { JwtAuthGuard } from './guards/jwt-auth.guard';

@Controller('auth')
export class AuthController {
  constructor(private authService: AuthService) {}

  @Post('login')
  async login(@Body() loginDto: LoginDto) {
    return this.authService.login(loginDto);
  }

  @Post('register')
  async register(@Body() registerDto: RegisterDto) {
    return this.authService.register(registerDto);
  }

  @UseGuards(JwtAuthGuard)
  @Get('me')
  async getProfile(@Request() req) {
    const user = req.user;
    const roles = user.roles && user.roles.length > 0 ? user.roles : [];
    return {
      id: user._id,
      email: user.email,
      name: user.name,
      roles,
      department: user.department,
      isSupervisor: user.isSupervisor,
      phone: user.phone,
      employeeId: user.employeeId,
    };
  }
}

