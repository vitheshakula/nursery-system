import { randomUUID } from 'crypto';
import { HttpStatus } from '@nestjs/common';
import { IdempotentOperationType, Prisma } from '@prisma/client';
import { DomainError, DomainErrorCode } from '../errors/domain-error';

type TxClient = Prisma.TransactionClient;

export async function runIdempotent<T extends object>(
  tx: TxClient,
  operation: IdempotentOperationType,
  requestId: string | undefined,
  callback: () => Promise<T>,
): Promise<T> {
  if (!requestId) {
    return callback();
  }

  try {
    await tx.idempotencyRecord.create({
      data: {
        requestId,
        operation,
      },
    });
  } catch (error) {
    if (isUniqueConstraintError(error)) {
      const existing = await tx.idempotencyRecord.findUnique({
        where: { requestId },
      });

      if (existing?.response) {
        return existing.response as T;
      }

      throw new DomainError(
        DomainErrorCode.DuplicateRequest,
        'Request is already being processed',
        HttpStatus.CONFLICT,
      );
    }

    throw error;
  }

  const response = await callback();

  await tx.idempotencyRecord.update({
    where: { requestId },
    data: {
      response: JSON.parse(JSON.stringify(response)) as Prisma.InputJsonValue,
    },
  });

  return response;
}

export function createOperationId() {
  return randomUUID();
}

function isUniqueConstraintError(error: unknown) {
  return (
    error instanceof Prisma.PrismaClientKnownRequestError &&
    error.code === 'P2002'
  );
}
