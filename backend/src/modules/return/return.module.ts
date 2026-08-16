import { Module } from '@nestjs/common';
import { InventoryModule } from '../inventory/inventory.module';
import { ReturnController } from './return.controller';
import { ReturnService } from './return.service';

@Module({
  imports: [InventoryModule],
  controllers: [ReturnController],
  providers: [ReturnService],
  exports: [ReturnService],
})
export class ReturnModule {}
