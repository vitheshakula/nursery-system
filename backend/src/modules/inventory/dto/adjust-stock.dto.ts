import { ApiProperty } from '@nestjs/swagger';
import { IsInt, IsNotEmpty, IsString, NotEquals } from 'class-validator';

export class AdjustStockDto {
  @ApiProperty({ description: 'Signed quantity change. e.g. +50 restock, -3 wastage.', example: 50 })
  @IsInt()
  @NotEquals(0)
  quantityDelta: number;

  @ApiProperty({ description: 'Reason — recorded on the movement and audit log.' })
  @IsString()
  @IsNotEmpty()
  reason: string;
}
