import { Injectable } from '@nestjs/common';
import { IssueStatus, LedgerEntryType, MovementType, Prisma } from '@prisma/client';
import { PrismaService } from '../../config/prisma.service';
import { DomainError, DomainErrorCode } from '../../common/errors/domain-error';
import { IdempotencyService } from '../../common/idempotency/idempotency.service';
import { AuditService } from '../audit/audit.service';
import { InventoryService } from '../inventory/inventory.service';
import { LedgerService } from '../ledger/ledger.service';
import { NumberingService } from '../numbering/numbering.service';
import { CreateReturnDto } from './dto/create-return.dto';

@Injectable()
export class ReturnService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly numbering: NumberingService,
    private readonly inventory: InventoryService,
    private readonly ledger: LedgerService,
    private readonly audit: AuditService,
    private readonly idempotency: IdempotencyService,
  ) {}

  /**
   * Evening operation. Validates each returned quantity against
   * (issued − already returned), increments stock back, and records the
   * return. Supports multiple partial returns per issue. Idempotent.
   */
  async create(dto: CreateReturnDto, staffId: string, idempotencyKey?: string) {
    this.assertNoDuplicateItems(dto.items.map((i) => i.itemId));

    return this.idempotency.execute(idempotencyKey, 'RETURN', async () => {
      const returnId = await this.prisma.$transaction(async (tx) => {
        const issue = await tx.issueTransaction.findUnique({
          where: { id: dto.issueTransactionId },
          include: { items: true, returns: { include: { items: true } } },
        });
        if (!issue) throw DomainError.notFound('IssueTransaction', dto.issueTransactionId);
        if (issue.status === IssueStatus.SETTLED || issue.status === IssueStatus.CANCELLED) {
          throw new DomainError(
            DomainErrorCode.INVALID_STATE,
            `Cannot return against a ${issue.status.toLowerCase()} issue`,
          );
        }

        // Returned-so-far per item across all prior returns.
        const returnedSoFar = new Map<string, number>();
        for (const ret of issue.returns) {
          for (const ri of ret.items) {
            returnedSoFar.set(ri.itemId, (returnedSoFar.get(ri.itemId) ?? 0) + ri.quantityReturned);
          }
        }

        // Validate every line before mutating anything.
        for (const line of dto.items) {
          const issued = issue.items.find((ii) => ii.itemId === line.itemId);
          if (!issued) {
            throw new DomainError(
              DomainErrorCode.INVALID_RETURN_QUANTITY,
              `Item ${line.itemId} was not issued in this transaction`,
            );
          }
          const remaining = issued.quantityIssued - (returnedSoFar.get(line.itemId) ?? 0);
          if (line.quantity > remaining) {
            throw new DomainError(
              DomainErrorCode.INVALID_RETURN_QUANTITY,
              `Return exceeds outstanding quantity for item ${line.itemId}: remaining ${remaining}, got ${line.quantity}`,
              { itemId: line.itemId, remaining, requested: line.quantity },
            );
          }
        }

        const returnNumber = await this.numbering.next(tx, 'RET', { scope: 'daily' });
        const returnTxn = await tx.returnTransaction.create({
          data: {
            returnNumber,
            issueTransactionId: issue.id,
            vendorId: issue.vendorId,
            staffId,
            notes: dto.notes,
            items: {
              create: dto.items.map((l) => ({ itemId: l.itemId, quantityReturned: l.quantity })),
            },
          },
        });

        for (const line of dto.items) {
          await this.inventory.applyMovement(tx, {
            itemId: line.itemId,
            type: MovementType.RETURN,
            quantityDelta: line.quantity,
            referenceType: 'RETURN_TXN',
            referenceId: returnTxn.id,
            performedById: staffId,
          });
        }

        await tx.issueTransaction.update({
          where: { id: issue.id },
          data: { status: IssueStatus.PARTIALLY_RETURNED },
        });

        await this.ledger.append(tx, {
          vendorId: issue.vendorId,
          type: LedgerEntryType.INVENTORY_RETURNED,
          referenceType: 'RETURN_TXN',
          referenceId: returnTxn.id,
          referenceNumber: returnNumber,
          createdById: staffId,
          notes: `Returned ${dto.items.length} item(s)`,
        });

        await this.audit.record(
          {
            userId: staffId,
            action: 'RETURN',
            module: 'RETURN',
            entityType: 'ReturnTransaction',
            entityId: returnTxn.id,
            metadata: { returnNumber, issueId: issue.id, lineCount: dto.items.length },
          },
          tx,
        );

        return returnTxn.id;
      });

      return this.findOne(returnId);
    });
  }

  async findOne(id: string) {
    const ret = await this.prisma.returnTransaction.findUnique({
      where: { id },
      include: {
        items: { include: { item: { select: { id: true, sku: true, name: true } } } },
        vendor: { select: { id: true, vendorCode: true, name: true } },
      },
    });
    if (!ret) throw DomainError.notFound('ReturnTransaction', id);
    return ret;
  }

  private assertNoDuplicateItems(itemIds: string[]) {
    if (new Set(itemIds).size !== itemIds.length) {
      throw new DomainError(DomainErrorCode.VALIDATION, 'Duplicate items in return payload');
    }
  }
}
