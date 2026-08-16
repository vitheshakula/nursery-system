import { Injectable, UnauthorizedException } from '@nestjs/common';
import * as bcrypt from 'bcrypt';
import { PrismaService } from '../../config/prisma.service';
import { AuthResponseDto } from './dto/auth-response.dto';
import { LoginDto } from './dto/login.dto';
import { TokenService } from './token.service';
import { RefreshTokenPayload } from './types/jwt-payload';

@Injectable()
export class AuthService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly tokens: TokenService,
  ) {}

  async login(dto: LoginDto): Promise<AuthResponseDto> {
    const user = await this.prisma.user.findUnique({ where: { email: dto.email } });
    if (!user || !(await bcrypt.compare(dto.password, user.password))) {
      throw new UnauthorizedException('Invalid email or password');
    }
    if (!user.active) {
      throw new UnauthorizedException('Account is deactivated');
    }

    const tokens = await this.tokens.issueTokenPair(user);
    return {
      ...tokens,
      user: { id: user.id, name: user.name, email: user.email, role: user.role },
    };
  }

  /** Rotates the refresh token: the presented one is revoked, a new pair issued. */
  async refresh(payload: RefreshTokenPayload, rawToken: string): Promise<AuthResponseDto> {
    const record = await this.tokens.assertRefreshTokenValid(payload, rawToken);
    if (!record) throw new UnauthorizedException('Invalid or expired refresh token');

    const user = await this.prisma.user.findUnique({ where: { id: payload.sub } });
    if (!user || !user.active) throw new UnauthorizedException('Account is deactivated');

    await this.tokens.revokeToken(record.id);
    const tokens = await this.tokens.issueTokenPair(user);
    return {
      ...tokens,
      user: { id: user.id, name: user.name, email: user.email, role: user.role },
    };
  }

  async logout(payload: RefreshTokenPayload, rawToken: string): Promise<{ revoked: boolean }> {
    const record = await this.tokens.assertRefreshTokenValid(payload, rawToken);
    if (record) await this.tokens.revokeToken(record.id);
    return { revoked: true };
  }
}
