import { Body, Controller, Get, Param, ParseUUIDPipe, Post, Query } from '@nestjs/common';
import { ApiBearerAuth, ApiHeader, ApiOperation, ApiTags } from '@nestjs/swagger';
import { Role } from '@prisma/client';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { IdempotencyKey } from '../../common/decorators/idempotency-key.decorator';
import { Roles } from '../../common/decorators/roles.decorator';
import { CreateIssueDto } from './dto/create-issue.dto';
import { QueryIssuesDto } from './dto/query-issues.dto';
import { IssueService } from './issue.service';

@ApiTags('Issue')
@ApiBearerAuth()
@Controller('issues')
export class IssueController {
  constructor(private readonly issue: IssueService) {}

  @Post()
  @Roles(Role.ADMIN, Role.STAFF)
  @ApiHeader({ name: 'Idempotency-Key', required: false, description: 'Dedupes retried submissions' })
  @ApiOperation({ summary: 'Issue inventory to a vendor (morning operation)' })
  create(
    @Body() dto: CreateIssueDto,
    @CurrentUser('id') staffId: string,
    @IdempotencyKey() key?: string,
  ) {
    return this.issue.create(dto, staffId, key);
  }

  @Get()
  @Roles(Role.ADMIN, Role.STAFF)
  @ApiOperation({ summary: 'List issue transactions (paginated, filter by vendor/status)' })
  findAll(@Query() query: QueryIssuesDto) {
    return this.issue.findAll(query);
  }

  @Get(':id')
  @Roles(Role.ADMIN, Role.STAFF)
  @ApiOperation({ summary: 'Get an issue transaction with returns & settlement' })
  findOne(@Param('id', ParseUUIDPipe) id: string) {
    return this.issue.findOne(id);
  }
}
