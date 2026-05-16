import {
  CallHandler,
  ExecutionContext,
  Injectable,
  NestInterceptor,
} from '@nestjs/common';
import { Observable } from 'rxjs';
import { map } from 'rxjs/operators';

@Injectable()
export class ResponseInterceptor<T>
  implements NestInterceptor<T, { success: true; code: 'OK'; message: string; data: T }>
{
  intercept(
    _context: ExecutionContext,
    next: CallHandler<T>,
  ): Observable<{ success: true; code: 'OK'; message: string; data: T }> {
    return next.handle().pipe(
      map((data) => ({
        success: true as const,
        code: 'OK' as const,
        message: 'OK',
        data,
      })),
    );
  }
}
