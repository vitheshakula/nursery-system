import { Type } from 'class-transformer';
import { IsNotEmpty, IsNumber, IsOptional, IsString } from 'class-validator';

export class CreatePlantDto {
  @IsString()
  @IsNotEmpty()
  name!: string;

  @IsString()
  @IsNotEmpty()
  categoryId!: string;

  @Type(() => Number)
  @IsNumber()
  vendorPrice!: number;

  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  retailPrice?: number;
}
