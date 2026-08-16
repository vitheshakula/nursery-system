import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import { User } from '@prisma/client';
import { createHash } from 'crypto';
import { PrismaService } from '../../config/prisma.service';
import { AuthTokensDto } from './dto/auth-response.dto';
import { AccessTokenPayload, RefreshTokenPayload } from './types/jwt-payload';

/**
 * Mints and rotates JWTs. Access tokens are short-lived and stateless.
 * Refresh tokens are long-lived but backed by a revocable `RefreshToken`
 * row (only a SHA-256 hash is stored), so logout / deactivation can
 * invalidate them server-side.
 */
@Injectable()
export class TokenService {
  constructor(
    private readonly jwt: JwtService,
    private readonly config: ConfigService,
    private readonly prisma: PrismaService,
  ) {}

  private hash(token: string): string {
    return createHash('sha256').update(token).digest('hex');
  }

  private accessExpiresIn(): string {
    return this.config.get<string>('JWT_ACCESS_EXPIRES_IN', '15m');
  }

  signAccessToken(user: Pick<User, 'id' | 'email' | 'role' | 'name'>): string {
    const payload: AccessTokenPayload = {
      sub: user.id,
      email: user.email,
      role: user.role,
      name: user.name,
    };
    return this.jwt.sign(payload, {
      secret: this.config.getOrThrow<string>('JWT_ACCESS_SECRET'),
      expiresIn: this.accessExpiresIn(),
    });
  }

  /** Creates a refresh record then signs a token bound to it (jti = record id). */
  private async signRefreshToken(userId: string): Promise<string> {
    const ttlDays = Number(this.config.get<string>('JWT_REFRESH_EXPIRES_IN', '7d').replace('d', ''));
    const expiresAt = new Date(Date.now() + ttlDays * 24 * 60 * 60 * 1000);

    const record = await this.prisma.refreshToken.create({
      data: { userId, tokenHash: 'pending', expiresAt },
    });

    const payload: RefreshTokenPayload = { sub: userId, jti: record.id };
    const token = this.jwt.sign(payload, {
      secret: this.config.getOrThrow<string>('JWT_REFRESH_SECRET'),
      expiresIn: this.config.get<string>('JWT_REFRESH_EXPIRES_IN', '7d'),
    });

    await this.prisma.refreshToken.update({
      where: { id: record.id },
      data: { tokenHash: this.hash(token) },
    });
    return token;
  }

  async issueTokenPair(user: User): Promise<AuthTokensDto> {
    const [accessToken, refreshToken] = await Promise.all([
      this.signAccessToken(user),
      this.signRefreshToken(user.id),
    ]);
    return { accessToken, refreshToken, expiresIn: this.accessExpiresIn() };
  }

  /** Validates a presented refresh token against its stored, non-revoked record. */
  async assertRefreshTokenValid(payload: RefreshTokenPayload, rawToken: string) {
    const record = await this.prisma.refreshToken.findUnique({ where: { id: payload.jti } });
    if (
      !record ||
      record.revokedAt ||
      record.userId !== payload.sub ||
      record.expiresAt < new Date() ||
      record.tokenHash !== this.hash(rawToken)
    ) {
      return null;
    }
    return record;
  }

  async revokeToken(jti: string): Promise<void> {
    await this.prisma.refreshToken
      .updateMany({ where: { id: jti, revokedAt: null }, data: { revokedAt: new Date() } })
      .catch(() => undefined);
  }

  async revokeAllForUser(userId: string): Promise<void> {
    await this.prisma.refreshToken.updateMany({
      where: { userId, revokedAt: null },
      data: { revokedAt: new Date() },
    });
  }
}
