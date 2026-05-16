import {
  Injectable,
  Logger,
  NotFoundException,
} from "@nestjs/common";
import { IdempotentOperationType, LedgerEntryType } from "@prisma/client";
import { PrismaService } from "../../config/prisma.service";
import {
  DomainError,
  DomainErrorCode,
} from "../../common/errors/domain-error";
import { runIdempotent } from "../../common/idempotency/idempotency.util";
import { CreatePaymentDto } from "./dto/create-payment.dto";

@Injectable()
export class PaymentsService {
  private readonly logger = new Logger(PaymentsService.name);

  constructor(private readonly prisma: PrismaService) {}

  async create(createPaymentDto: CreatePaymentDto) {
    const result = await this.prisma.$transaction(async (tx) =>
      runIdempotent(
        tx,
        IdempotentOperationType.PAYMENT_CREATE,
        createPaymentDto.requestId,
        async () => {
      const vendor = await tx.vendor.findUnique({
        where: { id: createPaymentDto.vendorId },
        select: { id: true },
      });

      if (!vendor) {
        throw new NotFoundException("Vendor not found");
      }

      const updateResult = await tx.vendor.updateMany({
        where: {
          id: createPaymentDto.vendorId,
          balance: {
            gte: createPaymentDto.amount,
          },
        },
        data: {
          balance: {
            decrement: createPaymentDto.amount,
          },
        },
      });

      if (updateResult.count !== 1) {
        throw new DomainError(
          DomainErrorCode.OverpaymentNotAllowed,
          "Payment amount exceeds vendor outstanding balance",
        );
      }

      const payment = await tx.payment.create({
        data: {
          vendorId: createPaymentDto.vendorId,
          amount: createPaymentDto.amount,
          mode: createPaymentDto.mode,
        },
      });

      await tx.ledgerEntry.create({
        data: {
          vendorId: createPaymentDto.vendorId,
          type: LedgerEntryType.PAYMENT_RECEIVED,
          amount: -createPaymentDto.amount,
          notes: `Payment received via ${createPaymentDto.mode}`,
        },
      });

      const updatedVendor = await tx.vendor.findUniqueOrThrow({
        where: { id: createPaymentDto.vendorId },
      });

      return { payment, updatedVendor };
        },
      ),
    );

    this.logger.log(
      `Payment created: paymentId=${result.payment.id} vendorId=${result.payment.vendorId} amount=${result.payment.amount} mode=${result.payment.mode}`,
    );

    return {
      ...result.payment,
      vendorBalance: result.updatedVendor.balance,
    };
  }

  async findByVendor(vendorId: string) {
    const vendor = await this.prisma.vendor.findUnique({
      where: { id: vendorId },
    });

    if (!vendor) {
      throw new NotFoundException("Vendor not found");
    }

    return this.prisma.payment.findMany({
      where: { vendorId },
      orderBy: { createdAt: "desc" },
    });
  }
}
