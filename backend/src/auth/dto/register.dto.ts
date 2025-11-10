import { IsEmail, IsNotEmpty, IsString, MinLength, IsOptional, IsEnum, IsArray } from 'class-validator';
import { UserRole } from '../../users/schemas/user.schema';

export class RegisterDto {
  @IsEmail()
  @IsNotEmpty()
  email: string;

  @IsString()
  @IsNotEmpty()
  @MinLength(6)
  password: string;

  @IsString()
  @IsNotEmpty()
  name: string;

  @IsString()
  @IsNotEmpty()
  phone: string;

  @IsEnum(UserRole, { each: true })
  @IsArray()
  @IsOptional()
  roles?: UserRole[];

  @IsEnum(UserRole)
  @IsOptional()
  role?: UserRole; // For backward compatibility

  @IsString()
  @IsOptional()
  department?: string;

  @IsOptional()
  isSupervisor?: boolean;

  @IsString()
  @IsOptional()
  supervisorId?: string;

  @IsString()
  @IsOptional()
  employeeId?: string;
}

