# API Inventory

Base prefix: `/api` · Auth: Bearer access token unless marked **public** · Swagger: `/api/docs`
Roles: **A** = ADMIN, **S** = STAFF.

## Auth
| Method | Path | Roles | Notes |
|---|---|---|---|
| POST | `/auth/login` | public | → access + refresh + user |
| POST | `/auth/refresh` | public | rotates token pair |
| POST | `/auth/logout` | public | revokes presented refresh token |
| GET | `/auth/me` | A/S | current user |

## Users / Staff (admin only)
| Method | Path | Notes |
|---|---|---|
| POST | `/users` | create staff/admin |
| GET | `/users` | list/search, filter role & active (paginated) |
| GET | `/users/:id` | |
| PATCH | `/users/:id` | update name/phone/role |
| PATCH | `/users/:id/activate` | |
| PATCH | `/users/:id/deactivate` | revokes their sessions |

## Vendors
| Method | Path | Roles |
|---|---|---|
| POST | `/vendors` | A/S |
| GET | `/vendors` | A/S — search, `active`, `withBalance` (paginated) |
| GET | `/vendors/:id` | A/S |
| GET | `/vendors/:id/history` | A/S — balance + recent activity |
| PATCH | `/vendors/:id` | A/S |
| PATCH | `/vendors/:id/activate` · `/deactivate` | A |

## Categories
| POST `/categories` (A) · GET `/categories` (A/S) |

## Inventory
| Method | Path | Roles |
|---|---|---|
| POST | `/inventory/items` | A — optional opening stock |
| GET | `/inventory/items` | A/S — filter category/active/lowStock (paginated) |
| GET | `/inventory/items/:id` | A/S |
| GET | `/inventory/items/:id/movements` | A/S — stock history |
| PATCH | `/inventory/items/:id` | A |
| POST | `/inventory/items/:id/stock-adjustments` | A — restock/wastage (audited) |

## Issue / Return / Settlement / Payment (engine)
| Method | Path | Roles | Idempotent |
|---|---|---|---|
| POST | `/issues` | A/S | ✓ |
| GET | `/issues` · `/issues/:id` | A/S | |
| POST | `/returns` | A/S | ✓ |
| GET | `/returns/:id` | A/S | |
| POST | `/settlements/generate` | A/S | (unique guard) |
| POST | `/settlements/:id/finalize` | A/S | ✓ — posts ledger, immutable |
| GET | `/settlements` · `/settlements/:id` | A/S | |
| POST | `/payments` | A/S | ✓ |
| GET | `/payments` · `/payments/:id` | A/S | |

## Ledger
| Method | Path | Roles |
|---|---|---|
| GET | `/ledger/vendors/:vendorId` | A/S — bank-statement (paginated) |
| POST | `/ledger/adjustments` | A — manual correction (only manual balance path, audited) |

Idempotent endpoints accept an optional `Idempotency-Key` header.
