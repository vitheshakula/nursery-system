import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../config/prisma.service';
import { CreateVendorDto } from './dto/create-vendor.dto';
import { UpdateVendorDto } from './dto/update-vendor.dto';
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

  async update(id: string, updateVendorDto: UpdateVendorDto): Promise<Vendor> {
    await this.findOne(id);

    return this.prisma.vendor.update({
      where: { id },
      data: updateVendorDto,
    });
  }

  async remove(id: string) {
    const vendor = await this.findOne(id);

    const [sessionCount, paymentCount] = await this.prisma.$transaction([
      this.prisma.session.count({ where: { vendorId: id } }),
      this.prisma.payment.count({ where: { vendorId: id } }),
    ]);

    if (sessionCount > 0 || paymentCount > 0) {
      throw new BadRequestException('Vendor with session or payment history cannot be deleted');
    }

    await this.prisma.vendor.delete({
      where: { id },
    });

    return {
      id: vendor.id,
      deleted: true,
    };
  }

  async getSessionHistory(vendorId: string) {
    await this.findOne(vendorId);

    const sessions = await this.prisma.session.findMany({
      where: { vendorId },
      orderBy: { createdAt: 'desc' },
      include: {
        issueItems: {
          include: {
            plant: {
              select: {
                vendorPrice: true,
              },
            },
          },
        },
        returnItems: true,
      },
    });

    return sessions.map((session) => {
      const issuedByPlant = session.issueItems.reduce<
        Record<string, { quantity: number; vendorPrice: number }>
      >((acc, item) => {
        const current = acc[item.plantId] ?? {
          quantity: 0,
          vendorPrice: item.plant.vendorPrice,
        };
        current.quantity += item.quantity;
        acc[item.plantId] = current;
        return acc;
      }, {});

      const returnedByPlant = session.returnItems.reduce<Record<string, number>>((acc, item) => {
        acc[item.plantId] = (acc[item.plantId] ?? 0) + item.quantity;
        return acc;
      }, {});

      const totalIssued = session.issueItems.reduce((sum, item) => sum + item.quantity, 0);
      const totalReturned = session.returnItems.reduce((sum, item) => sum + item.quantity, 0);
      const totalBill = Object.entries(issuedByPlant).reduce((sum, entry) => {
        const plantId = entry[0];
        const issued = entry[1];
        const sold = Math.max(issued.quantity - (returnedByPlant[plantId] ?? 0), 0);
        return sum + sold * issued.vendorPrice;
      }, 0);

      return {
        id: session.id,
        status: session.status,
        createdAt: session.createdAt,
        closedAt: session.closedAt,
        totalIssued,
        totalReturned,
        totalSold: Math.max(totalIssued - totalReturned, 0),
        totalBill,
      };
    });
  }
}
