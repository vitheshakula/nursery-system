import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../config/prisma.service';
import { CreateVendorDto } from './dto/create-vendor.dto';
import { Vendor } from '@prisma/client';

@Injectable()
export class VendorService {
  constructor(private readonly prisma: PrismaService) {}

  async create(createVendorDto: CreateVendorDto): Promise<Vendor> {
    return this.prisma.vendor.create({
      data: createVendorDto,
    });
  }

  async findAll(): Promise<Vendor[]> {
    return this.prisma.vendor.findMany({
      orderBy: { createdAt: 'desc' },
    });
  }

  async findOne(id: string): Promise<Vendor> {
    const vendor = await this.prisma.vendor.findUnique({
      where: { id },
    });

    if (!vendor) {
      throw new NotFoundException(`Vendor with id ${id} not found`);
    }

    return vendor;
  }
}
