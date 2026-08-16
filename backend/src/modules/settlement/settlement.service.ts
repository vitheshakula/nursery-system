import { Injectable } from '@nestjs/common';
import { IssueStatus, LedgerEntryType, Prisma, SettlementStatus } from '@prisma/client';
import { PrismaService } from '../../config/prisma.service';
import { Paginated, paginate } from '../../common/dto/paginated';
import { PaginationQueryDto } from '../../common/dto/pagination-query.dto';
import { DomainError, DomainErrorCode } from '../../common/errors/domain-error';
import { IdempotencyService } from '../../common/idempotency/idempotency.service';
import { AuditService } from '../audit/audit.service';
import { LedgerService } from '../ledger/ledger.service';
import { NumberingService } from '../numbering/numbering.service';
import { GenerateSettlementDto } from './dto/generate-settlement.dto';

const SETTLEMENT_INCLUDE = {
  vendor: { select: { id: true, vendorCode: true, name: true } },
  items: { include: { item: { select: { id: true, sku: true, name: true, unit: true } } } },
  issueTransaction: { select: { id: true, transactionNumber: true } },
} satisfies Prisma.SettlementInclude;

@Injectable()
export class SettlementService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly numbering: NumberingService,
    private readonly ledger: LedgerService,
    private readonly audit: AuditService,
    private readonly idempotency: IdempotencyService,
  ) {}

  /**
   * Generates a DRAFT settlement for an issue cycle.
   *   sold = issued − Σ returned     (per item)
   *   lineTotal = sold × sellingPriceSnapshot
   * No ledger/balance impact yet — that happens on finalize. The unique
   * constraint on Settlement.issueTransactionId prevents a second settlement
   * for the same issue (double-settlement guard).
   */
  async generate(dto: GenerateSettlementDto, staffId: string) {
    const settlementId = await this.prisma.$transaction(async (tx) => {
      const issue = await tx.issueTransaction.findUnique({
        where: { id: dto.issueTransactionId },
        include: { items: true, returns: { include: { items: true } } },
      });
      if (!issue) throw DomainError.notFound('IssueTransaction', dto.issueTransactionId);
      if (issue.status === IssueStatus.CANCELLED) {
        throw new DomainError(DomainErrorCode.INVALID_STATE, 'Issue is cancelled');
      }

      const existing = await tx.settlement.findUnique({
        where: { issueTransactionId: issue.id },
        select: { id: true },
      });
      if (existing) {
        throw new DomainError(
          DomainErrorCode.ALREADY_SETTLED,
          'A settlement already exists for this issue',
          { settlementId: existing.id },
        );
      }

      const returnedByItem = new Map<string, number>();
      for (const ret of issue.returns) {
        for (const ri of ret.items) {
          returnedByItem.set(ri.itemId, (returnedByItem.get(ri.itemId) ?? 0) + ri.quantityReturned);
        }
      }

      let totalAmount = new Prisma.Decimal(0);
      let totalSoldItems = 0;
      const lines = issue.items.map((ii) => {
        const returned = returnedByItem.get(ii.itemId) ?? 0;
        const sold = ii.quantityIssued - returned;
        const lineTotal = new Prisma.Decimal(ii.sellingPriceSnapshot).mul(sold);
        totalAmount = totalAmount.plus(lineTotal);
        totalSoldItems += sold;
        return {
          itemId: ii.itemId,
          quantityIssued: ii.quantityIssued,
          quantityReturned: returned,
          quantitySold: sold,
          sellingPrice: ii.sellingPriceSnapshot,
          lineTotal,
        };
      });

      const settlementNumber = await this.numbering.next(tx, 'STL', { scope: 'daily' });
      const settlement = await tx.settlement.create({
        data: {
          settlementNumber,
          issueTransactionId: issue.id,
          vendorId: issue.vendorId,
          staffId,
          status: SettlementStatus.DRAFT,
          totalAmount,
          totalSoldItems,
          items: { create: lines },
        },
      });

      await this.audit.record(
        {
          userId: staffId,
          action: 'SETTLE_GENERATE',
          module: 'SETTLEMENT',
          entityType: 'Settlement',
          entityId: settlement.id,
          metadata: { settlementNumber, totalAmount: totalAmount.toString(), totalSoldItems },
        },
        tx,
      );

      return settlement.id;
    });

    return this.findOne(settlementId);
  }

  /**
   * Finalizes a DRAFT settlement: posts the SETTLEMENT debit to the vendor
   * ledger (balance increases), marks the issue SETTLED, and freezes the
   * settlement immutable. Idempotent and guarded against re-finalization.
   */
  async finalize(id: string, staffId: string, idempotencyKey?: string) {
    return this.idempotency.execute(idempotencyKey, 'SETTLEMENT', async () => {
      await this.prisma.$transaction(async (tx) => {
        const settlement = await tx.settlement.findUnique({ where: { id } });
        if (!settlement) throw DomainError.notFound('Settlement', id);
        if (settlement.status === SettlementStatus.FINALIZED) {
          throw new DomainError(
            DomainErrorCode.SETTLEMENT_FINALIZED,
            'Settlement is already finalized and immutable',
          );
        }

        await tx.settlement.update({
          where: { id },
          data: { status: SettlementStatus.FINALIZED, finalizedAt: new Date() },
        });

        await this.ledger.append(tx, {
          vendorId: settlement.vendorId,
          type: LedgerEntryType.SETTLEMENT,
          debit: settlement.totalAmount, // vendor now owes the sold value
          referenceType: 'SETTLEMENT',
          referenceId: settlement.id,
          referenceNumber: settlement.settlementNumber,
          createdById: staffId,
          notes: `Settlement of ${settlement.totalSoldItems} sold item(s)`,
        });

        await tx.issueTransaction.update({
          where: { id: settlement.issueTransactionId },
          data: { status: IssueStatus.SETTLED },
        });

        await this.audit.record(
          {
            userId: staffId,
            action: 'SETTLE_FINALIZE',
            module: 'SETTLEMENT',
            entityType: 'Settlement',
            entityId: settlement.id,
            metadata: {
              settlementNumber: settlement.settlementNumber,
              totalAmount: settlement.totalAmount.toString(),
            },
          },
          tx,
        );
      });

      return this.findOne(id);
    });
  }

  async findAll(query: PaginationQueryDto & { vendorId?: string; status?: SettlementStatus }) {
    const where: Prisma.SettlementWhereInput = {
      ...(query.vendorId ? { vendorId: query.vendorId } : {}),
      ...(query.status ? { status: query.status } : {}),
      ...(query.search ? { settlementNumber: { contains: query.search, mode: 'insensitive' } } : {}),
    };
    const [items, total] = await this.prisma.$transaction([
      this.prisma.settlement.findMany({
        where,
        include: SETTLEMENT_INCLUDE,
        orderBy: { createdAt: 'desc' },
        skip: query.skip,
        take: query.limit,
      }),
      this.prisma.settlement.count({ where }),
    ]);
    return paginate(items, total, query.page, query.limit) as Paginated<unknown>;
  }

  async findOne(id: string) {
    const settlement = await this.prisma.settlement.findUnique({
      where: { id },
      include: SETTLEMENT_INCLUDE,
    });
    if (!settlement) throw DomainError.notFound('Settlement', id);
    return settlement;
  }
}
