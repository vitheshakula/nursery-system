import { Type } from "class-transformer";
import { PaymentMode } from "@prisma/client";
import {
  IsEnum,
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsPositive,
  IsString,
} from "class-validator";

export class CreatePaymentDto {
  @IsString()
  @IsNotEmpty()
  vendorId!: string;

  @Type(() => Number)
  @IsNumber()
  @IsPositive()
  amount!: number;

  @IsEnum(PaymentMode)
  mode!: PaymentMode;

  @IsOptional()
  @IsString()
  requestId?: string;
}
