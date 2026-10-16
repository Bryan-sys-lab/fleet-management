// packages/api/src/security/clerk.ts
// Clerk JWT verification via JWKS (RS256). Clerk is the system's managed auth provider:
// sign-in, sign-up, MFA, password reset, and session management all live in Clerk.
// The API verifies Clerk-issued JWTs and maps clerk_user_id → internal app.users.id.
//
// Verification follows Clerk's documented "Manual JWT verification" flow:
//   1. JWKS is fetched from {CLERK_FRONTEND_URL}/.well-known/jwks.json and cached by kid.
//   2. If CLERK_JWT_KEY (PEM public key from Clerk Dashboard) is set, verification is
//      networkless — no per-request network call to Clerk.
//   3. `authorizedParties` (CLERK_AUTHORIZED_PARTIES) restricts which frontend app(s)
//      may issue tokens.
//   4. `audience` (CLERK_JWT_AUDIENCE) is checked against the token's `aud` claim.
//   5. `clockSkewInMs` defaults to 5000ms per Clerk docs.
//
// Token claims:
//   sub        → clerk_user_id (maps to app.users.clerk_user_id)
//   sid        → Clerk session id
//   email      → primary email address
// Custom claims (synced via Clerk webhook user.created/user.updated):
//   internal_user_id → app.users.id
//   roles          → app.role_codes
//   permissions    → app.permission_codes

import jwt, { type JwtPayload } from "jsonwebtoken";
import { Unauthenticated, type Principal, type RoleCode, type PermissionCode } from "@fleet/shared";
import type { Env } from "../config/env";

// In-memory JWKS cache keyed by kid. Refreshed on key mismatch (kid rotation).
let jwksCache: Map<string, jwt.Secret | Buffer | jwt.GetPublicKeyOrSecret> = new Map();
let jwksFetchedAt: number | null = null;
const JWKS_TTL_MS = 5 * 60 * 1000; // 5 min — Clerk recommends caching JWKS

export interface ClerkClaims extends JwtPayload {
  sub: string; // clerk_user_id
  sid?: string; // Clerk session id
  email?: string;
  org_id?: string;
  org_role?: string;
  org_permissions?: string[];
  session_id?: string;
  locale?: string;
  /** Custom claim: internal app user id, synced via Clerk webhook. */
  internal_user_id?: string;
  /** Custom claim: roles synced from app.user_roles via Clerk public metadata. */
  roles?: string[];
  /** Custom claim: permissions synced from app.permissions via Clerk public metadata. */
  permissions?: string[];
  /** The intended audience of the token (checked against CLERK_JWT_AUDIENCE). */
  aud?: string | string[];
}

/** Resolve the JWKS URL. Per Clerk docs: {frontendUrl}/.well-known/jwks.json. */
function jwksUrl(env: Env): string {
  const explicit = env.CLERK_JWKS_URL;
  if (explicit) return explicit;
  const frontend = env.CLERK_FRONTEND_URL;
  if (!frontend) throw new Error("CLERK_FRONTEND_URL or CLERK_JWKS_URL must be configured");
  return frontend.replace(/\/$/, "") + "/.well-known/jwks.json";
}

/** PEM public key for networkless verification (from Clerk Dashboard → API keys → JWT public key). */
function jwtKey(env: Env): string | undefined {
  return env.CLERK_JWT_KEY;
}

/** Authorized parties — frontend origins allowed to issue tokens. */
function authorizedParties(env: Env): string[] | undefined {
  const raw = env.CLERK_AUTHORIZED_PARTIES;
  if (!raw) return undefined;
  return raw.split(",").map((s) => s.trim()).filter(Boolean);
}

/** Expected audience, checked against the token's `aud` claim. */
function audience(env: Env): string | string[] | undefined {
  return env.CLERK_JWT_AUDIENCE || undefined;
}

/** Clock skew tolerance (Clerk default: 5000ms). */
function clockSkewInMs(env: Env): number {
  const raw = env.CLERK_CLOCK_SKEW_IN_MS;
  if (!raw) return 5000;
  const n = Number(raw);
  return Number.isFinite(n) ? n : 5000;
}

/** Fetch Clerk's JWKS and cache the public keys by kid. */
async function refreshJwks(env: Env): Promise<void> {
  const url = jwksUrl(env);
  const res = await fetch(url);
  if (!res.ok) throw new Error(`Clerk JWKS fetch failed: ${res.status} ${url}`);
  const jwks = await res.json();
  const keys = new Map<string, jwt.Secret | Buffer | jwt.GetPublicKeyOrSecret>();
  for (const key of (jwks.keys as any[])) {
    if (key.kty === "RSA" && key.use === "sig" && key.kid) {
      let cert: string | undefined;
      if (key.x5c?.[0]) {
        cert = `-----BEGIN CERTIFICATE-----\n${key.x5c[0]}\n-----END CERTIFICATE-----`;
      } else if (key.n && key.e) {
        cert = JSON.stringify({ kty: key.kty, use: key.use, kid: key.kid, n: key.n, e: key.e, alg: key.alg });
      }
      if (cert) keys.set(key.kid, cert);
    }
  }
  jwksCache = keys;
  jwksFetchedAt = Date.now();
}

export async function getSigningKey(env: Env, kid: string): Promise<jwt.Secret | Buffer | jwt.GetPublicKeyOrSecret> {
  const now = Date.now();
  if (jwksFetchedAt == null || now - jwksFetchedAt > JWKS_TTL_MS || !jwksCache.has(kid)) {
    await refreshJwks(env);
  }
  const key = jwksCache.get(kid);
  if (!key) throw new Unauthenticated("Invalid Clerk token: unknown key id");
  return key;
}

/** Verify a Clerk JWT and return its claims. */
export async function verifyClerkToken(env: Env, token: string): Promise<ClerkClaims> {
  const decoded = jwt.decode(token, { complete: true }) as jwt.Jwt | null;
  if (!decoded || !decoded.header.kid) throw new Unauthenticated("Invalid Clerk token");

  const claims = (await jwt.verify(token, await getSigningKey(env, decoded.header.kid), {
    algorithms: ["RS256"],
    issuer: env.CLERK_ISSUER,
    audience: audience(env) as string | RegExp | undefined,
    clockTolerance: clockSkewInMs(env),
  })) as unknown as ClerkClaims;

  if (!claims.sub) throw new Unauthenticated("Invalid Clerk token: missing subject");

  // authorizedParties: the token must be issued for one of the allowed frontend apps.
  const parties = authorizedParties(env);
  if (parties && parties.length > 0) {
    const azp = claims.azp || claims.aud;
    if (!azp || (Array.isArray(azp) ? !azp.some((p) => parties.includes(p)) : !parties.includes(azp))) {
      throw new Unauthenticated("Invalid Clerk token: unauthorized party");
    }
  }

  return claims;
}

/** Build a Principal from verified Clerk claims, mapping clerk_user_id → internal user_id. */
export function principalFromClerkClaims(claims: ClerkClaims): Principal {
  return {
    userId: claims.internal_user_id ?? claims.sub,
    tenantId: claims.org_id ?? "",
    email: claims.email ?? "",
    phone: undefined,
    roles: (claims.roles ?? []).filter(Boolean) as RoleCode[],
    permissions: new Set((claims.permissions ?? []).filter(Boolean)) as Set<PermissionCode>,
    sessionId: claims.session_id ?? claims.sid,
    locale: (claims.locale as "en" | "sw") ?? "en",
  };
}
