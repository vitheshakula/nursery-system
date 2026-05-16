import {
  ArgumentsHost,
  Catch,
  ExceptionFilter,
  HttpException,
  HttpStatus,
  Logger,
} from '@nestjs/common';
import { Response } from 'express';
import { DomainErrorCode } from '../errors/domain-error';

@Catch()
export class HttpExceptionFilter implements ExceptionFilter {
  private readonly logger = new Logger(HttpExceptionFilter.name);

  catch(exception: unknown, host: ArgumentsHost) {
    const context = host.switchToHttp();
    const response = context.getResponse<Response>();

    const status =
      exception instanceof HttpException
        ? exception.getStatus()
        : HttpStatus.INTERNAL_SERVER_ERROR;

    const { code, message } = this.getErrorDetails(exception);

    if (status >= HttpStatus.INTERNAL_SERVER_ERROR) {
      this.logger.error(message, exception instanceof Error ? exception.stack : undefined);
    }

    response.status(status).json({
      success: false,
      code,
      message,
    });
  }

  private getErrorDetails(exception: unknown) {
    if (exception instanceof HttpException) {
      const exceptionResponse = exception.getResponse();

      if (typeof exceptionResponse === 'string') {
        return {
          code: this.statusToCode(exception.getStatus()),
          message: exceptionResponse,
        };
      }

      if (typeof exceptionResponse === 'object' && exceptionResponse !== null) {
        const body = exceptionResponse as {
          code?: string;
          message?: string | string[];
        };
        const message = body.message;

        if (Array.isArray(message)) {
          return {
            code: body.code ?? this.statusToCode(exception.getStatus()),
            message: message.join(', '),
          };
        }

        if (typeof message === 'string') {
          return {
            code: body.code ?? this.statusToCode(exception.getStatus()),
            message,
          };
        }
      }

      return {
        code: this.statusToCode(exception.getStatus()),
        message: exception.message,
      };
    }

    if (exception instanceof Error) {
      return {
        code: 'INTERNAL_SERVER_ERROR',
        message: exception.message,
      };
    }

    return {
      code: 'INTERNAL_SERVER_ERROR',
      message: 'Internal server error',
    };
  }

  private statusToCode(status: number) {
    if (status === HttpStatus.NOT_FOUND) {
      return DomainErrorCode.NotFound;
    }

    if (status >= HttpStatus.INTERNAL_SERVER_ERROR) {
      return 'INTERNAL_SERVER_ERROR';
    }

    return 'REQUEST_FAILED';
  }
}
