import { ApiProperty } from '@nestjs/swagger';
import { IsUUID } from 'class-validator';

export class GenerateSettlementDto {
  @ApiProperty({ format: 'uuid', description: 'The issue cycle to settle.' })
  @IsUUID()
  issueTransactionId: string;
}
