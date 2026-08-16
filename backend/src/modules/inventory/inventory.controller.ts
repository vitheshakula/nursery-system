import {
  Body,
  Controller,
  Get,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
  Query,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { Role } from '@prisma/client';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { Roles } from '../../common/decorators/roles.decorator';
import { PaginationQueryDto } from '../../common/dto/pagination-query.dto';
import { AdjustStockDto } from './dto/adjust-stock.dto';
import { CreateItemDto } from './dto/create-item.dto';
import { QueryItemsDto } from './dto/query-items.dto';
import { UpdateItemDto } from './dto/update-item.dto';
import { InventoryService } from './inventory.service';

@ApiTags('Inventory')
@ApiBearerAuth()
@Controller('inventory/items')
export class InventoryController {
  constructor(private readonly inventory: InventoryService) {}

  @Post()
  @Roles(Role.ADMIN)
  @ApiOperation({ summary: 'Create an inventory item (optionally with opening stock)' })
  create(@Body() dto: CreateItemDto, @CurrentUser('id') actorId: string) {
    return this.inventory.createItem(dto, actorId);
  }

  @Get()
  @Roles(Role.ADMIN, Role.STAFF)
  @ApiOperation({ summary: 'List / search items (paginated, filter by category/active/lowStock)' })
  findAll(@Query() query: QueryItemsDto) {
    return this.inventory.findAll(query);
  }

  @Get(':id')
  @Roles(Role.ADMIN, Role.STAFF)
  @ApiOperation({ summary: 'Get an item with stock' })
  findOne(@Param('id', ParseUUIDPipe) id: string) {
    return this.inventory.findOne(id);
  }

  @Get(':id/movements')
  @Roles(Role.ADMIN, Role.STAFF)
  @ApiOperation({ summary: 'Stock movement history for an item' })
  movements(@Param('id', ParseUUIDPipe) id: string, @Query() query: PaginationQueryDto) {
    return this.inventory.getMovements(id, query);
  }

  @Patch(':id')
  @Roles(Role.ADMIN)
  @ApiOperation({ summary: 'Update item details (not stock)' })
  update(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdateItemDto,
    @CurrentUser('id') actorId: string,
  ) {
    return this.inventory.update(id, dto, actorId);
  }

  @Post(':id/stock-adjustments')
  @Roles(Role.ADMIN)
  @ApiOperation({ summary: 'Adjust stock (restock / wastage / count correction)' })
  adjustStock(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: AdjustStockDto,
    @CurrentUser('id') actorId: string,
  ) {
    return this.inventory.adjustStock(id, dto, actorId);
  }
}
