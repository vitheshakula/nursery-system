import { Injectable } from '@nestjs/common';
import { InventoryMovementType, LedgerEntryType, SessionStatus } from '@prisma/client';
import { PrismaService } from '../../config/prisma.service';

type ClosedSessionInfo = {
  id: string;
  vendorId: string;
  closedAt: Date;
  vendor: {
    id: string;
    name: string;
    balance: number;
  };
};

@Injectable()
export class AnalyticsService {
  constructor(private readonly prisma: PrismaService) {}

  async getDashboardSummary() {
    const now = new Date();
    const startOfDay = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const endOfDay = new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1);

    const [closedToday, activeSessions, vendorsWithBalance] = await this.prisma.$transaction([
      this.prisma.session.findMany({
        where: {
          status: SessionStatus.CLOSED,
          closedAt: {
            gte: startOfDay,
            lt: endOfDay,
          },
        },
        select: {
          id: true,
        },
      }),
      this.prisma.session.count({
        where: {
          status: SessionStatus.ACTIVE,
        },
      }),
      this.prisma.vendor.count({
        where: {
          balance: {
            gt: 0,
          },
        },
      }),
    ]);

    let totalSales = 0;
    for (const session of closedToday) {
      const summary = await this.buildClosedSessionSummary(session.id);
      totalSales += summary.totalBill;
    }

    return {
      totalSales,
      activeSessions,
      vendorsWithBalance,
      date: startOfDay,
    };
  }

  async getMonthlySales() {
    const analytics = await this.buildClosedSessionAnalytics();
    const revenueByMonth = new Map<string, number>();

    for (const session of analytics.sessions) {
      const monthKey = this.formatMonthKey(session.closedAt);
      const currentRevenue = revenueByMonth.get(monthKey) ?? 0;
      revenueByMonth.set(monthKey, currentRevenue + (analytics.revenueBySession.get(session.id) ?? 0));
    }

    return Array.from(revenueByMonth.entries())
      .map(([month, revenue]) => ({
        month,
        revenue,
      }))
      .sort((left, right) => left.month.localeCompare(right.month));
  }

  async getTopPlants() {
    const analytics = await this.buildClosedSessionAnalytics();

    return Array.from(analytics.soldByPlant.entries())
      .map(([plantId, soldQuantity]) => {
        const plant = analytics.plants.get(plantId);

        return {
          plantId,
          name: plant?.name ?? 'Unknown',
          totalSoldQuantity: soldQuantity,
        };
      })
      .sort((left, right) => {
        if (right.totalSoldQuantity !== left.totalSoldQuantity) {
          return right.totalSoldQuantity - left.totalSoldQuantity;
        }

        return (analytics.revenueByPlant.get(right.plantId) ?? 0) - (analytics.revenueByPlant.get(left.plantId) ?? 0);
      });
  }

  async getVendorPerformance() {
    const analytics = await this.buildClosedSessionAnalytics();
    const performanceByVendor = new Map<
      string,
      {
        vendorId: string;
        vendorName: string;
        lifetimeRevenue: number;
        currentOutstandingBalance: number;
      }
    >();

    for (const session of analytics.sessions) {
      const existing = performanceByVendor.get(session.vendorId) ?? {
        vendorId: session.vendor.id,
        vendorName: session.vendor.name,
        lifetimeRevenue: 0,
        currentOutstandingBalance: session.vendor.balance,
      };

      existing.lifetimeRevenue += analytics.revenueBySession.get(session.id) ?? 0;
      performanceByVendor.set(session.vendorId, existing);
    }

    return Array.from(performanceByVendor.values()).sort(
      (left, right) => right.lifetimeRevenue - left.lifetimeRevenue,
    );
  }

  async getOperationalReport() {
    const { startOfDay, endOfDay } = this.getTodayBounds();

    const [
      issuedToday,
      returnedToday,
      collectionsToday,
      outstandingVendors,
      topIssuedGroups,
    ] = await this.prisma.$transaction([
      this.prisma.issueItem.aggregate({
        where: {
          createdAt: {
            gte: startOfDay,
            lt: endOfDay,
          },
        },
        _sum: { quantity: true },
      }),
      this.prisma.returnItem.aggregate({
        where: {
          createdAt: {
            gte: startOfDay,
            lt: endOfDay,
          },
        },
        _sum: { quantity: true },
      }),
      this.prisma.ledgerEntry.aggregate({
        where: {
          type: LedgerEntryType.PAYMENT_RECEIVED,
          createdAt: {
            gte: startOfDay,
            lt: endOfDay,
          },
        },
        _sum: { amount: true },
      }),
      this.prisma.vendor.findMany({
        where: {
          balance: {
            gt: 0,
          },
        },
        select: {
          id: true,
          name: true,
          phone: true,
          balance: true,
        },
        orderBy: { balance: 'desc' },
      }),
      this.prisma.issueItem.groupBy({
        by: ['plantId'],
        where: {
          createdAt: {
            gte: startOfDay,
            lt: endOfDay,
          },
        },
        _sum: { quantity: true },
        orderBy: {
          _sum: {
            quantity: 'desc',
          },
        },
        take: 10,
      }),
    ]);

    const topPlantIds = topIssuedGroups.map((item) => item.plantId);
    const plants = await this.prisma.plant.findMany({
      where: { id: { in: topPlantIds } },
      select: { id: true, name: true, vendorPrice: true },
    });
    const plantMap = new Map(plants.map((plant) => [plant.id, plant]));

    return {
      date: startOfDay,
      todayIssuedQuantity: issuedToday._sum.quantity ?? 0,
      todayReturnedQuantity: returnedToday._sum.quantity ?? 0,
      todayCollections: Math.abs(collectionsToday._sum.amount ?? 0),
      vendorOutstandingSummary: {
        vendorCount: outstandingVendors.length,
        totalOutstanding: outstandingVendors.reduce(
          (sum, vendor) => sum + vendor.balance,
          0,
        ),
        vendors: outstandingVendors,
      },
      topMovingInventoryItems: topIssuedGroups.map((item) => {
        const plant = plantMap.get(item.plantId);
        return {
          plantId: item.plantId,
          name: plant?.name ?? 'Unknown',
          issuedQuantity: item._sum?.quantity ?? 0,
          vendorPrice: plant?.vendorPrice ?? 0,
        };
      }),
    };
  }

  async getOperationalInsights(days = 7, lowStockThreshold = 5, largeBalanceThreshold = 1000) {
    const safeDays = Math.max(1, Math.min(days, 90));
    const safeLowStockThreshold = Math.max(0, lowStockThreshold);
    const safeLargeBalanceThreshold = Math.max(0, largeBalanceThreshold);
    const now = new Date();
    const since = new Date(now.getFullYear(), now.getMonth(), now.getDate() - safeDays + 1);
    const today = this.getTodayBounds();
    const staleBefore = new Date(now.getFullYear(), now.getMonth(), now.getDate() - 30);

    const [
      lowStockItems,
      movementGroups,
      adjustmentGroups,
      stagnantItems,
      largeBalanceVendors,
      todayCollections,
      activeSessions,
    ] = await this.prisma.$transaction([
      this.prisma.plant.findMany({
        where: { currentStock: { lte: safeLowStockThreshold } },
        select: {
          id: true,
          name: true,
          currentStock: true,
          vendorPrice: true,
        },
        orderBy: [{ currentStock: 'asc' }, { name: 'asc' }],
        take: 10,
      }),
      this.prisma.inventoryMovement.groupBy({
        by: ['itemId', 'type'],
        where: { createdAt: { gte: since } },
        _sum: { quantity: true },
        _count: { _all: true },
        orderBy: [{ itemId: 'asc' }, { type: 'asc' }],
      }),
      this.prisma.inventoryMovement.groupBy({
        by: ['itemId'],
        where: {
          type: { in: [InventoryMovementType.ADJUSTMENT, InventoryMovementType.DAMAGE] },
          createdAt: { gte: since },
        },
        _count: { _all: true },
        _sum: { quantity: true },
        orderBy: { _count: { itemId: 'desc' } },
        take: 10,
      }),
      this.prisma.plant.findMany({
        where: {
          currentStock: { gt: safeLowStockThreshold },
          inventoryMovements: {
            none: { createdAt: { gte: staleBefore } },
          },
        },
        select: {
          id: true,
          name: true,
          currentStock: true,
          updatedAt: true,
        },
        orderBy: [{ currentStock: 'desc' }, { name: 'asc' }],
        take: 10,
      }),
      this.prisma.vendor.findMany({
        where: { balance: { gte: safeLargeBalanceThreshold } },
        select: {
          id: true,
          name: true,
          phone: true,
          balance: true,
          updatedAt: true,
        },
        orderBy: { balance: 'desc' },
        take: 10,
      }),
      this.prisma.ledgerEntry.aggregate({
        where: {
          type: LedgerEntryType.PAYMENT_RECEIVED,
          createdAt: { gte: today.startOfDay, lt: today.endOfDay },
        },
        _sum: { amount: true },
      }),
      this.prisma.session.count({ where: { status: SessionStatus.ACTIVE } }),
    ]);

    const reconciliationRisk = await Promise.all([
      this.prisma.plant.count({
        where: {
          currentStock: {
            not: 0,
          },
          inventoryMovements: {
            none: {},
          },
        },
      }),
      this.prisma.vendor.count({
        where: {
          balance: { not: 0 },
          ledgerEntries: { none: {} },
        },
      }),
    ]);

    const plantIds = [
      ...new Set([
        ...movementGroups.map((item) => item.itemId),
        ...adjustmentGroups.map((item) => item.itemId),
      ]),
    ];
    const plants = await this.prisma.plant.findMany({
      where: { id: { in: plantIds } },
      select: { id: true, name: true, currentStock: true },
    });
    const plantMap = new Map(plants.map((plant) => [plant.id, plant]));

    const movementByPlant = new Map<
      string,
      { itemId: string; name: string; issued: number; returned: number; netMovement: number; movementCount: number }
    >();

    for (const group of movementGroups) {
      const plant = plantMap.get(group.itemId);
      const current = movementByPlant.get(group.itemId) ?? {
        itemId: group.itemId,
        name: plant?.name ?? 'Unknown',
        issued: 0,
        returned: 0,
        netMovement: 0,
        movementCount: 0,
      };

      const quantity = group._sum?.quantity ?? 0;
      if (group.type === InventoryMovementType.ISSUE_OUT) {
        current.issued += Math.abs(quantity);
      }
      if (group.type === InventoryMovementType.RETURN_IN) {
        current.returned += quantity;
      }
      current.netMovement += quantity;
      current.movementCount += this.readGroupCount(group._count);
      movementByPlant.set(group.itemId, current);
    }

    const topMovingItems = Array.from(movementByPlant.values())
      .sort((left, right) => right.issued - left.issued)
      .slice(0, 10);

    const movementSpikeItems = topMovingItems.filter((item) => item.issued >= 25);

    const repeatedAdjustments = adjustmentGroups.map((item) => {
      const plant = plantMap.get(item.itemId);
      return {
        itemId: item.itemId,
        name: plant?.name ?? 'Unknown',
        adjustmentCount: this.readGroupCount(item._count),
        netAdjustment: item._sum?.quantity ?? 0,
      };
    });

    const alerts = [
      ...lowStockItems.map((item) => ({
        type: 'LOW_STOCK',
        severity: item.currentStock === 0 ? 'HIGH' : 'MEDIUM',
        message: `${item.name} stock is ${item.currentStock}`,
        refId: item.id,
      })),
      ...largeBalanceVendors.map((vendor) => ({
        type: 'LARGE_BALANCE',
        severity: 'MEDIUM',
        message: `${vendor.name} outstanding is ${vendor.balance}`,
        refId: vendor.id,
      })),
      ...repeatedAdjustments
        .filter((item) => item.adjustmentCount >= 2)
        .map((item) => ({
          type: 'REPEATED_ADJUSTMENT',
          severity: 'MEDIUM',
          message: `${item.name} adjusted ${item.adjustmentCount} times`,
          refId: item.itemId,
        })),
      ...movementSpikeItems.map((item) => ({
        type: 'MOVEMENT_SPIKE',
        severity: 'LOW',
        message: `${item.name} issued ${item.issued} in ${safeDays} days`,
        refId: item.itemId,
      })),
    ];

    return {
      windowDays: safeDays,
      generatedAt: now,
      dailySnapshot: {
        activeSessions,
        todayCollections: Math.abs(todayCollections._sum.amount ?? 0),
        lowStockCount: lowStockItems.length,
        largeBalanceCount: largeBalanceVendors.length,
        reconciliationRiskCount: reconciliationRisk[0] + reconciliationRisk[1],
      },
      alerts: alerts.slice(0, 20),
      inventory: {
        lowStockItems,
        topMovingItems,
        movementSpikeItems,
        repeatedAdjustments,
        stagnantItems,
      },
      vendors: {
        largeBalanceVendors,
      },
    };
  }

  private async buildClosedSessionAnalytics() {
    const sessions = await this.prisma.session.findMany({
      where: {
        status: SessionStatus.CLOSED,
        closedAt: { not: null },
      },
      select: {
        id: true,
        vendorId: true,
        closedAt: true,
        vendor: {
          select: {
            id: true,
            name: true,
            balance: true,
          },
        },
      },
      orderBy: { closedAt: 'asc' },
    });

    const normalizedSessions: ClosedSessionInfo[] = sessions
      .filter((session): session is typeof session & { closedAt: Date } => session.closedAt !== null)
      .map((session) => ({
        id: session.id,
        vendorId: session.vendorId,
        closedAt: session.closedAt,
        vendor: session.vendor,
      }));

    if (normalizedSessions.length === 0) {
      return {
        sessions: normalizedSessions,
        plants: new Map<string, { name: string; vendorPrice: number }>(),
        soldByPlant: new Map<string, number>(),
        revenueByPlant: new Map<string, number>(),
        revenueBySession: new Map<string, number>(),
      };
    }

    const sessionIds = normalizedSessions.map((session) => session.id);

    const [issuedGroups, returnedGroups] = await this.prisma.$transaction([
      this.prisma.issueItem.groupBy({
        by: ['sessionId', 'plantId'],
        where: { sessionId: { in: sessionIds } },
        orderBy: [{ sessionId: 'asc' }, { plantId: 'asc' }],
        _sum: { quantity: true },
      }),
      this.prisma.returnItem.groupBy({
        by: ['sessionId', 'plantId'],
        where: { sessionId: { in: sessionIds } },
        orderBy: [{ sessionId: 'asc' }, { plantId: 'asc' }],
        _sum: { quantity: true },
      }),
    ]);

    const plantIds = [...new Set(issuedGroups.map((item) => item.plantId))];
    const plants = await this.prisma.plant.findMany({
      where: { id: { in: plantIds } },
      select: {
        id: true,
        name: true,
        vendorPrice: true,
      },
    });

    const plantMap = new Map(
      plants.map((plant) => [
        plant.id,
        {
          name: plant.name,
          vendorPrice: plant.vendorPrice,
        },
      ]),
    );

    const returnedBySessionPlant = new Map<string, number>();
    for (const item of returnedGroups) {
      returnedBySessionPlant.set(
        this.buildSessionPlantKey(item.sessionId, item.plantId),
        item._sum?.quantity ?? 0,
      );
    }

    const soldByPlant = new Map<string, number>();
    const revenueByPlant = new Map<string, number>();
    const revenueBySession = new Map<string, number>();

    for (const item of issuedGroups) {
      const plant = plantMap.get(item.plantId);
      if (!plant) {
        continue;
      }

      const issuedQuantity = item._sum?.quantity ?? 0;
      const returnedQuantity =
        returnedBySessionPlant.get(this.buildSessionPlantKey(item.sessionId, item.plantId)) ?? 0;
      const soldQuantity = Math.max(issuedQuantity - returnedQuantity, 0);
      const revenue = soldQuantity * plant.vendorPrice;

      soldByPlant.set(item.plantId, (soldByPlant.get(item.plantId) ?? 0) + soldQuantity);
      revenueByPlant.set(item.plantId, (revenueByPlant.get(item.plantId) ?? 0) + revenue);
      revenueBySession.set(item.sessionId, (revenueBySession.get(item.sessionId) ?? 0) + revenue);
    }

    return {
      sessions: normalizedSessions,
      plants: plantMap,
      soldByPlant,
      revenueByPlant,
      revenueBySession,
    };
  }

  private async buildClosedSessionSummary(sessionId: string) {
    const [issueItems, returnItems] = await this.prisma.$transaction([
      this.prisma.issueItem.findMany({
        where: { sessionId },
        include: { plant: true },
      }),
      this.prisma.returnItem.findMany({
        where: { sessionId },
        include: { plant: true },
      }),
    ]);

    const issuedByPlant = issueItems.reduce<Record<string, { quantity: number; vendorPrice: number }>>(
      (acc, item) => {
        const current = acc[item.plantId] ?? {
          quantity: 0,
          vendorPrice: item.plant.vendorPrice,
        };
        current.quantity += item.quantity;
        acc[item.plantId] = current;
        return acc;
      },
      {},
    );

    const returnedByPlant = returnItems.reduce<Record<string, number>>((acc, item) => {
      acc[item.plantId] = (acc[item.plantId] ?? 0) + item.quantity;
      return acc;
    }, {});

    const totalBill = Object.entries(issuedByPlant).reduce((sum, entry) => {
      const plantId = entry[0];
      const issued = entry[1];
      const sold = Math.max(issued.quantity - (returnedByPlant[plantId] ?? 0), 0);
      return sum + sold * issued.vendorPrice;
    }, 0);

    return { totalBill };
  }

  private buildSessionPlantKey(sessionId: string, plantId: string) {
    return `${sessionId}:${plantId}`;
  }

  private readGroupCount(count: true | { _all?: number } | undefined) {
    return typeof count === 'object' ? count._all ?? 0 : 0;
  }

  private formatMonthKey(date: Date) {
    return `${date.getUTCFullYear()}-${String(date.getUTCMonth() + 1).padStart(2, '0')}`;
  }

  private getTodayBounds() {
    const now = new Date();
    return {
      startOfDay: new Date(now.getFullYear(), now.getMonth(), now.getDate()),
      endOfDay: new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1),
    };
  }
}
