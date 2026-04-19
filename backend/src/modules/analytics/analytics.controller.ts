import { Controller, Get, UseGuards } from '@nestjs/common';
import { Role } from '@prisma/client';
import { AnalyticsService } from './analytics.service';
import { Roles } from '../auth/decorators/roles.decorator';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';

@Controller('analytics')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(Role.ADMIN)
export class AnalyticsController {
  constructor(private readonly analyticsService: AnalyticsService) {}

  @Get('monthly-sales')
  async getMonthlySales() {
    return this.analyticsService.getMonthlySales();
  }

  @Get('dashboard')
  async getDashboard() {
    return this.analyticsService.getDashboardSummary();
  }

  @Get('top-plants')
  async getTopPlants() {
    return this.analyticsService.getTopPlants();
  }

  @Get('vendors')
  async getVendorPerformance() {
    return this.analyticsService.getVendorPerformance();
  }
}
