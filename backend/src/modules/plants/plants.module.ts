import { Module } from '@nestjs/common';
import { PrismaModule } from '../../config/prisma.module';
import { PlantsController } from './plants.controller';
import { PlantsService } from './plants.service';

@Module({
  imports: [PrismaModule],
  controllers: [PlantsController],
  providers: [PlantsService],
})
export class PlantsModule {}
