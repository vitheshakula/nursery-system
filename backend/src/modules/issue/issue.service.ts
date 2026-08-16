import { Injectable } from '@nestjs/common';
import { IssueStatus, LedgerEntryType, MovementType, Prisma } from '@prisma/client';
import { PrismaService } from '../../config/prisma.service';
import { Paginated, paginate } from '../../common/dto/paginated';
import { PaginationQueryDto } from '../../common/dto/pagination-query.dto';
import { DomainError, DomainErrorCode } from '../../common/errors/domain-error';
import { IdempotencyService } from '../../common/idempotency/idempotency.service';
import { AuditService } from '../audit/audit.service';
import { InventoryService } from '../inventory/inventory.service';
import { LedgerService } from '../ledger/ledger.service';
import { NumberingService } from '../numbering/numbering.service';
import { CreateIssueDto } from './dto/create-issue.dto';

const ISSUE_INCLUDE = {
  vendor: { select: { id: true, vendorCode: true, name: true } },
  staff: { select: { id: true, name: true } },
  items: { include: { item: { select: { id: true, sku: true, name: true, unit: true } } } },
} satisfies Prisma.IssueTransactionInclude;

@Injectable()
export class IssueService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly numbering: NumberingService,
    private readonly inventory: InventoryService,
    private readonly ledger: LedgerService,
    private readonly audit: AuditService,
    private readonly idempotency: IdempotencyService,
  ) {}

  /**
   * Morning operation. Atomically: validates the vendor & items, decrements
   * stock (with movement records), snapshots the selling price per line,
   * and writes an INVENTORY_ISSUED ledger activity entry. Idempotent.
   */
  async create(dto: CreateIssueDto, staffId: string, idempotencyKey?: string) {
    this.assertNoDuplicateItems(dto.items.map((i) => i.itemId));

    return this.idempotency.execute(idempotencyKey, 'ISSUE', async () => {
      const issueId = await this.prisma.$transaction(async (tx) => {
        const vendor = await tx.vendor.findUnique({ where: { id: dto.vendorId } });
        if (!vendor) throw DomainError.notFound('Vendor', dto.vendorId);
        if (!vendor.active) {
          throw new DomainError(DomainErrorCode.INACTIVE_ENTITY, 'Vendor is inactive');
        }

        const transactionNumber = await this.numbering.next(tx, 'ISS', { scope: 'daily' });
        const issue = await tx.issueTransaction.create({
          data: {
            transactionNumber,
            vendorId: dto.vendorId,
            staffId,
            notes: dto.notes,
            status: IssueStatus.OPEN,
          },
        });

        for (const line of dto.items) {
          const item = await tx.inventoryItem.findUnique({ where: { id: line.itemId } });
          if (!item) throw DomainError.notFound('InventoryItem', line.itemId);
          if (!item.active) {
            throw new DomainError(DomainErrorCode.INACTIVE_ENTITY, `Item ${item.sku} is inactive`);
          }

          await this.inventory.applyMovement(tx, {
            itemId: line.itemId,
            type: MovementType.ISSUE,
            quantityDelta: -line.quantity,
            referenceType: 'ISSUE_TXN',
            referenceId: issue.id,
            performedById: staffId,
          });

          await tx.issueItem.create({
            data: {
              issueTransactionId: issue.id,
              itemId: line.itemId,
              quantityIssued: line.quantity,
              sellingPriceSnapshot: item.sellingPrice,
            },
          });
        }

        // Activity-only ledger entry — financial impact occurs at settlement.
        await this.ledger.append(tx, {
          vendorId: dto.vendorId,
          type: LedgerEntryType.INVENTORY_ISSUED,
          referenceType: 'ISSUE_TXN',
          referenceId: issue.id,
          referenceNumber: transactionNumber,
          createdById: staffId,
          notes: `Issued ${dto.items.length} item(s)`,
        });

        await this.audit.record(
          {
            userId: staffId,
            action: 'ISSUE',
            module: 'ISSUE',
            entityType: 'IssueTransaction',
            entityId: issue.id,
            metadata: { transactionNumber, lineCount: dto.items.length },
          },
          tx,
        );

        return issue.id;
      });

      return this.findOne(issueId);
    });
  }

  async findAll(query: PaginationQueryDto & { vendorId?: string; status?: IssueStatus }) {
    const where: Prisma.IssueTransactionWhereInput = {
      ...(query.vendorId ? { vendorId: query.vendorId } : {}),
      ...(query.status ? { status: query.status } : {}),
      ...(query.search ? { transactionNumber: { contains: query.search, mode: 'insensitive' } } : {}),
    };
    const [items, total] = await this.prisma.$transaction([
      this.prisma.issueTransaction.findMany({
        where,
        include: ISSUE_INCLUDE,
        orderBy: { issuedAt: 'desc' },
        skip: query.skip,
        take: query.limit,
      }),
      this.prisma.issueTransaction.count({ where }),
    ]);
    return paginate(items, total, query.page, query.limit) as Paginated<unknown>;
  }

  async findOne(id: string) {
    const issue = await this.prisma.issueTransaction.findUnique({
      where: { id },
      include: { ...ISSUE_INCLUDE, returns: { include: { items: true } }, settlement: true },
    });
    if (!issue) throw DomainError.notFound('IssueTransaction', id);
    return issue;
  }

  private assertNoDuplicateItems(itemIds: string[]) {
    if (new Set(itemIds).size !== itemIds.length) {
      throw new DomainError(DomainErrorCode.VALIDATION, 'Duplicate items in issue payload');
    }
  }
}
