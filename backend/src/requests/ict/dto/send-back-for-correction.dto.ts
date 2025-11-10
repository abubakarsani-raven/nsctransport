import { IsString, IsNotEmpty } from 'class-validator';

export class SendBackForCorrectionDto {
  @IsString()
  @IsNotEmpty()
  correctionNote: string;
}

