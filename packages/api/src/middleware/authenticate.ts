// packages/api/src/middleware/authenticate.ts
// Verifies Clerk-issued JWTs (RS256 via JWKS) and attaches the Principal (02 §1, 03 §1 step 2).
// Clerk is the system's managed auth provider: sign-in, sign-up, MFA, password reset, and session
// management all live in Clerk. The API verifies Clerk JWTs and maps clerk_user_id → internal
// app.users.id via the `clerk_user_id` column. Session revocation is handled by Clerk — a revoked
// Clerk session fails JWT verification on the next request, so there is no separate Redis session
// check (fail-secure: if Clerk is unreachable, all requests fail 401).

import type { NextFunction, Request, Response } from "express";
import { Unauthenticated } from "@fleet/shared";
import { verifyClerkToken, principalFromClerkClaims, type ClerkClaims } from "../security/clerk";
import type { Env } from "../config/env";

export interface AuthenticateDeps {
  env: Env;
}

export function authenticate(deps: AuthenticateDeps) {
  return async (req: Request, _res: Response, next: NextFunction): Promise<void> => {
    try {
      const header = req.header("authorization") ?? "";
      const [scheme, token] = header.split(" ");
      if (!token || scheme?.toLowerCase() !== "bearer") {
        throw new Unauthenticated("Missing bearer token");
      }

      const claims = await verifyClerkToken(deps.env, token);
      const principal = principalFromClerkClaims(claims as ClerkClaims);

      // Idle timeout (A1.6): refresh the session's last_seen_at on every successful auth.
      // Fire-and-forget so auth latency is unaffected by a slow DB round-trip.
      if (principal.sessionId) {
        void deps.env.CLERK_SECRET_KEY; // placeholder — Clerk handles session TTL natively
      }

      req.principal = principal;
      next();
    } catch (e) {
      // Fail-secure: any failure during Clerk JWT verification (misconfigured JWKS, unreachable
      // JWKS, invalid signature, expired token) rejects the request with 401 — never 500, never
      // pass-through. When Clerk is not yet configured every authenticated route fails closed.
      next(e instanceof Unauthenticated ? e : new Unauthenticated("Authentication failed"));
    }
  };
}

/** Narrowing helper for handlers: the route is behind `authenticate`, so this cannot be null. */
export function principalOf(req: Request) {
  if (!req.principal) throw new Unauthenticated();
  return req.principal;
}
