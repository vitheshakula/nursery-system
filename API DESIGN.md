# 🌐 API DESIGN

# Nursery Vendor Inventory \& Settlement System

### 1\. 🧭 API Principles (follow these)

* RESTful
* Resource-based URLs
* Consistent responses
* No business logic in controller (NestJS service layer)

### 2\. 🔐 Authentication APIs

#### Login

&#x09;POST /auth/login

#### Request

&#x09;{

&#x20; 	  "accessToken": "jwt\_token",

&#x20; 	  "user": {

&#x20;   	    "id": "uuid",

&#x20;   	    "name": "Admin",

&#x20;   	    "role": "ADMIN"

&#x20; 	  }

&#x09;}

#### Refresh Token

&#x09;POST /auth/refresh

### 3\. 👥 User APIs (Admin only)

#### Create User

&#x09;POST /users

#### Get Users

&#x09;GET /users

### 4\. 👤 Vendor APIs

#### Create Vendor

&#x09;POST /vendors

#### Request

&#x09;{

&#x20; 	  "name": "Ramesh",

&#x20; 	  "phone": "9999999999"

&#x09;}

#### Get All Vendors

&#x09;GET /vendors

#### Get Vendor Details

&#x09;GET /vendors/:id

#### Response

&#x09;{

&#x09;  "id": "uuid",

&#x09;  "name": "Ramesh",

&#x09;  "balance": 1200

&#x09;}

#### Vendor Summary (Important)

&#x09;GET /vendors/:id/summary

##### Includes:

* total sessions
* total sold
* outstanding balance

### 5\. 🌱 Category APIs

#### Create Category

&#x09;POST /categories

#### Get Categories

&#x09;GET /categories

### 6\. 🌿 Plant APIs

#### Create Plant

&#x09;POST /plants

#### Request

&#x09;{

&#x09;  "name": "Rose",

&#x09;  "categoryId": "uuid",

&#x09;  "vendorPrice": 20,

&#x09;  "retailPrice": 30

&#x09;}

#### Get Plants (with pagination)

&#x09;GET /plants?page=1\&limit=10

#### Get Plant by ID

&#x09;GET /plants/:id

### 7\. 🔁 SESSION APIs (CORE)

#### Start Session

&#x09;POST /sessions/start

#### Request

&#x09;{

&#x09;  "vendorId": "uuid"

&#x09;}

#### Logic

##### Check if active session exists

* If yes → return existing
* Else → create new

#### Get Active Session

&#x09;GET /sessions/active/:vendorId

#### Get Session Details

&#x09;GET /sessions/:id

#### Issue Plants

&#x09;POST /sessions/:id/issue

#### Request

&#x09;{

&#x09;  "items": \[

&#x09;    { "plantId": "uuid", "quantity": 10 },

&#x09;    { "plantId": "uuid2", "quantity": 5 }

&#x09;  ]

&#x09;}

#### Return Plants

&#x09;POST /sessions/:id/return

#### Request

&#x09;{

&#x09;  "items": \[

&#x09;    { "plantId": "uuid", "quantity": 3, "condition": "GOOD" }

&#x09;  ]

&#x09;}

##### Validation

* Cannot return more than issued

#### Get Session Summary (VERY IMPORTANT)

&#x09;GET /sessions/:id/summary

#### Response

&#x09;{

&#x09;  "issued": \[

&#x09;    { "plant": "Rose", "quantity": 20 }

&#x09;  ],

&#x09;  "returned": \[

&#x09;    { "plant": "Rose", "quantity": 5 }

&#x09;  ],

&#x09;  "sold": \[

&#x09;    { "plant": "Rose", "quantity": 15 }

&#x09;  ],

&#x09;  "totalBill": 300

&#x09;}

#### Close Session (Billing Trigger)

&#x09;POST /sessions/:id/close

##### Logic

* Calculate sold
* Generate bill
* Mark session CLOSED

### 8\. 💰 Payment APIs

#### Add Payment

&#x09;POST /payments

#### Request

&#x09;{

&#x09;  "vendorId": "uuid",

&#x09;  "sessionId": "uuid",

&#x09;  "amount": 200,

&#x09;  "mode": "UPI"

&#x09;}

#### Get Vendor Payments

&#x09;GET /payments/vendor/:vendorId

#### Get Session Payments

&#x09;GET /payments/session/:sessionId

### 9\. 📊 Analytics APIs

#### Monthly Sales

&#x09;GET /analytics/monthly-sales

#### Top Plants

&#x09;GET /analytics/top-plants

#### Vendor Performance

&#x09;GET /analytics/vendors

### 10\. 📦 Response Format (Standardize this)

##### Always return:

&#x09;{

&#x09;  "success": true,

&#x09;  "data": {},

&#x09;  "message": "optional"

&#x09;}

### 11\. ❌ Error Format

&#x09;{

&#x09;  "success": false,

&#x09;  "error": "Invalid return quantity"

&#x09;}

### 12\. 🔐 Auth Middleware

##### Protected routes require:

&#x09;Authorization: Bearer <token>

### 13\. ⚠️ Important Backend Rules

* Only 1 Active Session per Vendor
* Return ≤ Issued
* Cannot Modify Closed Session
* Payment Updates Vendor Balance



