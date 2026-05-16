# Deployment Runbook

## Environments

- `staging`: test migrations, sync replay, reports, Android debug/release candidates.
- `production`: live nursery operations only.

Each environment must use separate:

- `DATABASE_URL`
- `JWT_SECRET`
- API base URL
- Neon project or branch

## Backend Deployment

1. Confirm CI is green.
2. Take a database backup or Neon branch snapshot.
3. Deploy pending Prisma migrations:

   ```bash
   npx prisma migrate deploy
   ```

4. Generate Prisma client and build:

   ```bash
   npm ci
   npm run prisma:generate
   npm run build
   ```

5. Start the backend with production environment variables.
6. Verify:
   - `/api/auth/login`
   - `/api/reconciliation/summary`
   - `/api/analytics/operational-report`

## Android Release

Build with an environment-specific API URL:

```bash
flutter build apk --release --dart-define=API_BASE_URL=https://api.example.com/api
```

Before release:

- Verify app icon and splash on a physical Android device.
- Confirm login, session issue/return, payment, close, and sync retry flows.
- Confirm no queued operation is duplicated after app restart.
- Store signing keys outside the repository.

## Backup Strategy

- Take a backup/snapshot before every production migration.
- Keep at least one daily backup while the system is actively used.
- Test restore on staging before relying on backups operationally.

## Failure Drill

Before production rollout, run:

- no internet for 30+ minutes
- interrupted sync during payment
- duplicate replay using the same `requestId`
- stale inventory replay
- app background/resume during queued operations
