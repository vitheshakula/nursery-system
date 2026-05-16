# Reconciliation Test Plan

## Stock Accuracy

For each plant:

1. Export or inspect `InventoryMovement` rows.
2. Calculate `SUM(quantity)` grouped by `itemId`.
3. Compare the result with `Plant.currentStock`.
4. Investigate any row from `/api/reconciliation/stock` where `hasDrift = true`.

## Vendor Balance Accuracy

For each vendor:

1. Export or inspect `LedgerEntry` rows.
2. Calculate `SUM(amount)` grouped by `vendorId`.
3. Compare the result with `Vendor.balance`.
4. Investigate any row from `/api/reconciliation/balances` where `hasDrift = true`.

## Session Calculation Cross-Check

For a closed session:

1. Sum issued quantity by plant.
2. Sum returned quantity by plant.
3. Calculate sold quantity as `issued - returned`.
4. Multiply sold quantity by plant vendor price.
5. Compare manual total with session close result and `SESSION_DUE` ledger entry.

## Payment Cross-Check

For each payment:

1. Confirm a `Payment` row exists.
2. Confirm a matching `PAYMENT_RECEIVED` ledger entry exists.
3. Confirm amount sign is negative in the ledger.
4. Confirm vendor balance reduced exactly once, even if the request was replayed.

## Sync Replay Cross-Check

1. Queue an operation offline.
2. Restart the app.
3. Sync when online.
4. Confirm the server applied the operation once.
5. Replay the same `requestId`.
6. Confirm the backend returns the saved idempotent response without duplicate mutation.
