const assert = require('node:assert/strict');
const test = require('node:test');

function sessionTotal(issuedItems, returnedItems) {
  const returnedByItem = new Map();
  for (const item of returnedItems) {
    returnedByItem.set(item.itemId, (returnedByItem.get(item.itemId) ?? 0) + item.quantity);
  }

  return issuedItems.reduce((sum, item) => {
    const returned = returnedByItem.get(item.itemId) ?? 0;
    const sold = Math.max(item.quantity - returned, 0);
    return sum + sold * item.price;
  }, 0);
}

function closeSession(vendor, session) {
  if (session.status !== 'active') {
    throw new Error('Session is already closed');
  }

  const totalAmount = sessionTotal(session.issuedItems, session.returnedItems);
  return {
    vendor: {
      ...vendor,
      pendingBalance: vendor.pendingBalance + totalAmount,
    },
    session: {
      ...session,
      totalAmount,
      status: 'closed',
    },
  };
}

function collectPayment(vendor, amount) {
  if (amount <= 0) {
    throw new Error('Payment amount must be positive');
  }

  if (amount > vendor.pendingBalance) {
    throw new Error('Payment amount exceeds vendor outstanding balance');
  }

  return {
    ...vendor,
    pendingBalance: vendor.pendingBalance - amount,
  };
}

function issueStock(item, quantity) {
  if (quantity <= 0) {
    throw new Error('Invalid stock operation');
  }

  if (quantity > item.currentStock) {
    throw new Error('Insufficient stock');
  }

  return {
    item: {
      ...item,
      currentStock: item.currentStock - quantity,
    },
    movement: {
      itemId: item.id,
      type: 'ISSUE_OUT',
      quantity: -quantity,
    },
  };
}

function replayIdempotent(cache, requestId, operation) {
  if (cache.has(requestId)) {
    return cache.get(requestId);
  }

  const result = operation();
  cache.set(requestId, result);
  return result;
}

test('closing a session adds total amount to vendor pending balance', () => {
  const result = closeSession(
    { id: 'vendor-1', pendingBalance: 100 },
    {
      id: 'session-1',
      status: 'active',
      issuedItems: [
        { itemId: 'rose', quantity: 10, price: 12 },
        { itemId: 'mango', quantity: 2, price: 50 },
      ],
      returnedItems: [{ itemId: 'rose', quantity: 4 }],
      totalAmount: 0,
    },
  );

  assert.equal(result.session.totalAmount, 172);
  assert.equal(result.vendor.pendingBalance, 272);
  assert.equal(result.session.status, 'closed');
});

test('closed sessions are immutable', () => {
  assert.throws(
    () =>
      closeSession(
        { id: 'vendor-1', pendingBalance: 100 },
        {
          id: 'session-1',
          status: 'closed',
          issuedItems: [],
          returnedItems: [],
          totalAmount: 0,
        },
      ),
    /already closed/,
  );
});

test('payment reduces pending balance without touching sessions', () => {
  const vendor = collectPayment({ id: 'vendor-1', pendingBalance: 500 }, 125);
  assert.equal(vendor.pendingBalance, 375);
});

test('overpayment, zero payment, and negative payment fail', () => {
  assert.throws(
    () => collectPayment({ id: 'vendor-1', pendingBalance: 50 }, 51),
    /exceeds/,
  );
  assert.throws(
    () => collectPayment({ id: 'vendor-1', pendingBalance: 50 }, 0),
    /positive/,
  );
  assert.throws(
    () => collectPayment({ id: 'vendor-1', pendingBalance: 50 }, -1),
    /positive/,
  );
});

test('large quantities and prices are calculated correctly', () => {
  const total = sessionTotal(
    [{ itemId: 'bulk', quantity: 100000, price: 99.5 }],
    [{ itemId: 'bulk', quantity: 25000 }],
  );

  assert.equal(total, 7462500);
});

test('issuing stock creates a matching negative inventory movement', () => {
  const result = issueStock({ id: 'rose', currentStock: 20 }, 6);

  assert.equal(result.item.currentStock, 14);
  assert.deepEqual(result.movement, {
    itemId: 'rose',
    type: 'ISSUE_OUT',
    quantity: -6,
  });
});

test('negative stock is rejected before mutation', () => {
  assert.throws(
    () => issueStock({ id: 'rose', currentStock: 5 }, 6),
    /Insufficient stock/,
  );
});

test('idempotent replay returns the first result without repeating operation', () => {
  const cache = new Map();
  let executions = 0;
  const operation = () => {
    executions += 1;
    return { paymentId: 'payment-1', vendorBalance: 75 };
  };

  const first = replayIdempotent(cache, 'request-1', operation);
  const second = replayIdempotent(cache, 'request-1', operation);

  assert.equal(executions, 1);
  assert.deepEqual(first, second);
});
