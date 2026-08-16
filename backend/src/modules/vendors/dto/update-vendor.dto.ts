import { OmitType, PartialType } from '@nestjs/swagger';
import { CreateVendorDto } from './create-vendor.dto';

/** Opening balance cannot be edited after creation — adjustments go via the ledger. */
export class UpdateVendorDto extends PartialType(OmitType(CreateVendorDto, ['openingBalance'] as const)) {}
