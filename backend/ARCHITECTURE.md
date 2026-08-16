# Backend Architecture — Nursery Vendor Inventory & Settlement System

Status: **Foundation complete & verified.** NestJS + Prisma + PostgreSQL (Neon).
Build passes; full issue→return→settle→pay flow smoke-tested live.

## 1. Layered architecture

```
HTTP ─▶ Controller ─▶ Service ─▶ Prisma (Repository) ─▶ PostgreSQL
            │            │
   DTO validation    business rules + DB transactions
   RBAC guards       ledger/stock/audit/numbering helpers

Cross-cutting (global):
  ValidationPipe ▸ JwtAuthGuard ▸ RolesGuard ▸ LoggingInterceptor
  ▸ Handler ▸ ResponseInterceptor ({success,data}) ▸ AllExceptionsFilter
```

## 2. Core invariants

| Invariant | How it's enforced |
|---|---|
| Vendor balance derived from ledger | `VendorLedger` append-only; `Vendor.currentBalance` written **only** by `LedgerService.append` inside the same tx, under `SELECT … FOR UPDATE` |
| Stock derived from movements | `InventoryStock.quantityOnHand` written only by `InventoryService.applyMovement`, with an `InventoryMovement` row each time |
| One settlement per issue cycle | `Settlement.issueTransactionId @unique` + status guard |
| Settlement immutable | Finalize sets `FINALIZED`; re-finalize rejected (`SETTLEMENT_FINALIZED`) |
| No double-processing on retry | `IdempotencyService.execute(key,…)` on issue/return/finalize/payment |
| Atomic numbering | `Counter` raw `INSERT … ON CONFLICT DO UPDATE … RETURNING` inside tx |
| Balance only moves at settlement/payment | Issue/Return ledger entries are activity-only (debit=credit=0) |

## 3. Settlement math

```
sold(item)      = issued(item) − Σ returned(item)
lineTotal(item) = sold(item) × sellingPriceSnapshot(item)
settlementTotal = Σ lineTotal
On finalize:  ledger debit = settlementTotal  ⇒  currentBalance += settlementTotal
On payment:   ledger credit = amount          ⇒  currentBalance −= amount
```

## 4. Module dependency map

```
                 ┌─────────── Global infra (every feature can inject) ───────────┐
                 │ PrismaModule  IdempotencyModule  NumberingModule               │
                 │ AuditModule   LedgerModule                                     │
                 └───────────────────────────────────────────────────────────────┘
AuthModule ───────────────▶ TokenService (exported)
UsersModule ──▶ AuthModule(TokenService), AuditService
VendorsModule ──▶ Numbering, Audit
CategoriesModule ──▶ (Prisma)
InventoryModule ──▶ Numbering, Audit            (exports InventoryService.applyMovement)
IssueModule ──▶ InventoryModule, Ledger, Numbering, Audit, Idempotency
ReturnModule ──▶ InventoryModule, Ledger, Numbering, Audit, Idempotency
SettlementModule ──▶ Ledger, Numbering, Audit, Idempotency
PaymentModule ──▶ Ledger, Numbering, Audit, Idempotency
LedgerModule(controller) ──▶ Ledger(adjust/getStatement), Audit
```

## 5. Auth model

- **Access token** (15m, stateless) — `JwtAccessStrategy` re-checks user active on every request.
- **Refresh token** (7d) — backed by revocable `RefreshToken` row (sha-256 hash stored). Rotated on `/auth/refresh`. Deactivating a user revokes all their refresh tokens.
- **RBAC** — `@Roles(ADMIN|STAFF)` + global `RolesGuard`. `@Public()` opts out of auth.

## 6. Error envelope

Success: `{ "success": true, "data": … }`  (paginated data = `{ items, meta }`)
Error:   `{ "success": false, statusCode, code, message, details?, path, timestamp }`
`DomainError` codes map to HTTP (e.g. `INSUFFICIENT_STOCK`→422, `ALREADY_SETTLED`→409).

See `API_INVENTORY.md` for the full endpoint list. Swagger UI: `/api/docs`.
