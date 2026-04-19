import { BadRequestException, Injectable, Logger, NotFoundException } from '@nestjs/common';
import { SessionStatus } from '@prisma/client';
import { PrismaService } from '../../config/prisma.service';
import { IssueItemsDto } from './dto/issue-items.dto';
import { ReturnItemsDto } from './dto/return-items.dto';
import { StartSessionDto } from './dto/start-session.dto';

@Injectable()
export class SessionsService {
  private readonly logger = new Logger(SessionsService.name);

  constructor(private readonly prisma: PrismaService) {}

  async startSession(data: StartSessionDto) {
    const vendor = await this.prisma.vendor.findUnique({
      where: { id: data.vendorId },
    });

    if (!vendor) {
      throw new NotFoundException('Vendor not found');
    }

    const activeSession = await this.prisma.session.findFirst({
      where: { vendorId: data.vendorId, status: SessionStatus.ACTIVE },
    });

    if (activeSession) {
      return activeSession;
    }

    const session = await this.prisma.session.create({
      data: {
        vendorId: data.vendorId,
      },
    });

    this.logger.log(`Session started: sessionId=${session.id} vendorId=${session.vendorId}`);

    return session;
  }

  async issueItems(sessionId: string, dto: IssueItemsDto) {
    await this.ensureActiveSession(sessionId);
    const requestedQuantityByPlant = this.groupQuantitiesByPlant(dto.items);
    const plantIds = Object.keys(requestedQuantityByPlant);

    await this.ensurePlantsExist(plantIds);

    const createData = dto.items.map((item) => ({
      sessionId,
      plantId: item.plantId,
      quantity: item.quantity,
    }));

    await this.prisma.issueItem.createMany({ data: createData });

    return {
      sessionId,
      issuedItemsCount: dto.items.length,
      totalIssuedQuantity: Object.values(requestedQuantityByPlant).reduce((sum, quantity) => sum + quantity, 0),
    };
  }

  async returnItems(sessionId: string, dto: ReturnItemsDto) {
    await this.ensureActiveSession(sessionId);
    const requestedReturnByPlant = this.groupQuantitiesByPlant(dto.items);
    const plantIds = Object.keys(requestedReturnByPlant);

    await this.ensurePlantsExist(plantIds);

    const issueItems = await this.prisma.issueItem.findMany({
      where: { sessionId, plantId: { in: plantIds } },
    });

    const returnItems = await this.prisma.returnItem.findMany({
      where: { sessionId, plantId: { in: plantIds } },
    });

    const issuedQuantityByPlant = issueItems.reduce<Record<string, number>>((acc, item) => {
      acc[item.plantId] = (acc[item.plantId] ?? 0) + item.quantity;
      return acc;
    }, {});

    const returnedQuantityByPlant = returnItems.reduce<Record<string, number>>((acc, item) => {
      acc[item.plantId] = (acc[item.plantId] ?? 0) + item.quantity;
      return acc;
    }, {});

    for (const plantId of Object.keys(requestedReturnByPlant)) {
      const issued = issuedQuantityByPlant[plantId] ?? 0;
      const alreadyReturned = returnedQuantityByPlant[plantId] ?? 0;
      const requested = requestedReturnByPlant[plantId];

      if (issued === 0) {
        throw new BadRequestException(`No issued quantity found for plant ${plantId}`);
      }

      if (alreadyReturned + requested > issued) {
        throw new BadRequestException(`Return quantity for plant ${plantId} exceeds issued quantity`);
      }
    }

    const createData = dto.items.map((item) => ({
      sessionId,
      plantId: item.plantId,
      quantity: item.quantity,
      condition: item.condition,
    }));

    await this.prisma.returnItem.createMany({ data: createData });

    return {
      sessionId,
      returnedItemsCount: dto.items.length,
      totalReturnedQuantity: Object.values(requestedReturnByPlant).reduce((sum, quantity) => sum + quantity, 0),
    };
  }

  async getSessionSummary(sessionId: string) {
    const [session, issueItems, returnItems] = await this.prisma.$transaction([
      this.prisma.session.findUnique({
        where: { id: sessionId },
        include: {
          vendor: {
            select: {
              id: true,
              name: true,
            },
          },
        },
      }),
      this.prisma.issueItem.findMany({
        where: { sessionId },
        include: { plant: true },
      }),
      this.prisma.returnItem.findMany({
        where: { sessionId },
        include: { plant: true },
      }),
    ]);

    if (!session) {
      throw new NotFoundException('Session not found');
    }

    const summaryByPlant = new Map<
      string,
      {
        plantId: string;
        name: string;
        vendorPrice: number;
        issued: number;
        returned: number;
      }
    >();

    for (const item of issueItems) {
      const record = summaryByPlant.get(item.plantId) ?? {
        plantId: item.plantId,
        name: item.plant.name,
        vendorPrice: item.plant.vendorPrice,
        issued: 0,
        returned: 0,
      };

      record.issued += item.quantity;
      summaryByPlant.set(item.plantId, record);
    }

    for (const item of returnItems) {
      const record = summaryByPlant.get(item.plantId) ?? {
        plantId: item.plantId,
        name: item.plant.name,
        vendorPrice: item.plant.vendorPrice,
        issued: 0,
        returned: 0,
      };

      record.returned += item.quantity;
      summaryByPlant.set(item.plantId, record);
    }

    const plantSummaries = Array.from(summaryByPlant.values()).map((entry) => {
      const sold = entry.issued - entry.returned;
      return {
        plantId: entry.plantId,
        name: entry.name,
        issued: entry.issued,
        returned: entry.returned,
        sold,
        unitPrice: entry.vendorPrice,
        total: sold * entry.vendorPrice,
      };
    });

    const totalIssued = plantSummaries.reduce((sum, item) => sum + item.issued, 0);
    const totalReturned = plantSummaries.reduce((sum, item) => sum + item.returned, 0);
    const totalSold = plantSummaries.reduce((sum, item) => sum + item.sold, 0);
    const totalBill = plantSummaries.reduce((sum, item) => sum + item.total, 0);

    return {
      sessionId,
      vendor: session.vendor,
      status: session.status,
      createdAt: session.createdAt,
      closedAt: session.closedAt,
      totalIssued,
      totalReturned,
      totalSold,
      totalBill,
      plants: plantSummaries,
    };
  }

  async closeSession(sessionId: string) {
    const session = await this.prisma.session.findUnique({
      where: { id: sessionId },
    });

    if (!session) {
      throw new NotFoundException('Session not found');
    }

    if (session.status !== SessionStatus.ACTIVE) {
      throw new BadRequestException('Session is already closed');
    }

    const summary = await this.getSessionSummary(sessionId);
    const closedAt = new Date();
    const [updatedSession, updatedVendor] = await this.prisma.$transaction([
      this.prisma.session.update({
        where: { id: sessionId },
        data: {
          status: SessionStatus.CLOSED,
          closedAt,
        },
      }),
      this.prisma.vendor.update({
        where: { id: session.vendorId },
        data: {
          balance: {
            increment: summary.totalBill,
          },
        },
      }),
    ]);

    this.logger.log(
      `Session closed: sessionId=${updatedSession.id} vendorId=${session.vendorId} totalBill=${summary.totalBill}`,
    );

    return {
      sessionId: updatedSession.id,
      status: updatedSession.status,
      closedAt: updatedSession.closedAt,
      totalBill: summary.totalBill,
      totalSold: summary.totalSold,
      vendorBalance: updatedVendor.balance,
      plants: summary.plants,
    };
  }

  private async ensureActiveSession(sessionId: string) {
    const session = await this.prisma.session.findUnique({
      where: { id: sessionId },
    });

    if (!session) {
      throw new NotFoundException('Session not found');
    }

    if (session.status !== SessionStatus.ACTIVE) {
      throw new BadRequestException('Cannot modify a closed session');
    }

    return session;
  }

  private groupQuantitiesByPlant(items: Array<{ plantId: string; quantity: number }>) {
    return items.reduce<Record<string, number>>((acc, item) => {
      acc[item.plantId] = (acc[item.plantId] ?? 0) + item.quantity;
      return acc;
    }, {});
  }

  private async ensurePlantsExist(plantIds: string[]) {
    const uniquePlantIds = [...new Set(plantIds)];
    const plants = await this.prisma.plant.findMany({
      where: { id: { in: uniquePlantIds } },
      select: { id: true },
    });

    const foundPlantIds = new Set(plants.map((plant) => plant.id));
    const missingPlantId = uniquePlantIds.find((plantId) => !foundPlantIds.has(plantId));

    if (missingPlantId) {
      throw new BadRequestException(`Plant ${missingPlantId} does not exist`);
    }
  }
}
