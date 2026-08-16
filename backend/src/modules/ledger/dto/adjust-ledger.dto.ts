import { ApiProperty } from '@nestjs/swagger';
import { IsNotEmpty, IsNumber, IsString, IsUUID } from 'class-validator';

export class AdjustLedgerDto {
  @ApiProperty({ format: 'uuid' })
  @IsUUID()
  vendorId: string;

  @ApiProperty({
    description: 'Signed amount. Positive = vendor owes more (debit); negative = owes less (credit).',
    example: -250.5,
  })
  @IsNumber({ maxDecimalPlaces: 2 })
  amount: number;

  @ApiProperty({ description: 'Mandatory justification — recorded in the audit log.' })
  @IsString()
  @IsNotEmpty()
  reason: string;
}
