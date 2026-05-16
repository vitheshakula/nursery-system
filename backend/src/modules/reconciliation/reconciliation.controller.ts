import { Controller, DefaultValuePipe, Get, ParseIntPipe, Query, UseGuards } from '@nestjs/common';
import { Role } from '@prisma/client';
import { Roles } from '../auth/decorators/roles.decorator';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { ReconciliationService } from './reconciliation.service';

@Controller('reconciliation')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(Role.ADMIN)
export class ReconciliationController {
  constructor(private readonly reconciliationService: ReconciliationService) {}

  @Get('summary')
  async getSummary() {
    return this.reconciliationService.getSummary();
  }

  @Get('stock')
  async getStockReconciliation() {
    return this.reconciliationService.getStockReconciliation();
  }

  @Get('balances')
  async getBalanceReconciliation() {
    return this.reconciliationService.getBalanceReconciliation();
  }

  @Get('adjustments')
  async getAdjustmentHistory(
    @Query('limit', new DefaultValuePipe(100), ParseIntPipe) limit: number,
  ) {
    return this.reconciliationService.getAdjustmentHistory(limit);
  }
}
