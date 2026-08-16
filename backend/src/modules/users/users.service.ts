import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import * as bcrypt from 'bcrypt';
import { PrismaService } from '../../config/prisma.service';
import { Paginated, paginate } from '../../common/dto/paginated';
import { DomainError, DomainErrorCode } from '../../common/errors/domain-error';
import { AuditService } from '../audit/audit.service';
import { TokenService } from '../auth/token.service';
import { CreateUserDto } from './dto/create-user.dto';
import { QueryUsersDto } from './dto/query-users.dto';
import { UpdateUserDto } from './dto/update-user.dto';

const SAFE_SELECT = {
  id: true,
  name: true,
  email: true,
  phone: true,
  role: true,
  active: true,
  createdAt: true,
  updatedAt: true,
} satisfies Prisma.UserSelect;

type SafeUser = Prisma.UserGetPayload<{ select: typeof SAFE_SELECT }>;

@Injectable()
export class UsersService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: AuditService,
    private readonly tokens: TokenService,
  ) {}

  async create(dto: CreateUserDto, actorId: string): Promise<SafeUser> {
    const password = await bcrypt.hash(dto.password, 10);
    const user = await this.prisma.user.create({
      data: { ...dto, password },
      select: SAFE_SELECT,
    });
    await this.audit.record({
      userId: actorId,
      action: 'CREATE',
      module: 'USER',
      entityType: 'User',
      entityId: user.id,
      metadata: { email: user.email, role: user.role },
    });
    return user;
  }

  async findAll(query: QueryUsersDto): Promise<Paginated<SafeUser>> {
    const where: Prisma.UserWhereInput = {
      ...(query.role ? { role: query.role } : {}),
      ...(query.active !== undefined ? { active: query.active } : {}),
      ...(query.search
        ? {
            OR: [
              { name: { contains: query.search, mode: 'insensitive' } },
              { email: { contains: query.search, mode: 'insensitive' } },
            ],
          }
        : {}),
    };

    const [items, total] = await this.prisma.$transaction([
      this.prisma.user.findMany({
        where,
        select: SAFE_SELECT,
        orderBy: { [query.sortBy ?? 'createdAt']: query.sortOrder },
        skip: query.skip,
        take: query.limit,
      }),
      this.prisma.user.count({ where }),
    ]);
    return paginate(items, total, query.page, query.limit);
  }

  async findOne(id: string): Promise<SafeUser> {
    const user = await this.prisma.user.findUnique({ where: { id }, select: SAFE_SELECT });
    if (!user) throw DomainError.notFound('User', id);
    return user;
  }

  async update(id: string, dto: UpdateUserDto, actorId: string): Promise<SafeUser> {
    await this.findOne(id);
    const user = await this.prisma.user.update({
      where: { id },
      data: dto,
      select: SAFE_SELECT,
    });
    await this.audit.record({
      userId: actorId,
      action: 'UPDATE',
      module: 'USER',
      entityType: 'User',
      entityId: id,
      metadata: { ...dto },
    });
    return user;
  }

  /** Deactivating a user also revokes all their refresh tokens. */
  async setActive(id: string, active: boolean, actorId: string): Promise<SafeUser> {
    if (id === actorId && !active) {
      throw new DomainError(DomainErrorCode.INVALID_STATE, 'You cannot deactivate your own account');
    }
    await this.findOne(id);
    const user = await this.prisma.user.update({
      where: { id },
      data: { active },
      select: SAFE_SELECT,
    });
    if (!active) await this.tokens.revokeAllForUser(id);
    await this.audit.record({
      userId: actorId,
      action: active ? 'ACTIVATE' : 'DEACTIVATE',
      module: 'USER',
      entityType: 'User',
      entityId: id,
    });
    return user;
  }
}
