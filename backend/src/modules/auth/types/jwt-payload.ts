import { Role } from '@prisma/client';

/** Claims embedded in the signed access token. */
export interface AccessTokenPayload {
  sub: string; // user id
  email: string;
  role: Role;
  name: string;
}

/** Claims embedded in the signed refresh token. `jti` ties it to a stored, revocable record. */
export interface RefreshTokenPayload {
  sub: string;
  jti: string; // RefreshToken record id
}
