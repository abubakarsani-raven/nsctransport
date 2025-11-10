import { IsString, IsNotEmpty } from 'class-validator';

export class CancelRequestDto {
  @IsString()
  @IsNotEmpty()
  cancellationReason: string;
}

