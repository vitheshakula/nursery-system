import {
  Injectable,
  Logger,
  NotFoundException,
} from "@nestjs/common";
import {
  IdempotentOperationType,
  InventoryMovementType,
  LedgerEntryType,
  Prisma,
  SessionStatus,
} from "@prisma/client";
import { PrismaService } from "../../config/prisma.service";
import {
  DomainError,
  DomainErrorCode,
} from "../../common/errors/domain-error";
import { runIdempotent } from "../../common/idempotency/idempotency.util";
import { CloseSessionDto } from "./dto/close-session.dto";
import { IssueItemsDto } from "./dto/issue-items.dto";
import { ReturnItemsDto } from "./dto/return-items.dto";
import { StartSessionDto } from "./dto/start-session.dto";

@Injectable()
export class SessionsService {
  private readonly logger = new Logger(SessionsService.name);

  constructor(private readonly prisma: PrismaService) {}

  async findActiveSessions() {
    const sessions = await this.prisma.session.findMany({
      where: { status: SessionStatus.ACTIVE },
      orderBy: { createdAt: "desc" },
      include: {
        vendor: {
          select: {
            id: true,
            name: true,
            phone: true,
            balance: true,
          },
        },
        issueItems: {
          include: {
            plant: {
              select: {
                vendorPrice: true,
              },
            },
          },
        },
        returnItems: true,
      },
    });

    return sessions.map((session) => {
      const summary = this.calculateSessionTotals(
        session.issueItems,
        session.returnItems,
      );

      return {
        id: session.id,
        vendorId: session.vendorId,
        status: session.status,
        createdAt: session.createdAt,
        vendor: session.vendor,
        totalIssued: summary.totalIssued,
        totalReturned: summary.totalReturned,
        totalBill: summary.totalBill,
      };
    });
  }

  async startSession(data: StartSessionDto) {
    const vendor = await this.prisma.vendor.findUnique({
      where: { id: data.vendorId },
    });

    if (!vendor) {
      throw new NotFoundException("Vendor not found");
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
        status: SessionStatus.ACTIVE,
      },
    });

    this.logger.log(
      `Session started: sessionId=${session.id} vendorId=${session.vendorId}`,
    );

    return session;
  }

  async issueItems(sessionId: string, dto: IssueItemsDto) {
    return this.prisma.$transaction(async (tx) =>
      runIdempotent(
        tx,
        IdempotentOperationType.ISSUE_ITEMS,
        dto.requestId,
        async () => {
      await this.ensureSessionCanMutate(tx, sessionId);
      const requestedQuantityByPlant = this.groupQuantitiesByPlant(dto.items);
      const plantIds = Object.keys(requestedQuantityByPlant);
      const expectedStockByPlant = this.groupExpectedStockByPlant(dto.items);

      await this.ensurePlantsExist(tx, plantIds);
      await this.decrementStockForIssue(
        tx,
        requestedQuantityByPlant,
        expectedStockByPlant,
      );

      const createData = dto.items.map((item) => ({
        sessionId,
        plantId: item.plantId,
        quantity: item.quantity,
      }));

      await tx.issueItem.createMany({ data: createData });
      await tx.inventoryMovement.createMany({
        data: Object.entries(requestedQuantityByPlant).map(
          ([plantId, quantity]) => ({
            itemId: plantId,
            sessionId,
            type: InventoryMovementType.ISSUE_OUT,
            quantity: -quantity,
            notes: `Issued in session ${sessionId}`,
          }),
        ),
      });

      return {
        sessionId,
        issuedItemsCount: dto.items.length,
        totalIssuedQuantity: Object.values(requestedQuantityByPlant).reduce(
          (sum, quantity) => sum + quantity,
          0,
        ),
      };
        },
      ),
    );
  }

  async returnItems(sessionId: string, dto: ReturnItemsDto) {
    return this.prisma.$transaction(async (tx) =>
      runIdempotent(
        tx,
        IdempotentOperationType.RETURN_ITEMS,
        dto.requestId,
        async () => {
      await this.ensureSessionCanMutate(tx, sessionId);
      const requestedReturnByPlant = this.groupQuantitiesByPlant(dto.items);
      const plantIds = Object.keys(requestedReturnByPlant);

      await this.ensurePlantsExist(tx, plantIds);

      const issueItems = await tx.issueItem.findMany({
        where: { sessionId, plantId: { in: plantIds } },
      });

      const returnItems = await tx.returnItem.findMany({
        where: { sessionId, plantId: { in: plantIds } },
      });

      const issuedQuantityByPlant = issueItems.reduce<Record<string, number>>(
        (acc, item) => {
          acc[item.plantId] = (acc[item.plantId] ?? 0) + item.quantity;
          return acc;
        },
        {},
      );

      const returnedQuantityByPlant = returnItems.reduce<Record<string, number>>(
        (acc, item) => {
          acc[item.plantId] = (acc[item.plantId] ?? 0) + item.quantity;
          return acc;
        },
        {},
      );

      for (const plantId of Object.keys(requestedReturnByPlant)) {
        const issued = issuedQuantityByPlant[plantId] ?? 0;
        const alreadyReturned = returnedQuantityByPlant[plantId] ?? 0;
        const requested = requestedReturnByPlant[plantId];

        if (issued === 0) {
          throw new DomainError(
            DomainErrorCode.InvalidReturnQuantity,
            `No issued quantity found for plant ${plantId}`,
          );
        }

        if (alreadyReturned + requested > issued) {
          throw new DomainError(
            DomainErrorCode.InvalidReturnQuantity,
            `Return quantity for plant ${plantId} exceeds issued quantity`,
          );
        }
      }

      const createData = dto.items.map((item) => ({
        sessionId,
        plantId: item.plantId,
        quantity: item.quantity,
        condition: item.condition,
      }));

      await tx.returnItem.createMany({ data: createData });
      for (const [plantId, quantity] of Object.entries(requestedReturnByPlant)) {
        await tx.plant.update({
          where: { id: plantId },
          data: {
            currentStock: {
              increment: quantity,
            },
          },
        });
      }
      await tx.inventoryMovement.createMany({
        data: Object.entries(requestedReturnByPlant).map(
          ([plantId, quantity]) => ({
            itemId: plantId,
            sessionId,
            type: InventoryMovementType.RETURN_IN,
            quantity,
            notes: `Returned in session ${sessionId}`,
          }),
        ),
      });

      return {
        sessionId,
        returnedItemsCount: dto.items.length,
        totalReturnedQuantity: Object.values(requestedReturnByPlant).reduce(
          (sum, quantity) => sum + quantity,
          0,
        ),
      };
        },
      ),
    );
  }

  async getSessionSummary(sessionId: string) {
    return this.buildSessionSummary(this.prisma, sessionId);
  }

  async closeSession(sessionId: string, dto: CloseSessionDto = {}) {
    const result = await this.prisma.$transaction(async (tx) =>
      runIdempotent(
        tx,
        IdempotentOperationType.SESSION_CLOSE,
        dto.requestId,
        async () => {
      const session = await tx.session.findUnique({
        where: { id: sessionId },
      });

      if (!session) {
        throw new NotFoundException("Session not found");
      }

      this.assertTransitionAllowed(session.status, SessionStatus.CLOSED);

      const summary = await this.buildSessionSummary(tx, sessionId);
      const closedAt = new Date();

      const updatedSession = await tx.session.update({
        where: { id: sessionId },
        data: {
          status: SessionStatus.CLOSED,
          closedAt,
        },
      });

      await tx.ledgerEntry.create({
        data: {
          vendorId: session.vendorId,
          sessionId,
          type: LedgerEntryType.SESSION_DUE,
          amount: summary.totalBill,
          notes: `Session ${sessionId} closed`,
        },
      });

      const updatedVendor = await tx.vendor.update({
        where: { id: session.vendorId },
        data: {
          balance: {
            increment: summary.totalBill,
          },
        },
      });

      return {
        updatedSession,
        updatedVendor,
        summary,
        vendorId: session.vendorId,
      };
        },
      ),
    );

    this.logger.log(
      `Session closed: sessionId=${result.updatedSession.id} vendorId=${result.vendorId} totalBill=${result.summary.totalBill}`,
    );

    return {
      sessionId: result.updatedSession.id,
      status: result.updatedSession.status,
      closedAt: result.updatedSession.closedAt,
      totalBill: result.summary.totalBill,
      totalSold: result.summary.totalSold,
      vendorBalance: result.updatedVendor.balance,
      plants: result.summary.plants,
    };
  }

  private async buildSessionSummary(
    client: PrismaService | Prisma.TransactionClient,
    sessionId: string,
  ) {
    const [session, issueItems, returnItems] = await Promise.all([
      client.session.findUnique({
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
      client.issueItem.findMany({
        where: { sessionId },
        include: { plant: true },
      }),
      client.returnItem.findMany({
        where: { sessionId },
        include: { plant: true },
      }),
    ]);

    if (!session) {
      throw new NotFoundException("Session not found");
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

    const totalIssued = plantSummaries.reduce(
      (sum, item) => sum + item.issued,
      0,
    );
    const totalReturned = plantSummaries.reduce(
      (sum, item) => sum + item.returned,
      0,
    );
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

  private async ensureSessionCanMutate(
    client: PrismaService | Prisma.TransactionClient,
    sessionId: string,
  ) {
    const session = await client.session.findUnique({
      where: { id: sessionId },
    });

    if (!session) {
      throw new NotFoundException("Session not found");
    }

    if (session.status !== SessionStatus.ACTIVE) {
      throw new DomainError(
        session.status === SessionStatus.CLOSED
          ? DomainErrorCode.SessionAlreadyClosed
          : DomainErrorCode.InvalidSessionState,
        "Cannot modify a session that is not active",
      );
    }

    return session;
  }

  private assertTransitionAllowed(
    currentStatus: SessionStatus,
    nextStatus: SessionStatus,
  ) {
    if (
      currentStatus === SessionStatus.ACTIVE &&
      nextStatus === SessionStatus.CLOSED
    ) {
      return;
    }

    if (currentStatus === SessionStatus.CLOSED) {
      throw new DomainError(
        DomainErrorCode.SessionAlreadyClosed,
        "Session is already closed",
      );
    }

    throw new DomainError(
      DomainErrorCode.InvalidSessionState,
      `Cannot transition session from ${currentStatus} to ${nextStatus}`,
    );
  }

  private groupQuantitiesByPlant(
    items: Array<{ plantId: string; quantity: number }>,
  ) {
    return items.reduce<Record<string, number>>((acc, item) => {
      acc[item.plantId] = (acc[item.plantId] ?? 0) + item.quantity;
      return acc;
    }, {});
  }

  private groupExpectedStockByPlant(
    items: Array<{ plantId: string; expectedStock?: number }>,
  ) {
    return items.reduce<Record<string, number>>((acc, item) => {
      if (item.expectedStock !== undefined) {
        acc[item.plantId] = item.expectedStock;
      }
      return acc;
    }, {});
  }

  private async decrementStockForIssue(
    client: Prisma.TransactionClient,
    requestedQuantityByPlant: Record<string, number>,
    expectedStockByPlant: Record<string, number>,
  ) {
    for (const [plantId, quantity] of Object.entries(requestedQuantityByPlant)) {
      const guards = [
        { currentStock: { gte: quantity } },
        ...(expectedStockByPlant[plantId] === undefined
          ? []
          : [{ currentStock: expectedStockByPlant[plantId] }]),
      ];

      const result = await client.plant.updateMany({
        where: {
          id: plantId,
          AND: guards,
        },
        data: {
          currentStock: {
            decrement: quantity,
          },
        },
      });

      if (result.count === 1) {
        continue;
      }

      const plant = await client.plant.findUnique({ where: { id: plantId } });
      if (
        plant &&
        expectedStockByPlant[plantId] !== undefined &&
        plant.currentStock !== expectedStockByPlant[plantId]
      ) {
        throw new DomainError(
          DomainErrorCode.StaleInventoryState,
          `Inventory changed for plant ${plantId}`,
        );
      }

      throw new DomainError(
        DomainErrorCode.InsufficientStock,
        `Insufficient stock for plant ${plantId}`,
      );
    }
  }

  private calculateSessionTotals(
    issueItems: Array<{
      plantId: string;
      quantity: number;
      plant: { vendorPrice: number };
    }>,
    returnItems: Array<{ plantId: string; quantity: number }>,
  ) {
    const issuedByPlant = issueItems.reduce<
      Record<string, { quantity: number; vendorPrice: number }>
    >((acc, item) => {
      const current = acc[item.plantId] ?? {
        quantity: 0,
        vendorPrice: item.plant.vendorPrice,
      };
      current.quantity += item.quantity;
      acc[item.plantId] = current;
      return acc;
    }, {});

    const returnedByPlant = returnItems.reduce<Record<string, number>>(
      (acc, item) => {
        acc[item.plantId] = (acc[item.plantId] ?? 0) + item.quantity;
        return acc;
      },
      {},
    );

    const totalIssued = issueItems.reduce(
      (sum, item) => sum + item.quantity,
      0,
    );
    const totalReturned = returnItems.reduce(
      (sum, item) => sum + item.quantity,
      0,
    );
    const totalBill = Object.entries(issuedByPlant).reduce((sum, entry) => {
      const plantId = entry[0];
      const issued = entry[1];
      const sold = Math.max(
        issued.quantity - (returnedByPlant[plantId] ?? 0),
        0,
      );
      return sum + sold * issued.vendorPrice;
    }, 0);

    return {
      totalIssued,
      totalReturned,
      totalBill,
    };
  }

  private async ensurePlantsExist(
    client: PrismaService | Prisma.TransactionClient,
    plantIds: string[],
  ) {
    const uniquePlantIds = [...new Set(plantIds)];
    const plants = await client.plant.findMany({
      where: { id: { in: uniquePlantIds } },
      select: { id: true },
    });

    const foundPlantIds = new Set(plants.map((plant) => plant.id));
    const missingPlantId = uniquePlantIds.find(
      (plantId) => !foundPlantIds.has(plantId),
    );

    if (missingPlantId) {
      throw new DomainError(
        DomainErrorCode.InsufficientStock,
        `Plant ${missingPlantId} does not exist`,
      );
    }
  }
}
