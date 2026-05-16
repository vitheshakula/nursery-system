import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../config/prisma.service';

@Injectable()
export class ReconciliationService {
  constructor(private readonly prisma: PrismaService) {}

  async getStockReconciliation() {
    const [plants, movementGroups] = await this.prisma.$transaction([
      this.prisma.plant.findMany({
        select: {
          id: true,
          name: true,
          currentStock: true,
          updatedAt: true,
        },
        orderBy: { name: 'asc' },
      }),
      this.prisma.inventoryMovement.groupBy({
        by: ['itemId'],
        orderBy: { itemId: 'asc' },
        _sum: { quantity: true },
      }),
    ]);

    const movementStockByItem = new Map(
      movementGroups.map((item) => [item.itemId, item._sum?.quantity ?? 0]),
    );

    return plants.map((plant) => {
      const movementDerivedStock = movementStockByItem.get(plant.id) ?? 0;
      const discrepancy = plant.currentStock - movementDerivedStock;

      return {
        itemId: plant.id,
        name: plant.name,
        storedStock: plant.currentStock,
        movementDerivedStock,
        discrepancy,
        hasDrift: discrepancy !== 0,
        updatedAt: plant.updatedAt,
      };
    });
  }

  async getBalanceReconciliation() {
    const [vendors, ledgerGroups] = await this.prisma.$transaction([
      this.prisma.vendor.findMany({
        select: {
          id: true,
          name: true,
          phone: true,
          balance: true,
          updatedAt: true,
        },
        orderBy: { name: 'asc' },
      }),
      this.prisma.ledgerEntry.groupBy({
        by: ['vendorId'],
        orderBy: { vendorId: 'asc' },
        _sum: { amount: true },
      }),
    ]);

    const ledgerBalanceByVendor = new Map(
      ledgerGroups.map((item) => [item.vendorId, item._sum?.amount ?? 0]),
    );

    return vendors.map((vendor) => {
      const ledgerDerivedBalance = ledgerBalanceByVendor.get(vendor.id) ?? 0;
      const discrepancy = vendor.balance - ledgerDerivedBalance;

      return {
        vendorId: vendor.id,
        name: vendor.name,
        phone: vendor.phone,
        storedBalance: vendor.balance,
        ledgerDerivedBalance,
        discrepancy,
        hasDrift: Math.abs(discrepancy) > 0.0001,
        updatedAt: vendor.updatedAt,
      };
    });
  }

  async getSummary() {
    const [stock, balances] = await Promise.all([
      this.getStockReconciliation(),
      this.getBalanceReconciliation(),
    ]);

    const stockDrift = stock.filter((item) => item.hasDrift);
    const balanceDrift = balances.filter((item) => item.hasDrift);

    return {
      stockItemsChecked: stock.length,
      stockDriftCount: stockDrift.length,
      balanceAccountsChecked: balances.length,
      balanceDriftCount: balanceDrift.length,
      hasOperationalDrift: stockDrift.length > 0 || balanceDrift.length > 0,
    };
  }

  async getAdjustmentHistory(limit = 100) {
    const safeLimit = Math.max(1, Math.min(limit, 500));

    const [inventoryAdjustments, ledgerCorrections] = await this.prisma.$transaction([
      this.prisma.inventoryMovement.findMany({
        where: {
          type: { in: ['ADJUSTMENT', 'DAMAGE'] },
        },
        include: {
          plant: {
            select: {
              id: true,
              name: true,
              currentStock: true,
            },
          },
        },
        orderBy: { createdAt: 'desc' },
        take: safeLimit,
      }),
      this.prisma.ledgerEntry.findMany({
        where: {
          type: { in: ['BALANCE_ADJUSTMENT', 'MANUAL_CORRECTION', 'REFUND'] },
        },
        include: {
          vendor: {
            select: {
              id: true,
              name: true,
              balance: true,
            },
          },
        },
        orderBy: { createdAt: 'desc' },
        take: safeLimit,
      }),
    ]);

    return {
      inventoryAdjustments,
      ledgerCorrections,
    };
  }
}
