import { Injectable } from '@nestjs/common';
import { LedgerEntryType, Prisma, VendorLedger } from '@prisma/client';
import { PrismaService } from '../../config/prisma.service';
import { Paginated, paginate } from '../../common/dto/paginated';
import { PaginationQueryDto } from '../../common/dto/pagination-query.dto';
import { DomainError } from '../../common/errors/domain-error';
import { AuditService } from '../audit/audit.service';
import { AdjustLedgerDto } from './dto/adjust-ledger.dto';

export interface LedgerAppendInput {
  vendorId: string;
  type: LedgerEntryType;
  debit?: Prisma.Decimal | number; // increases what the vendor owes
  credit?: Prisma.Decimal | number; // decreases what the vendor owes
  referenceType?: string;
  referenceId?: string;
  referenceNumber?: string;
  notes?: string;
  createdById?: string;
}

/**
 * The financial source of truth. The ledger is APPEND-ONLY: entries are never
 * updated or deleted. Each append also refreshes the denormalized
 * `Vendor.currentBalance` cache — these two writes happen inside the caller's
 * transaction so the cache can never drift from the ledger.
 *
 * Sign convention: positive balance = vendor owes the nursery.
 *   debit  -> balance increases (e.g. settlement)
 *   credit -> balance decreases (e.g. payment)
 */
@Injectable()
export class LedgerService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: AuditService,
  ) {}

  /**
   * Low-level append primitive. MUST be called with the surrounding
   * transaction client. The vendor row is locked (FOR UPDATE) so concurrent
   * appends serialize and balances stay exact.
   */
  async append(tx: Prisma.TransactionClient, input: LedgerAppendInput): Promise<VendorLedger> {
    await tx.$queryRaw`SELECT id FROM "Vendor" WHERE id = ${input.vendorId} FOR UPDATE`;

    const vendor = await tx.vendor.findUniqueOrThrow({
      where: { id: input.vendorId },
      select: { currentBalance: true },
    });

    const debit = new Prisma.Decimal(input.debit ?? 0);
    const credit = new Prisma.Decimal(input.credit ?? 0);
    const balanceAfter = new Prisma.Decimal(vendor.currentBalance).plus(debit).minus(credit);

    const entry = await tx.vendorLedger.create({
      data: {
        vendorId: input.vendorId,
        type: input.type,
        debit,
        credit,
        balanceAfter,
        referenceType: input.referenceType,
        referenceId: input.referenceId,
        referenceNumber: input.referenceNumber,
        notes: input.notes,
        createdById: input.createdById,
      },
    });

    await tx.vendor.update({
      where: { id: input.vendorId },
      data: { currentBalance: balanceAfter },
    });

    return entry;
  }

  /** Vendor "bank statement" — paginated ledger entries, newest first. */
  async getStatement(vendorId: string, query: PaginationQueryDto): Promise<Paginated<VendorLedger>> {
    const exists = await this.prisma.vendor.count({ where: { id: vendorId } });
    if (!exists) throw DomainError.notFound('Vendor', vendorId);

    const [items, total] = await this.prisma.$transaction([
      this.prisma.vendorLedger.findMany({
        where: { vendorId },
        orderBy: { createdAt: 'desc' },
        skip: query.skip,
        take: query.limit,
      }),
      this.prisma.vendorLedger.count({ where: { vendorId } }),
    ]);

    return paginate(items, total, query.page, query.limit);
  }

  /**
   * Manual balance correction — the ONLY way an operator can move a balance,
   * and it is always recorded as a ledger entry + audit log. Admin-gated at
   * the controller. A positive amount debits (vendor owes more), negative
   * credits (vendor owes less).
   */
  async adjust(dto: AdjustLedgerDto, actorId: string): Promise<VendorLedger> {
    const amount = new Prisma.Decimal(dto.amount);
    const isDebit = amount.greaterThanOrEqualTo(0);

    return this.prisma.$transaction(async (tx) => {
      const entry = await this.append(tx, {
        vendorId: dto.vendorId,
        type: LedgerEntryType.ADJUSTMENT,
        debit: isDebit ? amount.abs() : 0,
        credit: isDebit ? 0 : amount.abs(),
        referenceType: 'ADJUSTMENT',
        notes: dto.reason,
        createdById: actorId,
      });

      await this.audit.record(
        {
          userId: actorId,
          action: 'ADJUST',
          module: 'LEDGER',
          entityType: 'Vendor',
          entityId: dto.vendorId,
          metadata: { amount: dto.amount, reason: dto.reason, ledgerEntryId: entry.id },
        },
        tx,
      );

      return entry;
    });
  }
}
