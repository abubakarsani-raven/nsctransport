import { IsString, IsNotEmpty, IsOptional, IsNumber, Min, IsIn } from 'class-validator';

export class CreateStoreRequestDto {
  @IsString()
  @IsNotEmpty()
  itemName: string;

  @IsString()
  @IsNotEmpty()
  category: string;

  @IsNumber()
  @Min(1)
  @IsNotEmpty()
  quantity: number;

  @IsString()
  @IsNotEmpty()
  unit: string;

  @IsString()
  @IsOptional()
  specifications?: string;

  @IsString()
  @IsNotEmpty()
  purpose: string;

  @IsString()
  @IsIn(['low', 'normal', 'high', 'urgent'])
  @IsOptional()
  urgency?: string;

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

