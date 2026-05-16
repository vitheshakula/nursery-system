import { HttpException, HttpStatus } from "@nestjs/common";

export enum DomainErrorCode {
  SessionAlreadyClosed = "SESSION_ALREADY_CLOSED",
  InvalidSessionState = "INVALID_SESSION_STATE",
  InsufficientStock = "INSUFFICIENT_STOCK",
  InvalidStockOperation = "INVALID_STOCK_OPERATION",
  StaleInventoryState = "STALE_INVENTORY_STATE",
  DuplicateRequest = "DUPLICATE_REQUEST",
  OverpaymentNotAllowed = "OVERPAYMENT_NOT_ALLOWED",
  InvalidReturnQuantity = "INVALID_RETURN_QUANTITY",
  NotFound = "NOT_FOUND",
}

export class DomainError extends HttpException {
  constructor(
    readonly code: DomainErrorCode,
    message: string,
    status: HttpStatus = HttpStatus.BAD_REQUEST,
  ) {
    super({ code, message }, status);
  }
}
