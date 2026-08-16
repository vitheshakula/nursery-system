import { Injectable, Logger } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../config/prisma.service';
import { DomainError, DomainErrorCode } from '../errors/domain-error';

/**
 * Guarantees a mutating operation runs at most once per idempotency key.
 *
 *  - No key  -> runs `work` directly (idempotency opt-in).
 *  - First call with a key -> reserves it (IN_PROGRESS), runs `work`,
 *    stores the serialized result (COMPLETED), returns it.
 *  - Replay with a COMPLETED key -> returns the cached result, no re-processing.
 *  - Replay while IN_PROGRESS -> rejected as a concurrent duplicate.
 *
 * Critical for offline sync, where the client may resend the same operation.
 */
@Injectable()
export class IdempotencyService {
  private readonly logger = new Logger(IdempotencyService.name);

  constructor(private readonly prisma: PrismaService) {}

  async execute<T>(key: string | undefined, scope: string, work: () => Promise<T>): Promise<T> {
    if (!key) return work();

    const existing = await this.prisma.idempotencyRecord.findUnique({ where: { key } });
    if (existing) {
      if (existing.status === 'COMPLETED') {
        this.logger.log(`Idempotency replay for ${scope} key=${key}`);
        return existing.result as T;
      }
      throw new DomainError(
        DomainErrorCode.REQUEST_IN_PROGRESS,
        'A request with this idempotency key is already being processed',
      );
    }

    try {
      await this.prisma.idempotencyRecord.create({
        data: { key, scope, status: 'IN_PROGRESS' },
      });
    } catch (e) {
      // Lost a race to insert the same key — treat as concurrent duplicate.
      if (e instanceof Prisma.PrismaClientKnownRequestError && e.code === 'P2002') {
        const again = await this.prisma.idempotencyRecord.findUnique({ where: { key } });
        if (again?.status === 'COMPLETED') return again.result as T;
      }
      throw new DomainError(
        DomainErrorCode.REQUEST_IN_PROGRESS,
        'A request with this idempotency key is already being processed',
      );
    }

    try {
      const result = await work();
      await this.prisma.idempotencyRecord.update({
        where: { key },
        data: { status: 'COMPLETED', result: result as Prisma.InputJsonValue },
      });
      return result;
    } catch (err) {
      // Failed — release the key so the client can legitimately retry.
      await this.prisma.idempotencyRecord.delete({ where: { key } }).catch(() => undefined);
      throw err;
    }
  }
}
