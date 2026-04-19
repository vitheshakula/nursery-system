import { IsNotEmpty, IsString } from 'class-validator';

export class UpdateVendorDto {
  @IsString()
  @IsNotEmpty()
  name!: string;

  @IsString()
  @IsNotEmpty()
  phone!: string;
}
