import { IsNotEmpty, IsString } from 'class-validator';

export class StartSessionDto {
  @IsString()
  @IsNotEmpty()
  vendorId!: string;
}
