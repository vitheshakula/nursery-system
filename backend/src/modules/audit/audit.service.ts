import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../config/prisma.service';

export interface AuditInput {
  userId?: string;
  action: string; // CREATE | UPDATE | DEACTIVATE | ISSUE | RETURN | SETTLE | PAY | ADJUST
  module: string; // VENDOR | INVENTORY | ISSUE | RETURN | SETTLEMENT | PAYMENT | USER
  entityType?: string;
  entityId?: string;
  metadata?: Prisma.InputJsonValue;
}

/**
 * Append-only audit log. Pass the active transaction client when the audit
 * must commit atomically with the action it records (issue/return/settle/pay);
 * otherwise the default Prisma client is used.
 */
@Injectable()
export class AuditService {
  constructor(private readonly prisma: PrismaService) {}

  async record(input: AuditInput, tx?: Prisma.TransactionClient): Promise<void> {
    const client = tx ?? this.prisma;
    await client.auditLog.create({
      data: {
        userId: input.userId,
        action: input.action,
        module: input.module,
        entityType: input.entityType,
        entityId: input.entityId,
        metadata: input.metadata,
      },
    });
  }
}
