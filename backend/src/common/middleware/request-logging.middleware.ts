import { Injectable, Logger, NestMiddleware } from '@nestjs/common';
import { NextFunction, Request, Response } from 'express';
import { randomUUID } from 'crypto';

@Injectable()
export class RequestLoggingMiddleware implements NestMiddleware {
  private readonly logger = new Logger(RequestLoggingMiddleware.name);

  use(request: Request, response: Response, next: NextFunction) {
    const startedAt = Date.now();
    const correlationId =
      request.header('x-correlation-id') ??
      request.header('x-request-id') ??
      randomUUID();

    response.setHeader('x-correlation-id', correlationId);

    response.on('finish', () => {
      const durationMs = Date.now() - startedAt;
      this.logger.log(
        `${correlationId} ${request.method} ${request.originalUrl} ${response.statusCode} ${durationMs}ms`,
      );
    });

    next();
  }
}
