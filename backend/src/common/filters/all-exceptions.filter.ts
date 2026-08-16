import {
  ArgumentsHost,
  Catch,
  ExceptionFilter,
  HttpException,
  HttpStatus,
  Logger,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { Request, Response } from 'express';
import { DomainError } from '../errors/domain-error';

interface ErrorBody {
  success: false;
  statusCode: number;
  code: string;
  message: string;
  details?: unknown;
  path: string;
  timestamp: string;
}

/**
 * Single global filter. Normalises DomainError, Prisma errors, Nest
 * HttpExceptions and unknown throwables into one stable error envelope.
 */
@Catch()
export class AllExceptionsFilter implements ExceptionFilter {
  private readonly logger = new Logger(AllExceptionsFilter.name);

  catch(exception: unknown, host: ArgumentsHost) {
    const ctx = host.switchToHttp();
    const res = ctx.getResponse<Response>();
    const req = ctx.getRequest<Request>();

    const { status, code, message, details } = this.normalise(exception);

    const body: ErrorBody = {
      success: false,
      statusCode: status,
      code,
      message,
      details,
      path: req.url,
      timestamp: new Date().toISOString(),
    };

    if (status >= HttpStatus.INTERNAL_SERVER_ERROR) {
      this.logger.error(
        `${req.method} ${req.url} -> ${status} ${message}`,
        exception instanceof Error ? exception.stack : undefined,
      );
    } else {
      this.logger.warn(`${req.method} ${req.url} -> ${status} ${code}: ${message}`);
    }

    res.status(status).json(body);
  }

  private normalise(exception: unknown): {
    status: number;
    code: string;
    message: string;
    details?: unknown;
  } {
    if (exception instanceof DomainError) {
      return {
        status: exception.httpStatus,
        code: exception.code,
        message: exception.message,
        details: exception.details,
      };
    }

    if (exception instanceof Prisma.PrismaClientKnownRequestError) {
      return this.fromPrisma(exception);
    }

    if (exception instanceof HttpException) {
      const response = exception.getResponse();
      const message =
        typeof response === 'string'
          ? response
          : this.extractMessage((response as Record<string, unknown>).message) ??
            exception.message;
      return {
        status: exception.getStatus(),
        code: this.codeFromStatus(exception.getStatus()),
        message,
      };
    }

    return {
      status: HttpStatus.INTERNAL_SERVER_ERROR,
      code: 'INTERNAL_ERROR',
      message: 'Internal server error',
    };
  }

  private fromPrisma(e: Prisma.PrismaClientKnownRequestError) {
    switch (e.code) {
      case 'P2002': // unique constraint
        return {
          status: HttpStatus.CONFLICT,
          code: 'DUPLICATE',
          message: `Duplicate value for ${(e.meta?.target as string[])?.join(', ') ?? 'field'}`,
        };
      case 'P2025': // record not found
        return {
          status: HttpStatus.NOT_FOUND,
          code: 'NOT_FOUND',
          message: (e.meta?.cause as string) ?? 'Record not found',
        };
      case 'P2003': // FK constraint
        return {
          status: HttpStatus.CONFLICT,
          code: 'FK_CONSTRAINT',
          message: 'Operation violates a reference constraint',
        };
      default:
        return {
          status: HttpStatus.BAD_REQUEST,
          code: `PRISMA_${e.code}`,
          message: 'Database request error',
        };
    }
  }

  private extractMessage(message: unknown): string | undefined {
    if (Array.isArray(message)) return message.join(', ');
    if (typeof message === 'string') return message;
    return undefined;
  }

  private codeFromStatus(status: number): string {
    return HttpStatus[status] ?? 'ERROR';
  }
}
