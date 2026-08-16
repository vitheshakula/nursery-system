import { Body, Controller, Get, Param, ParseUUIDPipe, Post, Query } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { Role } from '@prisma/client';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { Roles } from '../../common/decorators/roles.decorator';
import { PaginationQueryDto } from '../../common/dto/pagination-query.dto';
import { AdjustLedgerDto } from './dto/adjust-ledger.dto';
import { LedgerService } from './ledger.service';

@ApiTags('Ledger')
@ApiBearerAuth()
@Controller('ledger')
export class LedgerController {
  constructor(private readonly ledger: LedgerService) {}

  @Get('vendors/:vendorId')
  @Roles(Role.ADMIN, Role.STAFF)
  @ApiOperation({ summary: "Vendor ledger statement (bank-statement view)" })
  getStatement(
    @Param('vendorId', ParseUUIDPipe) vendorId: string,
    @Query() query: PaginationQueryDto,
  ) {
    return this.ledger.getStatement(vendorId, query);
  }

  @Post('adjustments')
  @Roles(Role.ADMIN)
  @ApiOperation({ summary: 'Manual balance adjustment (admin only, audited)' })
  adjust(@Body() dto: AdjustLedgerDto, @CurrentUser('id') actorId: string) {
    return this.ledger.adjust(dto, actorId);
  }
}
