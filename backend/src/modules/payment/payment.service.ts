import { Injectable } from '@nestjs/common';
import { LedgerEntryType, Prisma } from '@prisma/client';
import { PrismaService } from '../../config/prisma.service';
import { Paginated, paginate } from '../../common/dto/paginated';
import { DomainError } from '../../common/errors/domain-error';
import { IdempotencyService } from '../../common/idempotency/idempotency.service';
import { AuditService } from '../audit/audit.service';
import { LedgerService } from '../ledger/ledger.service';
import { NumberingService } from '../numbering/numbering.service';
import { CreatePaymentDto } from './dto/create-payment.dto';
import { QueryPaymentsDto } from './dto/query-payments.dto';

@Injectable()
export class PaymentService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly numbering: NumberingService,
    private readonly ledger: LedgerService,
    private readonly audit: AuditService,
    private readonly idempotency: IdempotencyService,
  ) {}

  /**
   * Records a vendor payment and posts a PAYMENT credit to the ledger
   * (balance decreases). Overpayment is allowed and simply drives the
   * balance negative (nursery owes the vendor). Idempotent.
   */
  async create(dto: CreatePaymentDto, staffId: string, idempotencyKey?: string) {
    return this.idempotency.execute(idempotencyKey, 'PAYMENT', async () => {
      const paymentId = await this.prisma.$transaction(async (tx) => {
        const vendor = await tx.vendor.findUnique({ where: { id: dto.vendorId } });
        if (!vendor) throw DomainError.notFound('Vendor', dto.vendorId);

        const paymentNumber = await this.numbering.next(tx, 'PAY', { scope: 'daily' });
        const payment = await tx.payment.create({
          data: {
            paymentNumber,
            vendorId: dto.vendorId,
            staffId,
            amount: new Prisma.Decimal(dto.amount),
            method: dto.method,
            notes: dto.notes,
          },
        });

        await this.ledger.append(tx, {
          vendorId: dto.vendorId,
          type: LedgerEntryType.PAYMENT,
          credit: payment.amount, // reduces what the vendor owes
          referenceType: 'PAYMENT',
          referenceId: payment.id,
          referenceNumber: paymentNumber,
          createdById: staffId,
          notes: `Payment via ${dto.method}`,
        });

        await this.audit.record(
          {
            userId: staffId,
            action: 'PAY',
            module: 'PAYMENT',
            entityType: 'Payment',
            entityId: payment.id,
            metadata: { paymentNumber, amount: dto.amount, method: dto.method },
          },
          tx,
        );

        return payment.id;
      });

      return this.findOne(paymentId);
    });
  }

  async findAll(query: QueryPaymentsDto): Promise<Paginated<unknown>> {
    const where: Prisma.PaymentWhereInput = {
      ...(query.vendorId ? { vendorId: query.vendorId } : {}),
      ...(query.search ? { paymentNumber: { contains: query.search, mode: 'insensitive' } } : {}),
    };
    const [items, total] = await this.prisma.$transaction([
      this.prisma.payment.findMany({
        where,
        include: { vendor: { select: { id: true, vendorCode: true, name: true } } },
        orderBy: { paidAt: 'desc' },
        skip: query.skip,
        take: query.limit,
      }),
      this.prisma.payment.count({ where }),
    ]);
    return paginate(items, total, query.page, query.limit);
  }

  async findOne(id: string) {
    const payment = await this.prisma.payment.findUnique({
      where: { id },
      include: { vendor: { select: { id: true, vendorCode: true, name: true } } },
    });
    if (!payment) throw DomainError.notFound('Payment', id);
    return payment;
  }
}
