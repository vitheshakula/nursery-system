import { Body, Controller, Get, Param, Post, UseGuards } from '@nestjs/common';
import { Role } from '@prisma/client';
import { SessionsService } from './sessions.service';
import { StartSessionDto } from './dto/start-session.dto';
import { IssueItemsDto } from './dto/issue-items.dto';
import { ReturnItemsDto } from './dto/return-items.dto';
import { Roles } from '../auth/decorators/roles.decorator';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';

@Controller('sessions')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(Role.ADMIN, Role.STAFF)
export class SessionsController {
  constructor(private readonly sessionsService: SessionsService) {}

  @Post('start')
  async start(@Body() dto: StartSessionDto) {
    return this.sessionsService.startSession(dto);
  }

  @Post(':id/issue')
  async issue(@Param('id') id: string, @Body() dto: IssueItemsDto) {
    return this.sessionsService.issueItems(id, dto);
  }

  @Post(':id/return')
  async return(@Param('id') id: string, @Body() dto: ReturnItemsDto) {
    return this.sessionsService.returnItems(id, dto);
  }

  @Get(':id/summary')
  async summary(@Param('id') id: string) {
    return this.sessionsService.getSessionSummary(id);
  }

  @Post(':id/close')
  async close(@Param('id') id: string) {
    return this.sessionsService.closeSession(id);
  }
}
