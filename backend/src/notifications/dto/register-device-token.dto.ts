import { IsString, IsNotEmpty, IsEnum, IsOptional } from 'class-validator';

export enum Platform {
  ANDROID = 'android',
  IOS = 'ios',
  WEB = 'web',
}

export class RegisterDeviceTokenDto {
  @IsString()
  @IsNotEmpty()
  token: string;

  @IsEnum(Platform)
  @IsNotEmpty()
  platform: Platform;

  @IsString()
  @IsOptional()
  deviceName?: string;
}

