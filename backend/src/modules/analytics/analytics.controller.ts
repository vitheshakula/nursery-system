import { Controller, Get, UseGuards } from '@nestjs/common';
import { Role } from '@prisma/client';
import { AnalyticsService } from './analytics.service';
import { Roles } from '../auth/decorators/roles.decorator';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';

@Controller('analytics')
@UseGuards(JwtAuthGuard, RolesGuard)
export class AnalyticsController {
  constructor(private readonly analyticsService: AnalyticsService) {}

  @Get('monthly-sales')
  @Roles(Role.ADMIN)
  async getMonthlySales() {
    return this.analyticsService.getMonthlySales();
  }

  @Get('dashboard')
  @Roles(Role.ADMIN, Role.STAFF)
  async getDashboard() {
    return this.analyticsService.getDashboardSummary();
  }

  @Get('top-plants')
  @Roles(Role.ADMIN)
  async getTopPlants() {
    return this.analyticsService.getTopPlants();
  }

  @Get('vendors')
  @Roles(Role.ADMIN)
  async getVendorPerformance() {
    return this.analyticsService.getVendorPerformance();
  }
}
