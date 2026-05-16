# Phase 4 Offline + Production Notes

## Offline Foundation

- Local data is stored in `nursery_offline.db` through the Flutter `OfflineDatabase`.
- Cached read models currently include vendors, categories, plants, active sessions, and dashboard stats.
- Critical operations are written to the durable `operation_queue` table when the network is unavailable.
- Queue replay uses the same `requestId` values accepted by the backend idempotency layer.

## Queued Operations

Supported operation types:

- `issueItems`
- `returnItems`
- `createPayment`
- `closeSession`
- `adjustStock`

Queue statuses:

- `pending`
- `syncing`
- `completed`
- `failed`

Failed operations are returned to `pending` with exponential retry metadata.

## Conflict Strategy

- Server remains the authority for session state, ledger, and stock.
- Client operations are append-style and replayed with idempotency keys.
- Stock-sensitive requests can include last-known stock values for stale inventory detection.
- Destructive overwrite behavior should be avoided; prefer correction movements and ledger adjustments.

## Deployment Readiness

- Backend requires `DATABASE_URL`, `JWT_SECRET`, `JWT_EXPIRES_IN`, and `PORT`.
- Mobile builds should pass `API_BASE_URL` at compile time with `--dart-define`.
- Run database migrations before deploying a backend build generated from a newer Prisma schema.
- Keep `.env` out of source control and rotate Neon/JWT secrets before production use.

## Verification Notes

- Backend build and tests are passing.
- Flutter dependency resolution succeeds after clearing stale Flutter cache locks.
- Flutter analyze/test still require local SDK investigation because even `dart --version` hangs on this machine.
