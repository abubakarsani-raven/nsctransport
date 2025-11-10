import { IsString, IsNotEmpty, IsOptional, IsNumber, Min, IsIn } from 'class-validator';

export class CreateIctRequestDto {
  @IsString()
  @IsNotEmpty()
  equipmentType: string;

  @IsString()
  @IsNotEmpty()
  specifications: string;

  @IsString()
  @IsNotEmpty()
  purpose: string;

  @IsString()
  @IsIn(['low', 'normal', 'high', 'urgent'])
  @IsOptional()
  urgency?: string;

  @IsNumber()
  @Min(1)
  @IsOptional()
  quantity?: number;

  @IsNumber()
  @Min(0)
  @IsOptional()
  estimatedCost?: number;

  @IsString()
  @IsOptional()
  justification?: string;

  @IsString()
  @IsOptional()
  supervisorId?: string;
}

