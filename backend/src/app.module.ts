import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { APP_GUARD } from '@nestjs/core';
import { JwtAuthGuard } from './common/guards/jwt-auth.guard';
import { RolesGuard } from './common/guards/roles.guard';
import { IdempotencyModule } from './common/idempotency/idempotency.module';
import { PrismaModule } from './config/prisma.module';
import { AuditModule } from './modules/audit/audit.module';
import { AuthModule } from './modules/auth/auth.module';
import { CategoriesModule } from './modules/categories/categories.module';
import { InventoryModule } from './modules/inventory/inventory.module';
import { IssueModule } from './modules/issue/issue.module';
import { LedgerModule } from './modules/ledger/ledger.module';
import { NumberingModule } from './modules/numbering/numbering.module';
import { PaymentModule } from './modules/payment/payment.module';
import { ReturnModule } from './modules/return/return.module';
import { SettlementModule } from './modules/settlement/settlement.module';
import { UsersModule } from './modules/users/users.module';
import { VendorsModule } from './modules/vendors/vendors.module';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    // Cross-cutting infrastructure (all @Global)
    PrismaModule,
    IdempotencyModule,
    NumberingModule,
    AuditModule,
    LedgerModule,
    // Feature modules
    AuthModule,
    UsersModule,
    VendorsModule,
    CategoriesModule,
    InventoryModule,
    IssueModule,
    ReturnModule,
    SettlementModule,
    PaymentModule,
  ],
  providers: [
    // Global authn then authz. Routes opt out of authn with @Public().
    { provide: APP_GUARD, useClass: JwtAuthGuard },
    { provide: APP_GUARD, useClass: RolesGuard },
  ],
})
export class AppModule {}
