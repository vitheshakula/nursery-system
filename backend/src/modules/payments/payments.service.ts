import { BadRequestException, Injectable, Logger, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../config/prisma.service';
import { CreatePaymentDto } from './dto/create-payment.dto';

@Injectable()
export class PaymentsService {
  private readonly logger = new Logger(PaymentsService.name);

  constructor(private readonly prisma: PrismaService) {}

  async create(createPaymentDto: CreatePaymentDto) {
    const vendor = await this.prisma.vendor.findUnique({
      where: { id: createPaymentDto.vendorId },
    });

    if (!vendor) {
      throw new NotFoundException('Vendor not found');
    }

    let sessionId = createPaymentDto.sessionId;

    if (sessionId) {
      const session = await this.prisma.session.findUnique({
        where: { id: sessionId },
      });

      if (!session) {
        throw new NotFoundException('Session not found');
      }

      if (session.vendorId !== createPaymentDto.vendorId) {
        throw new BadRequestException('Session does not belong to the provided vendor');
      }
    }

    if (createPaymentDto.amount > vendor.balance) {
      throw new BadRequestException('Payment amount exceeds vendor outstanding balance');
    }

    const [payment, updatedVendor] = await this.prisma.$transaction([
      this.prisma.payment.create({
        data: {
          vendorId: createPaymentDto.vendorId,
          sessionId,
          amount: createPaymentDto.amount,
          mode: createPaymentDto.mode,
        },
      }),
      this.prisma.vendor.update({
        where: { id: createPaymentDto.vendorId },
        data: {
          balance: {
            decrement: createPaymentDto.amount,
          },
        },
      }),
    ]);

    this.logger.log(
      `Payment created: paymentId=${payment.id} vendorId=${payment.vendorId} amount=${payment.amount} mode=${payment.mode}`,
    );

    return {
      ...payment,
      vendorBalance: updatedVendor.balance,
    };
  }

  async findByVendor(vendorId: string) {
    const vendor = await this.prisma.vendor.findUnique({
      where: { id: vendorId },
    });

    if (!vendor) {
      throw new NotFoundException('Vendor not found');
    }

    return this.prisma.payment.findMany({
      where: { vendorId },
      orderBy: { createdAt: 'desc' },
    });
  }

  async findBySession(sessionId: string) {
    const session = await this.prisma.session.findUnique({
      where: { id: sessionId },
    });

    if (!session) {
      throw new NotFoundException('Session not found');
    }

    return this.prisma.payment.findMany({
      where: { sessionId },
      orderBy: { createdAt: 'desc' },
    });
  }
}
