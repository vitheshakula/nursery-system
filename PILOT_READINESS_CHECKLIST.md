# Pilot Readiness Checklist

## Daily Operator Checks

- Review operational signals on the home dashboard.
- Check low-stock items before issuing sessions.
- Review large outstanding balances before new settlement activity.
- Open sync diagnostics and resolve failed queued operations.
- Check reconciliation summary at end of day.

## Weekly Business Review

- Compare stock reconciliation output against physical counts.
- Compare vendor ledger-derived balances against stored balances.
- Review repeated inventory adjustments and damage movements.
- Review top moving plants and stagnant stock.
- Review vendor balances that remain high across the week.

## Pilot Rollout

- Start with one device and one operator.
- Keep manual paper totals for the first week as a fallback.
- Run database backup before each pilot day.
- Confirm app can queue operations offline and replay once online.
- Confirm duplicate payment/session requests do not double-apply.

## Rollback Plan

- Stop mobile usage.
- Export current vendor balances, ledger entries, and inventory movements.
- Restore the latest Neon backup or branch snapshot if data corruption is confirmed.
- Reconcile any paper-recorded operations before resuming.

## Alert Tuning

- Low stock threshold starts at `5`.
- Large balance threshold starts at `1000`.
- Movement spike threshold starts at `25 issued items in 7 days`.
- Tune thresholds after one week of actual usage.
