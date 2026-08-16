import { Body, Controller, Get, Param, ParseUUIDPipe, Post } from '@nestjs/common';
import { ApiBearerAuth, ApiHeader, ApiOperation, ApiTags } from '@nestjs/swagger';
import { Role } from '@prisma/client';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { IdempotencyKey } from '../../common/decorators/idempotency-key.decorator';
import { Roles } from '../../common/decorators/roles.decorator';
import { CreateReturnDto } from './dto/create-return.dto';
import { ReturnService } from './return.service';

@ApiTags('Return')
@ApiBearerAuth()
@Controller('returns')
export class ReturnController {
  constructor(private readonly returns: ReturnService) {}

  @Post()
  @Roles(Role.ADMIN, Role.STAFF)
  @ApiHeader({ name: 'Idempotency-Key', required: false, description: 'Dedupes retried submissions' })
  @ApiOperation({ summary: 'Record returned inventory against an issue (evening operation)' })
  create(
    @Body() dto: CreateReturnDto,
    @CurrentUser('id') staffId: string,
    @IdempotencyKey() key?: string,
  ) {
    return this.returns.create(dto, staffId, key);
  }

  @Get(':id')
  @Roles(Role.ADMIN, Role.STAFF)
  @ApiOperation({ summary: 'Get a return transaction' })
  findOne(@Param('id', ParseUUIDPipe) id: string) {
    return this.returns.findOne(id);
  }
}
