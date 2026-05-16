import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import {
  IdempotentOperationType,
  InventoryMovementType,
  Plant,
} from '@prisma/client';
import { PrismaService } from '../../config/prisma.service';
import {
  DomainError,
  DomainErrorCode,
} from '../../common/errors/domain-error';
import { runIdempotent } from '../../common/idempotency/idempotency.util';
import { AdjustStockDto } from './dto/adjust-stock.dto';
import { CreatePlantDto } from './dto/create-plant.dto';

@Injectable()
export class PlantsService {
  constructor(private readonly prisma: PrismaService) {}

  async create(createPlantDto: CreatePlantDto): Promise<Plant> {
    const category = await this.prisma.category.findUnique({
      where: { id: createPlantDto.categoryId },
    });

    if (!category) {
      throw new BadRequestException('Invalid categoryId provided');
    }

    const { initialStock = 0, ...plantData } = createPlantDto;

    return this.prisma.$transaction(async (tx) => {
      const plant = await tx.plant.create({
        data: {
          ...plantData,
          currentStock: initialStock,
        },
      });

      if (initialStock > 0) {
        await tx.inventoryMovement.create({
          data: {
            itemId: plant.id,
            type: InventoryMovementType.PURCHASE,
            quantity: initialStock,
            notes: 'Initial stock',
          },
        });
      }

      return plant;
    });
  }

  async findAll(page: number, limit: number): Promise<Plant[]> {
    const safePage = Math.max(1, page);
    const safeLimit = Math.max(1, limit);
    const skip = (safePage - 1) * safeLimit;

    return this.prisma.plant.findMany({
      skip,
      take: safeLimit,
      orderBy: { createdAt: 'desc' },
    });
  }

  async findOne(id: string): Promise<Plant> {
    const plant = await this.prisma.plant.findUnique({
      where: { id },
    });

    if (!plant) {
      throw new NotFoundException(`Plant with id ${id} not found`);
    }

    return plant;
  }

  async getStockSummary() {
    return this.prisma.plant.findMany({
      select: {
        id: true,
        name: true,
        categoryId: true,
        vendorPrice: true,
        retailPrice: true,
        currentStock: true,
        updatedAt: true,
      },
      orderBy: { name: 'asc' },
    });
  }

  async getLowStockItems(threshold: number) {
    return this.prisma.plant.findMany({
      where: {
        currentStock: {
          lte: Math.max(0, threshold),
        },
      },
      orderBy: [{ currentStock: 'asc' }, { name: 'asc' }],
    });
  }

  async getMovementHistory(itemId?: string, limit = 100) {
    return this.prisma.inventoryMovement.findMany({
      where: itemId ? { itemId } : undefined,
      take: Math.max(1, Math.min(limit, 500)),
      orderBy: { createdAt: 'desc' },
      include: {
        plant: {
          select: {
            id: true,
            name: true,
            currentStock: true,
          },
        },
      },
    });
  }

  async getDailyInventoryFlow() {
    const now = new Date();
    const startOfDay = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const endOfDay = new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1);

    const movementGroups = await this.prisma.inventoryMovement.groupBy({
      by: ['type'],
      where: {
        createdAt: {
          gte: startOfDay,
          lt: endOfDay,
        },
      },
      _sum: { quantity: true },
    });

    return {
      date: startOfDay,
      flows: movementGroups.map((item) => ({
        type: item.type,
        quantity: item._sum.quantity ?? 0,
      })),
    };
  }

  async adjustStock(id: string, dto: AdjustStockDto) {
    return this.prisma.$transaction(async (tx) =>
      runIdempotent(
        tx,
        IdempotentOperationType.INVENTORY_ADJUSTMENT,
        dto.requestId,
        async () => {
          if (dto.quantity === 0) {
            throw new DomainError(
              DomainErrorCode.InvalidStockOperation,
              'Adjustment quantity cannot be zero',
            );
          }

          const stockGuards = [
            ...(dto.expectedStock === undefined
              ? []
              : [{ currentStock: dto.expectedStock }]),
            ...(dto.quantity < 0
              ? [{ currentStock: { gte: Math.abs(dto.quantity) } }]
              : []),
          ];

          const updateResult = await tx.plant.updateMany({
            where: {
              id,
              ...(stockGuards.length === 0 ? {} : { AND: stockGuards }),
            },
            data: {
              currentStock: {
                increment: dto.quantity,
              },
            },
          });

          if (updateResult.count !== 1) {
            const plant = await tx.plant.findUnique({ where: { id } });
            if (!plant) {
              throw new NotFoundException(`Plant with id ${id} not found`);
            }

            if (
              dto.expectedStock !== undefined &&
              plant.currentStock !== dto.expectedStock
            ) {
              throw new DomainError(
                DomainErrorCode.StaleInventoryState,
                'Inventory changed since the request was prepared',
              );
            }

            throw new DomainError(
              DomainErrorCode.InsufficientStock,
              'Adjustment would make stock negative',
            );
          }

          const updatedPlant = await tx.plant.findUniqueOrThrow({
            where: { id },
          });

          await tx.inventoryMovement.create({
            data: {
              itemId: id,
              type:
                dto.quantity < 0
                  ? InventoryMovementType.DAMAGE
                  : InventoryMovementType.ADJUSTMENT,
              quantity: dto.quantity,
              notes: dto.reason,
            },
          });

          return updatedPlant;
        },
      ),
    );
  }
}
