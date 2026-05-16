import {
  Body,
  Controller,
  DefaultValuePipe,
  Get,
  Param,
  Patch,
  ParseIntPipe,
  Post,
  Query,
} from '@nestjs/common';
import { CreatePlantDto } from './dto/create-plant.dto';
import { AdjustStockDto } from './dto/adjust-stock.dto';
import { PlantsService } from './plants.service';

@Controller('plants')
export class PlantsController {
  constructor(private readonly plantsService: PlantsService) {}

  @Post()
  async create(@Body() createPlantDto: CreatePlantDto) {
    return this.plantsService.create(createPlantDto);
  }

  @Get()
  async findAll(
    @Query('page', new DefaultValuePipe(1), ParseIntPipe) page: number,
    @Query('limit', new DefaultValuePipe(10), ParseIntPipe) limit: number,
  ) {
    return this.plantsService.findAll(page, limit);
  }

  @Get('stock/summary')
  async getStockSummary() {
    return this.plantsService.getStockSummary();
  }

  @Get('stock/low')
  async getLowStockItems(
    @Query('threshold', new DefaultValuePipe(5), ParseIntPipe) threshold: number,
  ) {
    return this.plantsService.getLowStockItems(threshold);
  }

  @Get('movements/history')
  async getMovementHistory(
    @Query('itemId') itemId?: string,
    @Query('limit', new DefaultValuePipe(100), ParseIntPipe) limit?: number,
  ) {
    return this.plantsService.getMovementHistory(itemId, limit);
  }

  @Get('movements/daily-flow')
  async getDailyInventoryFlow() {
    return this.plantsService.getDailyInventoryFlow();
  }

  @Get(':id')
  async findOne(@Param('id') id: string) {
    return this.plantsService.findOne(id);
  }

  @Patch(':id/stock-adjustment')
  async adjustStock(@Param('id') id: string, @Body() dto: AdjustStockDto) {
    return this.plantsService.adjustStock(id, dto);
  }
}
