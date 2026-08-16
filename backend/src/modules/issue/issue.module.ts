import { Module } from '@nestjs/common';
import { InventoryModule } from '../inventory/inventory.module';
import { IssueController } from './issue.controller';
import { IssueService } from './issue.service';

@Module({
  imports: [InventoryModule],
  controllers: [IssueController],
  providers: [IssueService],
  exports: [IssueService],
})
export class IssueModule {}
