import { createParamDecorator, ExecutionContext } from '@nestjs/common';

/**
 * Pulls the optional `Idempotency-Key` header. Mutating endpoints pass it to
 * the engine so retried (offline-replayed) requests are de-duplicated.
 */
export const IdempotencyKey = createParamDecorator(
  (_data: unknown, ctx: ExecutionContext): string | undefined => {
    const request = ctx.switchToHttp().getRequest();
    const header = request.headers['idempotency-key'];
    return Array.isArray(header) ? header[0] : header;
  },
);
