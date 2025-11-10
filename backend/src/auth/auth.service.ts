import { Injectable, UnauthorizedException, ConflictException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import * as bcrypt from 'bcrypt';
import { UsersService } from '../users/users.service';
import { LoginDto } from './dto/login.dto';
import { RegisterDto } from './dto/register.dto';
import { UserRole } from '../users/schemas/user.schema';

@Injectable()
export class AuthService {
  constructor(
    private usersService: UsersService,
    private jwtService: JwtService,
    private configService: ConfigService,
  ) {}

  async login(loginDto: LoginDto) {
    const user = await this.usersService.findByEmail(loginDto.email);
    if (!user) {
      throw new UnauthorizedException('Invalid credentials');
    }

    const isPasswordValid = await bcrypt.compare(loginDto.password, user.password);
    if (!isPasswordValid) {
      throw new UnauthorizedException('Invalid credentials');
    }

    // Ensure roles array exists (default to STAFF if empty)
    const roles = user.roles && user.roles.length > 0 ? user.roles : [UserRole.STAFF];
    
    const payload = { email: user.email, sub: user._id, roles };
    return {
      access_token: this.jwtService.sign(payload),
      user: {
        id: user._id,
        email: user.email,
        name: user.name,
        roles,
        department: user.department,
        isSupervisor: user.isSupervisor,
      },
    };
  }

  async register(registerDto: RegisterDto) {
    const existingUser = await this.usersService.findByEmail(registerDto.email);
    if (existingUser) {
      console.log('Registration conflict: User already exists', { email: registerDto.email, userId: existingUser._id });
      throw new ConflictException('User with this email already exists');
    }

    const hashedPassword = await bcrypt.hash(registerDto.password, 10);
    
    // Handle roles: use roles array if provided, otherwise use role (for backward compatibility)
    const roles = registerDto.roles && registerDto.roles.length > 0 
      ? registerDto.roles 
      : (registerDto.role ? [registerDto.role] : [UserRole.STAFF]);
    
    console.log('Creating user with roles:', { email: registerDto.email, roles });
    
    const user = await this.usersService.create({
      ...registerDto,
      password: hashedPassword,
      roles,
    });

    const payload = { email: user.email, sub: user._id, roles };
    return {
      access_token: this.jwtService.sign(payload),
      user: {
        id: user._id,
        email: user.email,
        name: user.name,
        roles,
        department: user.department,
        isSupervisor: user.isSupervisor,
      },
    };
  }

  async validateUser(userId: string) {
    return this.usersService.findById(userId);
  }
}

