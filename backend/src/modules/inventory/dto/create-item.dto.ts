import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsInt, IsNumber, IsOptional, IsString, Min, MinLength } from 'class-validator';

export class CreateItemDto {
  @ApiProperty()
  @IsString()
  @MinLength(2)
  name: string;

  @ApiProperty({ format: 'uuid' })
  @IsString()
  categoryId: string;

  @ApiPropertyOptional({ default: 'unit', example: 'piece | bag | kg' })
  @IsOptional()
  @IsString()
  unit?: string;

  @ApiProperty({ example: 40 })
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0)
  costPrice: number;

  @ApiProperty({ example: 60 })
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0)
  sellingPrice: number;

  @ApiPropertyOptional({ default: 0 })
  @IsOptional()
  @IsInt()
  @Min(0)
  reorderLevel?: number;

  @ApiPropertyOptional({ default: 0, description: 'Opening stock quantity on hand.' })
  @IsOptional()
  @IsInt()
  @Min(0)
  openingStock?: number;
}
