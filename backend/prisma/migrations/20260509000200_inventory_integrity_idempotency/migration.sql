-- Phase 3.5: immutable inventory movements and replay-safe operation records.

CREATE TYPE "InventoryMovementType" AS ENUM (
    'ISSUE_OUT',
    'RETURN_IN',
    'DAMAGE',
    'ADJUSTMENT',
    'PURCHASE'
);

CREATE TYPE "IdempotentOperationType" AS ENUM (
    'ISSUE_ITEMS',
    'RETURN_ITEMS',
    'SESSION_CLOSE',
    'PAYMENT_CREATE',
    'INVENTORY_ADJUSTMENT'
);

ALTER TABLE "Plant" ADD COLUMN "currentStock" INTEGER NOT NULL DEFAULT 0;

CREATE TABLE "InventoryMovement" (
    "id" TEXT NOT NULL,
    "itemId" TEXT NOT NULL,
    "sessionId" TEXT,
    "type" "InventoryMovementType" NOT NULL,
    "quantity" INTEGER NOT NULL,
    "notes" TEXT,
    "createdBy" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "InventoryMovement_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "IdempotencyRecord" (
    "id" TEXT NOT NULL,
    "requestId" TEXT NOT NULL,
    "operation" "IdempotentOperationType" NOT NULL,
    "response" JSONB,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "IdempotencyRecord_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "InventoryMovement_itemId_createdAt_idx" ON "InventoryMovement"("itemId", "createdAt");
CREATE INDEX "InventoryMovement_sessionId_idx" ON "InventoryMovement"("sessionId");
CREATE INDEX "InventoryMovement_type_createdAt_idx" ON "InventoryMovement"("type", "createdAt");
CREATE UNIQUE INDEX "IdempotencyRecord_requestId_key" ON "IdempotencyRecord"("requestId");
CREATE INDEX "IdempotencyRecord_operation_createdAt_idx" ON "IdempotencyRecord"("operation", "createdAt");

ALTER TABLE "InventoryMovement" ADD CONSTRAINT "InventoryMovement_itemId_fkey" FOREIGN KEY ("itemId") REFERENCES "Plant"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "InventoryMovement" ADD CONSTRAINT "InventoryMovement_sessionId_fkey" FOREIGN KEY ("sessionId") REFERENCES "Session"("id") ON DELETE SET NULL ON UPDATE CASCADE;
