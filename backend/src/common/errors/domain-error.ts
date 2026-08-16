/**
 * Domain-level error, decoupled from HTTP. Services throw these; the global
 * exception filter maps the `code` to an HTTP status. This keeps business
 * logic free of transport concerns and gives clients stable error codes.
 */
export enum DomainErrorCode {
  // 404
  NOT_FOUND = 'NOT_FOUND',
  // 409
  CONFLICT = 'CONFLICT',
  DUPLICATE = 'DUPLICATE',
  ALREADY_SETTLED = 'ALREADY_SETTLED',
  SETTLEMENT_FINALIZED = 'SETTLEMENT_FINALIZED',
  REQUEST_IN_PROGRESS = 'REQUEST_IN_PROGRESS',
  // 422 — business rule violations
  INSUFFICIENT_STOCK = 'INSUFFICIENT_STOCK',
  INVALID_RETURN_QUANTITY = 'INVALID_RETURN_QUANTITY',
  INACTIVE_ENTITY = 'INACTIVE_ENTITY',
  INVALID_STATE = 'INVALID_STATE',
  // 400
  VALIDATION = 'VALIDATION',
}

const STATUS_BY_CODE: Record<DomainErrorCode, number> = {
  [DomainErrorCode.NOT_FOUND]: 404,
  [DomainErrorCode.CONFLICT]: 409,
  [DomainErrorCode.DUPLICATE]: 409,
  [DomainErrorCode.ALREADY_SETTLED]: 409,
  [DomainErrorCode.SETTLEMENT_FINALIZED]: 409,
  [DomainErrorCode.REQUEST_IN_PROGRESS]: 409,
  [DomainErrorCode.INSUFFICIENT_STOCK]: 422,
  [DomainErrorCode.INVALID_RETURN_QUANTITY]: 422,
  [DomainErrorCode.INACTIVE_ENTITY]: 422,
  [DomainErrorCode.INVALID_STATE]: 422,
  [DomainErrorCode.VALIDATION]: 400,
};

export class DomainError extends Error {
  readonly code: DomainErrorCode;
  readonly httpStatus: number;
  readonly details?: Record<string, unknown>;

  constructor(code: DomainErrorCode, message: string, details?: Record<string, unknown>) {
    super(message);
    this.name = 'DomainError';
    this.code = code;
    this.httpStatus = STATUS_BY_CODE[code];
    this.details = details;
  }

  static notFound(entity: string, id?: string) {
    return new DomainError(
      DomainErrorCode.NOT_FOUND,
      id ? `${entity} '${id}' not found` : `${entity} not found`,
    );
  }

  static conflict(message: string, details?: Record<string, unknown>) {
    return new DomainError(DomainErrorCode.CONFLICT, message, details);
  }
}
