import { Injectable } from '@nestjs/common';
import { InventoryItem, MovementType, Prisma } from '@prisma/client';
import { PrismaService } from '../../config/prisma.service';
import { Paginated, paginate } from '../../common/dto/paginated';
import { DomainError, DomainErrorCode } from '../../common/errors/domain-error';
import { PaginationQueryDto } from '../../common/dto/pagination-query.dto';
import { AuditService } from '../audit/audit.service';
import { NumberingService } from '../numbering/numbering.service';
import { AdjustStockDto } from './dto/adjust-stock.dto';
import { CreateItemDto } from './dto/create-item.dto';
import { QueryItemsDto } from './dto/query-items.dto';
import { UpdateItemDto } from './dto/update-item.dto';

export interface MovementInput {
  itemId: string;
  type: MovementType;
  quantityDelta: number; // signed: +in / -out
  referenceType?: string;
  referenceId?: string;
  performedById?: string;
  notes?: string;
}

@Injectable()
export class InventoryService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly numbering: NumberingService,
    private readonly audit: AuditService,
  ) {}

  /**
   * Tx-scoped stock primitive. Locks the stock row, validates the result is
   * non-negative, updates the cached `quantityOnHand`, and appends an
   * immutable movement. Used by issue/return/adjustment so stock is always
   * reconcilable against the movement log. MUST run inside a transaction.
   */
  async applyMovement(tx: Prisma.TransactionClient, input: MovementInput): Promise<number> {
    await tx.$queryRaw`SELECT id FROM "InventoryStock" WHERE "itemId" = ${input.itemId} FOR UPDATE`;

    const stock = await tx.inventoryStock.findUnique({ where: { itemId: input.itemId } });
    if (!stock) throw DomainError.notFound('Stock for item', input.itemId);

    const balanceAfter = stock.quantityOnHand + input.quantityDelta;
    if (balanceAfter < 0) {
      throw new DomainError(
        DomainErrorCode.INSUFFICIENT_STOCK,
        `Insufficient stock for item ${input.itemId}: have ${stock.quantityOnHand}, need ${-input.quantityDelta}`,
        { itemId: input.itemId, available: stock.quantityOnHand, requested: -input.quantityDelta },
      );
    }

    await tx.inventoryStock.update({
      where: { itemId: input.itemId },
      data: { quantityOnHand: balanceAfter },
    });
    await tx.inventoryMovement.create({
      data: {
        itemId: input.itemId,
        type: input.type,
        quantityDelta: input.quantityDelta,
        balanceAfter,
        referenceType: input.referenceType,
        referenceId: input.referenceId,
        performedById: input.performedById,
        notes: input.notes,
      },
    });
    return balanceAfter;
  }

  async createItem(dto: CreateItemDto, actorId: string): Promise<InventoryItem> {
    const category = await this.prisma.category.findUnique({ where: { id: dto.categoryId } });
    if (!category) throw DomainError.notFound('Category', dto.categoryId);

    const item = await this.prisma.$transaction(async (tx) => {
      const sku = await this.numbering.next(tx, 'ITM');
      const created = await tx.inventoryItem.create({
        data: {
          sku,
          name: dto.name,
          categoryId: dto.categoryId,
          unit: dto.unit ?? 'unit',
          costPrice: new Prisma.Decimal(dto.costPrice),
          sellingPrice: new Prisma.Decimal(dto.sellingPrice),
          reorderLevel: dto.reorderLevel ?? 0,
          stock: { create: { quantityOnHand: 0 } },
        },
      });
      if (dto.openingStock && dto.openingStock > 0) {
        await this.applyMovement(tx, {
          itemId: created.id,
          type: MovementType.INITIAL,
          quantityDelta: dto.openingStock,
          referenceType: 'INITIAL',
          performedById: actorId,
          notes: 'Opening stock',
        });
      }
      return created;
    });

    await this.audit.record({
      userId: actorId,
      action: 'CREATE',
      module: 'INVENTORY',
      entityType: 'InventoryItem',
      entityId: item.id,
      metadata: { sku: item.sku, openingStock: dto.openingStock ?? 0 },
    });
    return item;
  }

  async findAll(query: QueryItemsDto): Promise<Paginated<InventoryItem>> {
    const where: Prisma.InventoryItemWhereInput = {
      ...(query.categoryId ? { categoryId: query.categoryId } : {}),
      ...(query.active !== undefined ? { active: query.active } : {}),
      ...(query.search ? { name: { contains: query.search, mode: 'insensitive' } } : {}),
    };

    // Low stock = quantityOnHand <= reorderLevel. Cross-model comparison isn't
    // expressible in a Prisma `where`, so resolve the matching ids via SQL.
    if (query.lowStock) {
      const lowRows = await this.prisma.$queryRaw<{ id: string }[]>`
        SELECT i.id FROM "InventoryItem" i
        JOIN "InventoryStock" s ON s."itemId" = i.id
        WHERE s."quantityOnHand" <= i."reorderLevel"`;
      where.id = { in: lowRows.map((r) => r.id) };
    }

    const [items, total] = await this.prisma.$transaction([
      this.prisma.inventoryItem.findMany({
        where,
        include: { category: true, stock: true },
        orderBy: { [query.sortBy ?? 'createdAt']: query.sortOrder },
        skip: query.skip,
        take: query.limit,
      }),
      this.prisma.inventoryItem.count({ where }),
    ]);
    return paginate(items, total, query.page, query.limit);
  }

  async findOne(id: string) {
    const item = await this.prisma.inventoryItem.findUnique({
      where: { id },
      include: { category: true, stock: true },
    });
    if (!item) throw DomainError.notFound('InventoryItem', id);
    return item;
  }

  async update(id: string, dto: UpdateItemDto, actorId: string): Promise<InventoryItem> {
    await this.findOne(id);
    const data: Prisma.InventoryItemUpdateInput = {
      ...(dto.name !== undefined ? { name: dto.name } : {}),
      ...(dto.unit !== undefined ? { unit: dto.unit } : {}),
      ...(dto.reorderLevel !== undefined ? { reorderLevel: dto.reorderLevel } : {}),
      ...(dto.costPrice !== undefined ? { costPrice: new Prisma.Decimal(dto.costPrice) } : {}),
      ...(dto.sellingPrice !== undefined ? { sellingPrice: new Prisma.Decimal(dto.sellingPrice) } : {}),
      ...(dto.categoryId !== undefined ? { category: { connect: { id: dto.categoryId } } } : {}),
    };
    const item = await this.prisma.inventoryItem.update({ where: { id }, data });
    await this.audit.record({
      userId: actorId,
      action: 'UPDATE',
      module: 'INVENTORY',
      entityType: 'InventoryItem',
      entityId: id,
      metadata: { ...dto },
    });
    return item;
  }

  /** Manual stock correction (restock, wastage, count fix) — audited. */
  async adjustStock(id: string, dto: AdjustStockDto, actorId: string) {
    await this.findOne(id);
    const balanceAfter = await this.prisma.$transaction((tx) =>
      this.applyMovement(tx, {
        itemId: id,
        type: MovementType.ADJUSTMENT,
        quantityDelta: dto.quantityDelta,
        referenceType: 'ADJUSTMENT',
        performedById: actorId,
        notes: dto.reason,
      }),
    );
    await this.audit.record({
      userId: actorId,
      action: 'ADJUST',
      module: 'INVENTORY',
      entityType: 'InventoryItem',
      entityId: id,
      metadata: { quantityDelta: dto.quantityDelta, reason: dto.reason, balanceAfter },
    });
    return { itemId: id, quantityOnHand: balanceAfter };
  }

  async getMovements(id: string, query: PaginationQueryDto) {
    await this.findOne(id);
    const [items, total] = await this.prisma.$transaction([
      this.prisma.inventoryMovement.findMany({
        where: { itemId: id },
        orderBy: { createdAt: 'desc' },
        skip: query.skip,
        take: query.limit,
      }),
      this.prisma.inventoryMovement.count({ where: { itemId: id } }),
    ]);
    return paginate(items, total, query.page, query.limit);
  }
}
