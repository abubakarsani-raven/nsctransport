import { IsOptional, IsString } from 'class-validator';

export class ApproveRequestDto {
  @IsString()
  @IsOptional()
  comments?: string;
}

