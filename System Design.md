# 🏗️ System Design

# Nursery Vendor Inventory \& Settlement System

## 1\. 🎯 System Goal (Anchor This in Your Mind)



Build a reliable backend system to handle vendor sessions, inventory movement, billing, and payments with real-world flexibility (multi-issue, delayed returns, partial payments).



## 2\. 🧱 High-Level Architecture

#### &#x20;         Flutter App (Client)

#### &#x20;                 ↓

#### &#x20;         NestJS Backend (API Layer)

#### &#x20;                 ↓

#### &#x20;         PostgreSQL (Neon DB)

##### Responsibilities

###### 📱 Client (Flutter)

* UI
* Local state (optional offline)
* API calls

###### ⚙️ Backend (NestJS)

Business logic

* Validation
* Session management
* Billing \& payment handling

###### 🗄️ Database (PostgreSQL)

* Persistent storage
* Relationships
* Transactions

## 3\. 🧩 Core System Components

#### 3.1 Authentication Service

* JWT-based auth
* Role-based access (Admin / Staff)

#### 3.2 Vendor Service

* Vendor CRUD
* Balance tracking
* History retrieval

#### 3.3 Plant \& Category Service

* Manage plants
* Categorization
* Pricing

#### 3.4 Session Service (CORE ENGINE)



##### This is your system’s heart.



###### Responsibilities:

* Create session
* Add issued items
* Add returned items
* Maintain session state (ACTIVE / CLOSED)

#### 3.5 Billing Service

###### Calculate:

* total issued
* total returned
* sold quantity
* Generate bill

#### 3.6 Payment Service

###### Record:

* amount
* mode (UPI / Cash)
* Handle partial payments
* Update vendor balance

#### 3.7 Analytics Service

* Monthly trends
* Category insights
* Vendor performance

### 4\. 🔁 Core Data Flow (Most Important Part)

##### Flow 1: Start Session

Client → POST /sessions/start

&#x20;      → Backend creates session (ACTIVE)

##### Flow 2: Issue Plants

Client → POST /sessions/:id/issue

&#x20;      → Add issued items

&#x20;      → Update session totals

##### Flow 3: Return Plants

Client → POST /sessions/:id/return

&#x20;      → Add return items

&#x20;      → Validate (return ≤ issued)

##### Flow 4: Close Session (Billing)

###### Client → POST /sessions/:id/close



##### Backend:

* &#x20;Calculate sold = issued - returned
* &#x20;Generate bill
* &#x20;Mark session CLOSED

##### Flow 5: Payment

###### Client → POST /payments



###### Backend:

\- Record payment

\- Update vendor balance

### 5\. 🧠 Core Design Decisions (This is what matters in interviews)

#### ✅ 1. Session-Based Model



##### Why:



* Vendors operate continuously
* Not fixed to a single transaction



##### 👉 You designed:



* “One active session per vendor”



#### ✅ 2. Flexible Return Handling



##### Why:



* Returns can happen later



##### 👉 Solution:



* Allow returns anytime before session close

#### ✅ 3. Separation of Issue \& Return



##### Why:



* Clear tracking
* Avoid calculation errors

#### ✅ 4. Billing at Session Closure



##### Why:



* Avoid premature calculations
* Reflect real-world workflow

#### ✅ 5. Payment Decoupled from Billing



##### Why:



* Vendors may pay later or partially

### 6\. 🗄️ Data Modeling Strategy (Conceptual)

* Entities
* Vendor
* User
* Plant
* Category
* Session
* IssueItem
* ReturnItem
* Payment
* Key Relationships
* Vendor → Sessions (1:N)
* Session → IssueItems (1:N)
* Session → ReturnItems (1:N)
* Vendor → Payments (1:N)
* Plant → Category (N:1)

### 7\. ⚙️ Important Backend Patterns

#### 1\. Layered Architecture

* Controller → Service → Repository (Prisma)

#### 2\. DTO Validation

* Ensure clean inputs
* Prevent bad data

#### 3\. Transactions (VERY IMPORTANT)



##### Used when:



* Closing session
* Generating bill
* Updating balance



##### Example concept:



###### BEGIN TRANSACTION

* &#x20;calculate bill
* &#x20;update session
* &#x20;update vendor balance
* &#x20;COMMIT

#### 4\. Idempotency (Basic)



##### Prevent:



* Duplicate API calls
* Double entries

### 8\. ⚠️ Edge Case Handling (You MUST mention these)

#### Case 1:



Return > Issued

→ Reject request



#### Case 2:



Multiple issue entries

→ Aggregate properly



#### Case 3:



Session left open for days

→ Still valid



#### Case 4:



Partial payments

→ Track remaining balance



#### Case 5:



Duplicate entries

→ Prevent via validation



### 9\. 📊 Analytics Design

* Data Source
* Transactions (issue + return)
* Sessions
* Computation
* Aggregated queries:
* SUM(sold)
* GROUP BY month/category
* Output
* Monthly reports
* Top plants
* Vendor performance

### 10\. 🚀 Scalability (Simple but Smart)



You don’t need heavy scaling, but:



* Add later if needed:
* Caching (Redis)
* Plant list
* Vendor data
* Indexing (PostgreSQL)
* vendor\_id
* session\_id
* date



👉 This alone shows system awareness



### 11\. 🔐 Security

* JWT auth
* Role-based access
* Input validation

### 12\. 🧪 Testing Strategy

* Basic Testing
* API testing (Postman)
* Important Scenarios
* Multiple issue + return
* Late returns
* Partial payments
* Session closing

## 13\. 📦 Deployment Design

* Backend
* Render
* Auto deploy from GitHub
* DB
* Neon PostgreSQL
* Env Config
* DATABASE\_URL
* JWT\_SECRET

