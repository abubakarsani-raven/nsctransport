import { IsString, IsOptional, IsNumber, Min, IsIn } from 'class-validator';

export class UpdateIctRequestDto {
  @IsOptional()
  @IsString()
  equipmentType?: string;

  @IsOptional()
  @IsString()
  specifications?: string;

  @IsOptional()
  @IsString()
  purpose?: string;

  @IsOptional()
  @IsString()
  @IsIn(['low', 'normal', 'high', 'urgent'])
  urgency?: string;

  @IsOptional()
  @IsNumber()
  @Min(1)
  quantity?: number;

  @IsOptional()
  @IsNumber()
  @Min(0)
  estimatedCost?: number;

  @IsOptional()
  @IsString()
  justification?: string;
}

