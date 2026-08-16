import { Injectable } from '@nestjs/common';
import { Prisma, Vendor } from '@prisma/client';
import { PrismaService } from '../../config/prisma.service';
import { Paginated, paginate } from '../../common/dto/paginated';
import { DomainError } from '../../common/errors/domain-error';
import { AuditService } from '../audit/audit.service';
import { NumberingService } from '../numbering/numbering.service';
import { CreateVendorDto } from './dto/create-vendor.dto';
import { QueryVendorsDto } from './dto/query-vendors.dto';
import { UpdateVendorDto } from './dto/update-vendor.dto';

@Injectable()
export class VendorsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly numbering: NumberingService,
    private readonly audit: AuditService,
  ) {}

  async create(dto: CreateVendorDto, actorId: string): Promise<Vendor> {
    const opening = new Prisma.Decimal(dto.openingBalance ?? 0);

    const vendor = await this.prisma.$transaction(async (tx) => {
      const vendorCode = await this.numbering.next(tx, 'VEN');
      return tx.vendor.create({
        data: {
          vendorCode,
          name: dto.name,
          phone: dto.phone,
          address: dto.address,
          notes: dto.notes,
          openingBalance: opening,
          currentBalance: opening, // ledger entries accumulate on top of this
        },
      });
    });

    await this.audit.record({
      userId: actorId,
      action: 'CREATE',
      module: 'VENDOR',
      entityType: 'Vendor',
      entityId: vendor.id,
      metadata: { vendorCode: vendor.vendorCode, openingBalance: dto.openingBalance ?? 0 },
    });
    return vendor;
  }

  async findAll(query: QueryVendorsDto): Promise<Paginated<Vendor>> {
    const where: Prisma.VendorWhereInput = {
      ...(query.active !== undefined ? { active: query.active } : {}),
      ...(query.withBalance ? { currentBalance: { not: 0 } } : {}),
      ...(query.search
        ? {
            OR: [
              { name: { contains: query.search, mode: 'insensitive' } },
              { phone: { contains: query.search, mode: 'insensitive' } },
              { vendorCode: { contains: query.search, mode: 'insensitive' } },
            ],
          }
        : {}),
    };

    const [items, total] = await this.prisma.$transaction([
      this.prisma.vendor.findMany({
        where,
        orderBy: { [query.sortBy ?? 'createdAt']: query.sortOrder },
        skip: query.skip,
        take: query.limit,
      }),
      this.prisma.vendor.count({ where }),
    ]);
    return paginate(items, total, query.page, query.limit);
  }

  async findOne(id: string): Promise<Vendor> {
    const vendor = await this.prisma.vendor.findUnique({ where: { id } });
    if (!vendor) throw DomainError.notFound('Vendor', id);
    return vendor;
  }

  async update(id: string, dto: UpdateVendorDto, actorId: string): Promise<Vendor> {
    await this.findOne(id);
    const vendor = await this.prisma.vendor.update({ where: { id }, data: dto });
    await this.audit.record({
      userId: actorId,
      action: 'UPDATE',
      module: 'VENDOR',
      entityType: 'Vendor',
      entityId: id,
      metadata: { ...dto },
    });
    return vendor;
  }

  async setActive(id: string, active: boolean, actorId: string): Promise<Vendor> {
    await this.findOne(id);
    const vendor = await this.prisma.vendor.update({ where: { id }, data: { active } });
    await this.audit.record({
      userId: actorId,
      action: active ? 'ACTIVATE' : 'DEACTIVATE',
      module: 'VENDOR',
      entityType: 'Vendor',
      entityId: id,
    });
    return vendor;
  }

  /** Vendor overview: balance + recent issues, settlements and payments. */
  async getHistory(id: string) {
    const vendor = await this.findOne(id);
    const [issues, settlements, payments] = await Promise.all([
      this.prisma.issueTransaction.findMany({
        where: { vendorId: id },
        orderBy: { issuedAt: 'desc' },
        take: 20,
        include: { _count: { select: { items: true, returns: true } } },
      }),
      this.prisma.settlement.findMany({
        where: { vendorId: id },
        orderBy: { createdAt: 'desc' },
        take: 20,
      }),
      this.prisma.payment.findMany({
        where: { vendorId: id },
        orderBy: { paidAt: 'desc' },
        take: 20,
      }),
    ]);
    return { vendor, issues, settlements, payments };
  }
}
