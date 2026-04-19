import { Injectable } from '@nestjs/common';
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
          status: 'CLOSED',
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
          status: 'ACTIVE',
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

  private async buildClosedSessionAnalytics() {
    const sessions = await this.prisma.session.findMany({
      where: {
        status: 'CLOSED',
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

  private formatMonthKey(date: Date) {
    return `${date.getUTCFullYear()}-${String(date.getUTCMonth() + 1).padStart(2, '0')}`;
  }
}
