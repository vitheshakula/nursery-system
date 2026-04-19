# \# 🗄️ Database Design  

# \## Nursery Vendor Inventory \& Settlement System



# \---



### \# 1. 🧠 Design Philosophy



The system is designed around a \*\*Session-based model\*\*:



\- One active session per vendor

\- All issue and return actions are tied to a session

\- Billing is calculated when the session is closed

\- Payments are tracked independently



# \---



### \# 2. 🧩 Core Entities



\- User (multi-login system)

\- Vendor

\- Plant

\- Category

\- Session

\- IssueItem

\- ReturnItem

\- Payment



# \---



### \# 3. 📦 Prisma Schema



# \---



#### \## 🔐 User



```prisma

model User {

&#x20; id        String   @id @default(uuid())

&#x20; name      String

&#x20; email     String   @unique

&#x20; password  String

&#x20; role      Role

&#x20; createdAt DateTime @default(now())

}





#### 👤 Vendor



model Vendor {

&#x20; id        String   @id @default(uuid())

&#x20; name      String

&#x20; phone     String

&#x20; balance   Float    @default(0)

&#x20; createdAt DateTime @default(now())



&#x20; sessions  Session\[]

&#x20; payments  Payment\[]

}



#### 🌱 Category



model Category {

&#x20; id     String  @id @default(uuid())

&#x20; name   String  @unique



&#x20; plants Plant\[]

}





#### 🌿 Plant



model Plant {

&#x20; id           String   @id @default(uuid())

&#x20; name         String

&#x20; categoryId   String

&#x20; vendorPrice  Float

&#x20; retailPrice  Float?

&#x20; createdAt    DateTime @default(now())



&#x20; category Category @relation(fields: \[categoryId], references: \[id])



&#x20; issueItems  IssueItem\[]

&#x20; returnItems ReturnItem\[]

}







# \---







### 4\. 🔁 Session (Core Model)





model Session {

&#x20; id        String   @id @default(uuid())

&#x20; vendorId  String

&#x20; status    SessionStatus @default(ACTIVE)

&#x20; createdAt DateTime @default(now())

&#x20; closedAt  DateTime?



&#x20; vendor Vendor @relation(fields: \[vendorId], references: \[id])



&#x20; issueItems  IssueItem\[]

&#x20; returnItems ReturnItem\[]

&#x20; payments    Payment\[]

}





# 5\. 📤 Issue Items





model IssueItem {

&#x20; id        String   @id @default(uuid())

&#x20; sessionId String

&#x20; plantId   String

&#x20; quantity  Int

&#x20; createdAt DateTime @default(now())



&#x20; session Session @relation(fields: \[sessionId], references: \[id])

&#x20; plant   Plant   @relation(fields: \[plantId], references: \[id])

}





### 6\. 📥 Return Items





model ReturnItem {

&#x20; id        String   @id @default(uuid())

&#x20; sessionId String

&#x20; plantId   String

&#x20; quantity  Int

&#x20; condition PlantCondition

&#x20; createdAt DateTime @default(now())



&#x20; session Session @relation(fields: \[sessionId], references: \[id])

&#x20; plant   Plant   @relation(fields: \[plantId], references: \[id])

}





### 7\. 💰 Payments





model Payment {

&#x20; id        String   @id @default(uuid())

&#x20; vendorId  String

&#x20; sessionId String?

&#x20; amount    Float

&#x20; mode      PaymentMode

&#x20; createdAt DateTime @default(now())



&#x20; vendor  Vendor  @relation(fields: \[vendorId], references: \[id])

&#x20; session Session? @relation(fields: \[sessionId], references: \[id])

}





### 8\. 🔢 Enums





enum Role {

&#x20; ADMIN

&#x20; STAFF

}



enum SessionStatus {

&#x20; ACTIVE

&#x20; CLOSED

}



enum PaymentMode {

&#x20; CASH

&#x20; UPI

}



enum PlantCondition {

&#x20; GOOD

&#x20; DAMAGED

}





### 9\. 🧠 Derived Calculations (Handled in Backend)





sold = total\_issued - total\_returned

bill = sold × vendor\_price





### 10\. ⚠️ Constraints (Backend Enforcement)





* Only one ACTIVE session per vendor
* Return quantity ≤ issued quantity
* CLOSED sessions cannot be modified
* Payments should not exceed outstanding balance (optional)







### 11\. ⚙️ Indexing





@@index(\[vendorId])

@@index(\[sessionId])

@@index(\[plantId])







### 12\. 🔥 Design Strengths





* Flexible multi-day sessions
* Supports multiple issue/return entries
* Clean separation of billing and payments
* Strong relational integrity
* Extensible for future features







