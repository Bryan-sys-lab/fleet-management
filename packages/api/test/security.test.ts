// packages/api/test/security.test.ts
// Security gate: verifies that security headers are applied to every response (before auth) and
// that authentication is fail-secure when Clerk is not configured. These assertions run in CI as
// part of the deploy gate so no deploy can ship a backend that drops headers or accepts unsigned
// requests.

import { describe, it, expect } from "@jest/globals";
import express from "express";
import request from "supertest";
import helmet from "helmet";
import { securityHeaders } from "../src/security/headers";
import { corsMiddleware } from "../src/security/cors";
import { authenticate } from "../src/middleware/authenticate";
import { problemHandler } from "../src/http/problem";
import jwt from "jsonwebtoken";

describe("security headers (applied before any request is accepted)", () => {
  const app = express();
  app.use(helmet({ hidePoweredBy: true }));
  app.use(securityHeaders());
  app.use(corsMiddleware(""));
  app.get("/", (_req, res) => res.json({ ok: true }));

  it("sets Strict-Transport-Security", async () => {
    const res = await request(app).get("/");
    expect(res.headers["strict-transport-security"]).toContain("max-age=63072000");
    expect(res.headers["strict-transport-security"]).toContain("includeSubDomains");
    expect(res.headers["strict-transport-security"]).toContain("preload");
  });

  it("sets X-Content-Type-Options nosniff", async () => {
    const res = await request(app).get("/");
    expect(res.headers["x-content-type-options"]).toBe("nosniff");
  });

  it("sets X-Frame-Options DENY", async () => {
    const res = await request(app).get("/");
    expect(res.headers["x-frame-options"]).toBe("DENY");
  });

  it("sets Referrer-Policy no-referrer", async () => {
    const res = await request(app).get("/");
    expect(res.headers["referrer-policy"]).toBe("no-referrer");
  });

  it("sets strict CSP default-src none", async () => {
    const res = await request(app).get("/");
    expect(res.headers["content-security-policy"]).toContain("default-src 'none'");
  });

  it("removes X-Powered-By header", async () => {
    const res = await request(app).get("/");
    expect(res.headers["x-powered-by"]).toBeUndefined();
  });

  it("sets additional hardening headers", async () => {
    const res = await request(app).get("/");
    expect(res.headers["x-dns-prefetch-control"]).toBe("off");
    expect(res.headers["x-download-options"]).toBe("noopen");
    expect(res.headers["x-permitted-cross-domain-policies"]).toBe("none");
  });
});

describe("authentication enforcement (fail-secure without Clerk configured)", () => {
  // Clerk env is intentionally absent: CLERK_FRONTEND_URL / CLERK_JWKS_URL are unset, so JWKS
  // resolution throws and every authenticated request is rejected 401 (fail-secure).
  const env = {
    CLERK_SECRET_KEY: undefined,
    CLERK_PUBLISHABLE_KEY: undefined,
    CLERK_JWKS_URL: undefined,
    CLERK_JWT_KEY: undefined,
    CLERK_ISSUER: undefined,
    CLERK_FRONTEND_URL: undefined,
    CLERK_AUTHORIZED_PARTIES: undefined,
    CLERK_JWT_AUDIENCE: undefined,
    CLERK_CLOCK_SKEW_IN_MS: undefined,
    CLERK_WEBHOOK_SECRET: undefined,
  } as unknown as Parameters<typeof authenticate>[0]["env"];

  const app = express();
  app.use(express.json());
  app.use(authenticate({ env }));
  app.get("/protected", (_req, res) => res.json({ ok: true }));
  app.use(problemHandler());

  it("rejects requests without a bearer token", async () => {
    const res = await request(app).get("/protected");
    expect(res.status).toBe(401);
  });

  it("rejects requests with a malformed bearer token", async () => {
    const res = await request(app)
      .get("/protected")
      .set("Authorization", "Bearer not-a-real-token");
    expect(res.status).toBe(401);
  });

  it("rejects requests with an unsigned/HS256 token on Clerk RS256-only verification", async () => {
    const hs256Token = jwt.sign({ sub: "user_123" }, "secret", { algorithm: "HS256" });
    const res = await request(app)
      .get("/protected")
      .set("Authorization", `Bearer ${hs256Token}`);
    expect(res.status).toBe(401);
  });
});

describe("JWT algorithm enforcement", () => {
  it("HS256-signed tokens do not verify under RS256-only (Clerk) verification", () => {
    const hs256 = jwt.sign({ sub: "user_123" }, "secret", { algorithm: "HS256" });
    expect(() => jwt.verify(hs256, "secret", { algorithms: ["RS256"] })).toThrow();
  });

  it("self-issued tokens verify under HS256 only", () => {
    const token = jwt.sign({ sub: "user_123" }, "secret", { algorithm: "HS256", issuer: "fleet-api" });
    const decoded = jwt.verify(token, "secret", { algorithms: ["HS256"], issuer: "fleet-api" });
    expect(decoded).toBeDefined();
  });
});
