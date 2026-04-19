import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { PrismaModule } from './config/prisma.module';
import { AnalyticsModule } from './modules/analytics/analytics.module';
import { AuthModule } from './modules/auth/auth.module';
import { CategoriesModule } from './modules/categories/categories.module';
import { PaymentsModule } from './modules/payments/payments.module';
import { PlantsModule } from './modules/plants/plants.module';
import { SessionsModule } from './modules/sessions/sessions.module';
import { VendorsModule } from './modules/vendors/vendor.module';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    PrismaModule,
    AnalyticsModule,
    AuthModule,
    VendorsModule,
    CategoriesModule,
    PlantsModule,
    SessionsModule,
    PaymentsModule,
  ],
})
export class AppModule {}
