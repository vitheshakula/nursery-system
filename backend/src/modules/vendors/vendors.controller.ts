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
import { CreateVendorDto } from './dto/create-vendor.dto';
import { QueryVendorsDto } from './dto/query-vendors.dto';
import { UpdateVendorDto } from './dto/update-vendor.dto';
import { VendorsService } from './vendors.service';

@ApiTags('Vendors')
@ApiBearerAuth()
@Controller('vendors')
export class VendorsController {
  constructor(private readonly vendors: VendorsService) {}

  @Post()
  @Roles(Role.ADMIN, Role.STAFF)
  @ApiOperation({ summary: 'Create a vendor' })
  create(@Body() dto: CreateVendorDto, @CurrentUser('id') actorId: string) {
    return this.vendors.create(dto, actorId);
  }

  @Get()
  @Roles(Role.ADMIN, Role.STAFF)
  @ApiOperation({ summary: 'List / search vendors (paginated)' })
  findAll(@Query() query: QueryVendorsDto) {
    return this.vendors.findAll(query);
  }

  @Get(':id')
  @Roles(Role.ADMIN, Role.STAFF)
  @ApiOperation({ summary: 'Get a vendor' })
  findOne(@Param('id', ParseUUIDPipe) id: string) {
    return this.vendors.findOne(id);
  }

  @Get(':id/history')
  @Roles(Role.ADMIN, Role.STAFF)
  @ApiOperation({ summary: 'Vendor overview: balance + recent activity' })
  history(@Param('id', ParseUUIDPipe) id: string) {
    return this.vendors.getHistory(id);
  }

  @Patch(':id')
  @Roles(Role.ADMIN, Role.STAFF)
  @ApiOperation({ summary: 'Update vendor details' })
  update(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdateVendorDto,
    @CurrentUser('id') actorId: string,
  ) {
    return this.vendors.update(id, dto, actorId);
  }

  @Patch(':id/activate')
  @Roles(Role.ADMIN)
  @ApiOperation({ summary: 'Reactivate a vendor' })
  activate(@Param('id', ParseUUIDPipe) id: string, @CurrentUser('id') actorId: string) {
    return this.vendors.setActive(id, true, actorId);
  }

  @Patch(':id/deactivate')
  @Roles(Role.ADMIN)
  @ApiOperation({ summary: 'Deactivate a vendor' })
  deactivate(@Param('id', ParseUUIDPipe) id: string, @CurrentUser('id') actorId: string) {
    return this.vendors.setActive(id, false, actorId);
  }
}
