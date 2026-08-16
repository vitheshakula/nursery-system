import { Body, Controller, Get, Param, ParseUUIDPipe, Post, Query } from '@nestjs/common';
import { ApiBearerAuth, ApiHeader, ApiOperation, ApiTags } from '@nestjs/swagger';
import { Role } from '@prisma/client';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { IdempotencyKey } from '../../common/decorators/idempotency-key.decorator';
import { Roles } from '../../common/decorators/roles.decorator';
import { GenerateSettlementDto } from './dto/generate-settlement.dto';
import { QuerySettlementsDto } from './dto/query-settlements.dto';
import { SettlementService } from './settlement.service';

@ApiTags('Settlement')
@ApiBearerAuth()
@Controller('settlements')
export class SettlementController {
  constructor(private readonly settlements: SettlementService) {}

  @Post('generate')
  @Roles(Role.ADMIN, Role.STAFF)
  @ApiOperation({ summary: 'Generate a DRAFT settlement for an issue cycle' })
  generate(@Body() dto: GenerateSettlementDto, @CurrentUser('id') staffId: string) {
    return this.settlements.generate(dto, staffId);
  }

  @Post(':id/finalize')
  @Roles(Role.ADMIN, Role.STAFF)
  @ApiHeader({ name: 'Idempotency-Key', required: false })
  @ApiOperation({ summary: 'Finalize a settlement — posts ledger debit, becomes immutable' })
  finalize(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser('id') staffId: string,
    @IdempotencyKey() key?: string,
  ) {
    return this.settlements.finalize(id, staffId, key);
  }

  @Get()
  @Roles(Role.ADMIN, Role.STAFF)
  @ApiOperation({ summary: 'List settlements (paginated, filter by vendor/status)' })
  findAll(@Query() query: QuerySettlementsDto) {
    return this.settlements.findAll(query);
  }

  @Get(':id')
  @Roles(Role.ADMIN, Role.STAFF)
  @ApiOperation({ summary: 'Get a settlement with line items' })
  findOne(@Param('id', ParseUUIDPipe) id: string) {
    return this.settlements.findOne(id);
  }
}
