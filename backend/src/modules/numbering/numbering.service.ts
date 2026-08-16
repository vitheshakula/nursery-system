import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';

export type NumberingPrefix = 'ISS' | 'RET' | 'STL' | 'PAY' | 'VEN' | 'ITM';

interface NumberingOptions {
  /** 'daily' -> PREFIX-YYYYMMDD-0001 (resets per day); 'global' -> PREFIX-0001. */
  scope?: 'daily' | 'global';
  pad?: number;
}

/**
 * Generates human-readable, gap-tolerant sequential document numbers.
 *
 * Atomicity & concurrency: a single `INSERT ... ON CONFLICT DO UPDATE
 * ... RETURNING` statement increments the counter row under a row lock, so
 * two concurrent callers can never receive the same number. MUST be called
 * with the surrounding transaction client so the number and the entity it
 * labels commit (or roll back) together.
 */
@Injectable()
export class NumberingService {
  async next(
    tx: Prisma.TransactionClient,
    prefix: NumberingPrefix,
    options: NumberingOptions = {},
  ): Promise<string> {
    const { scope = 'global', pad = 4 } = options;
    const datePart = scope === 'daily' ? this.dateKey() : null;
    const counterKey = datePart ? `${prefix}:${datePart}` : prefix;

    const rows = await tx.$queryRaw<{ value: number }[]>`
      INSERT INTO "Counter" (key, value) VALUES (${counterKey}, 1)
      ON CONFLICT (key) DO UPDATE SET value = "Counter".value + 1
      RETURNING value;
    `;
    const seq = rows[0].value;
    const seqPart = String(seq).padStart(pad, '0');

    return datePart ? `${prefix}-${datePart}-${seqPart}` : `${prefix}-${seqPart}`;
  }

  private dateKey(date = new Date()): string {
    const y = date.getFullYear();
    const m = String(date.getMonth() + 1).padStart(2, '0');
    const d = String(date.getDate()).padStart(2, '0');
    return `${y}${m}${d}`;
  }
}
