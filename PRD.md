# 📘 PRD

# Nursery Vendor Inventory \& Settlement System

### 1\. 🎯 Product Overview



A mobile-first system to digitize and manage daily vendor plant transactions, including:



* Plant issuance (morning and throughout the day)
* Returns (same day or next day)
* Billing based on actual sales
* Vendor credit and payment tracking
* Business insights through analytics

### 2\. 🧠 Problem Statement



Currently:



* Transactions are tracked manually
* Errors in counting and billing are possible
* No centralized data storage
* No historical insights (sales, trends, vendor performance)
* Hard to track partial payments and balances

### 3\. 🎯 Goals

#### Primary Goals

* Digitize vendor transaction workflow
* Ensure accurate billing
* Track vendor balances (credit system)
* Maintain reliable data in cloud

#### Secondary Goals

* Provide analytics (monthly trends, plant demand)
* Track plant quality issues
* Enable multi-user usage (farm + nursery)

### 4\. 👥 User Roles

#### Admin

* Full access
* Manage plants, vendors, sessions, billing, analytics

#### Staff

* Create/update sessions
* Record returns
* Cannot modify critical configurations

### 5\. 🔁 Core Workflow (VERY IMPORTANT)

#### Step 1: Start Session

* A session begins when vendor first takes plants
* One session per vendor (active until billing)

#### Step 2: Issue Plants (Multiple times)

Vendor can:

* Take plants multiple times in a day
* Even after partial returns



👉 All actions are recorded under the same session



#### Step 3: Return Plants

Can happen:

* Same day
* Next day
* Partial returns allowed

#### Step 4: Close Session (Billing Trigger)



When admin decides:

* Session is closed

System calculates:

* Total Issued - Total Returned = Sold
* Bill = Sold × Vendor Price

#### Step 5: Payment Handling



##### After billing:

###### Admin records:

* Full payment OR
* Partial payment

##### Payment modes:

* UPI
* Cash
* Remaining balance is stored

### 6\. 🧩 Functional Requirements

#### 6.1 Authentication

* Login system (Admin / Staff)
* JWT-based authentication
* Role-based access control

#### 6.2 Vendor Management

##### Add/edit vendor

##### Track:

* Current balance
* Transaction history

#### 6.3 Plant Management

##### Add/edit plants

##### Assign:

* Category
* Vendor price
* Retail price (optional)

#### 6.4 Category Management

* Define plant categories (flowers, indoor, etc.)

#### 6.5 Session Management (CORE)

* Session Rules
* One active session per vendor
* Session remains open until billing
* Supports:
* Multiple issues
* Multiple returns
* Cross-day lifecycle
* Actions
* Start session
* Add issued plants
* Add returned plants
* View session summary
* Close session

#### 6.6 Billing System

* Auto-calculate:
* Sold quantity
* Total bill
* Generate session invoice

#### 6.7 Payment System

##### Record payments:

* Amount
* Mode (UPI / Cash)

##### Support:

* Partial payments
* Update vendor balance

#### 6.8 Analytics

* Business Insights
* Monthly plant sales
* Seasonal trends
* Category-wise demand
* Vendor-wise performance

#### 6.9 Quality Tracking

##### Track plant condition during return:

* Good
* Damaged

##### Use for:

* Quality insights
* Loss analysis

### 7\. ⚙️ Non-Functional Requirements

* Performance
* Fast response for daily operations
* Efficient DB queries
* Reliability
* Data should not be lost
* Cloud storage (Neon DB)
* Consistency
* Accurate billing (no mismatch)
* Use DB transactions
* Scalability (Basic)
* Handle multiple vendors daily
* Not required for large scale
* Offline Capability (Optional Phase)
* Allow temporary offline usage
* Sync when online

### 8\. 📊 Data Requirements



##### System must store:



* Vendors
* Plants
* Categories
* Sessions
* Issued items
* Returned items
* Payments
* Balances

### 9\. 🚫 Out of Scope (Important)



#### To avoid overengineering:



* No ML models (for now)
* No microservices
* No complex recommendation systems
* No vendor-facing app (initial version)

### 10\. 🔐 Assumptions

* Vendor prices are mostly stable
* Vendors are trusted (no fraud system needed)
* Internet is available most of the time

### 11\. ⚠️ Edge Cases



#### You MUST handle:



* Return quantity > issued (invalid)
* Multiple issues before return
* Returns after 1+ day
* Partial payments
* Duplicate entries
* Session not closed properly

### 12\. 📈 Success Metrics

* Reduced manual errors
* Faster billing process
* Accurate vendor balance tracking
* Ability to generate reports

### 13\. 🧠 Key Design Decisions

* Session-based model instead of daily logs
* One active session per vendor
* Flexible return handling (multi-day)
* Integrated billing + payment tracking



