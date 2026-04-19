import { Module } from '@nestjs/common';
import { PrismaModule } from '../../config/prisma.module';
import { VendorController } from './vendor.controller';
import { VendorService } from './vendor.service';

@Module({
  imports: [PrismaModule],
  controllers: [VendorController],
  providers: [VendorService],
})
export class VendorsModule {}
