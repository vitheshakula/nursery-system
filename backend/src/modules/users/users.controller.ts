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
import { CreateUserDto } from './dto/create-user.dto';
import { QueryUsersDto } from './dto/query-users.dto';
import { UpdateUserDto } from './dto/update-user.dto';
import { UsersService } from './users.service';

@ApiTags('Users / Staff')
@ApiBearerAuth()
@Roles(Role.ADMIN) // entire controller is admin-only
@Controller('users')
export class UsersController {
  constructor(private readonly users: UsersService) {}

  @Post()
  @ApiOperation({ summary: 'Create a staff or admin user' })
  create(@Body() dto: CreateUserDto, @CurrentUser('id') actorId: string) {
    return this.users.create(dto, actorId);
  }

  @Get()
  @ApiOperation({ summary: 'List / search users (paginated, filter by role & active)' })
  findAll(@Query() query: QueryUsersDto) {
    return this.users.findAll(query);
  }

  @Get(':id')
  @ApiOperation({ summary: 'Get a user' })
  findOne(@Param('id', ParseUUIDPipe) id: string) {
    return this.users.findOne(id);
  }

  @Patch(':id')
  @ApiOperation({ summary: 'Update a user' })
  update(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdateUserDto,
    @CurrentUser('id') actorId: string,
  ) {
    return this.users.update(id, dto, actorId);
  }

  @Patch(':id/activate')
  @ApiOperation({ summary: 'Reactivate a user' })
  activate(@Param('id', ParseUUIDPipe) id: string, @CurrentUser('id') actorId: string) {
    return this.users.setActive(id, true, actorId);
  }

  @Patch(':id/deactivate')
  @ApiOperation({ summary: 'Deactivate a user (revokes their sessions)' })
  deactivate(@Param('id', ParseUUIDPipe) id: string, @CurrentUser('id') actorId: string) {
    return this.users.setActive(id, false, actorId);
  }
}
