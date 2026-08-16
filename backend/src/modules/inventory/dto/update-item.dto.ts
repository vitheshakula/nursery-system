import { OmitType, PartialType } from '@nestjs/swagger';
import { CreateItemDto } from './create-item.dto';

/** Stock is never changed here — use the stock-adjustment endpoint (audited). */
export class UpdateItemDto extends PartialType(OmitType(CreateItemDto, ['openingStock'] as const)) {}
