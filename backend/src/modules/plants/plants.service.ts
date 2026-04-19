import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { Plant } from '@prisma/client';
import { PrismaService } from '../../config/prisma.service';
import { CreatePlantDto } from './dto/create-plant.dto';

@Injectable()
export class PlantsService {
  constructor(private readonly prisma: PrismaService) {}

  async create(createPlantDto: CreatePlantDto): Promise<Plant> {
    const category = await this.prisma.category.findUnique({
      where: { id: createPlantDto.categoryId },
    });

    if (!category) {
      throw new BadRequestException('Invalid categoryId provided');
    }

    return this.prisma.plant.create({
      data: createPlantDto,
    });
  }

  async findAll(page: number, limit: number): Promise<Plant[]> {
    const safePage = Math.max(1, page);
    const safeLimit = Math.max(1, limit);
    const skip = (safePage - 1) * safeLimit;

    return this.prisma.plant.findMany({
      skip,
      take: safeLimit,
      orderBy: { createdAt: 'desc' },
    });
  }

  async findOne(id: string): Promise<Plant> {
    const plant = await this.prisma.plant.findUnique({
      where: { id },
    });

    if (!plant) {
      throw new NotFoundException(`Plant with id ${id} not found`);
    }

    return plant;
  }
}
