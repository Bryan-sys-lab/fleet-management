// packages/api/src/http/routes/accidents.ts
// Accident routes (03 §2.4, 08 §3). State-changing routes carry Idempotency-Key (C5.1) and run
// through executeWrite so audit + outbox (+ escalation timer) commit with the mutation (D8). The
// mayday path is the B17 escape hatch — GPS + reason only, immediate escalation, no photos. Reads
// use a pooled client. Driver id is resolved from the Principal via drivers.user_id.

import { Router, type Request, type Response } from "express";
import { Forbidden, NotFound, err, ok, type IdempotencyService, type PermissionCode, type PoolLike, type Principal } from "@fleet/shared";
import { AccidentCreateSchema, AccidentMediaSchema, MaydaySchema } from "@fleet/shared";
import { authenticate } from "../../middleware/authenticate";
import { idempotency } from "../../middleware/idempotency";
import { requirePermission } from "../../middleware/requirePermission";
import { asyncHandler } from "../problem";
import { executeWrite } from "../write";
import { parseBody, parseQuery } from "../validate";
import { CursorQuerySchema } from "../pagination";
import { withClient } from "../../db/withClient";
import { ownScopeDriverId } from "../ownScope";
import type { Infra } from "../../app/compose";
import { makeServices } from "../../app/compose";

const asPerm = (code: string): PermissionCode => code as PermissionCode;

export interface AccidentRouterDeps {
  pool: PoolLike;
  idempotency: IdempotencyService;
  releaseClaim: (subject: string, key: string) => Promise<void>;
  infra: Infra;
}

export function createAccidentRouter(deps: AccidentRouterDeps): Router {
  const router = Router();
  const { pool, idempotency: idem, releaseClaim, infra } = deps;
  const writer = (req: Request, res: Response, fn: Parameters<typeof executeWrite>[3]) =>
    executeWrite(req, res, { pool, idempotency: idem, releaseClaim }, fn);

  // ── Mayday (B17 escape hatch) ──────────────────────────────────────────────────────────
  router.post(
    "/mayday",
    authenticate({ env: infra.env }),
    requirePermission(asPerm("accident:report")),
    idempotency({ idempotency: idem }),
    asyncHandler((req, res) =>
      writer(req, res, async (tx, ctx) => {
        const principal = ctx.principal as Principal;
        const input = parseBody(MaydaySchema, req);
        const svc = makeServices(tx.client, infra);
        const driver = await svc.drivers.findByUserId(principal.userId);
        if (!driver) return err(new Forbidden());
        const result = await svc.accident.mayday(tx, driver.id, input, {
          userId: principal.userId,
          email: principal.email,
          roles: principal.roles,
        });
        if (result.ok) {
          // Wire contract is snake_case (openapi `/accidents/mayday` → accident_id).
          const { accidentId, escalatedAt } = result.value;
          return ok({
            status: 201,
            body: { accident_id: accidentId, escalated_at: escalatedAt ?? null },
            resourceId: accidentId,
          });
        }
        return err(result.error);
      }),
    ),
  );

  // ── Create a report (evidence follows) ─────────────────────────────────────────────────
  router.post(
    "/",
    authenticate({ env: infra.env }),
    requirePermission(asPerm("accident:report")),
    idempotency({ idempotency: idem }),
    asyncHandler((req, res) =>
      writer(req, res, async (tx, ctx) => {
        const principal = ctx.principal as Principal;
        const input = parseBody(AccidentCreateSchema, req);
        const svc = makeServices(tx.client, infra);
        const driver = await svc.drivers.findByUserId(principal.userId);
        if (!driver) return err(new Forbidden());
        const result = await svc.accident.create(tx, driver.id, input, {
          userId: principal.userId,
          email: principal.email,
          roles: principal.roles,
        });
        if (result.ok) {
          // Wire contract is snake_case (openapi `/accidents` → accident_id).
          const { accidentId } = result.value;
          return ok({ status: 201, body: { accident_id: accidentId }, resourceId: accidentId });
        }
        return err(result.error);
      }),
    ),
  );

  // ── Attach media (append-only) ─────────────────────────────────────────────────────────
  router.post(
    "/:id/media",
    authenticate({ env: infra.env }),
    requirePermission(asPerm("accident:report")),
    idempotency({ idempotency: idem }),
    asyncHandler((req, res) =>
      writer(req, res, async (tx, ctx) => {
        const principal = ctx.principal as Principal;
        const input = parseBody(AccidentMediaSchema, req);
        const svc = makeServices(tx.client, infra);
        const result = await svc.accident.attachMedia(tx, req.params.id!, input, {
          userId: principal.userId,
          email: principal.email,
          roles: principal.roles,
        });
        if (result.ok) return ok({ status: 204, body: {} });
        return err(result.error);
      }),
    ),
  );

  // ── Own reports (read, cursor) ──────────────────────────────────────────────────────────
  router.get(
    "/me",
    authenticate({ env: infra.env }),
    requirePermission(asPerm("accident:read")),
    asyncHandler((req, res) =>
      withClient(pool, async (client) => {
        const query = parseQuery(CursorQuerySchema, req);
        const svc = makeServices(client, infra);
        const driver = await svc.drivers.findByUserId((req as { principal: Principal }).principal.userId);
        if (!driver) {
          res.status(403).json({ error_code: "FORBIDDEN", status: 403, title: "Forbidden" });
          return;
        }
        const result = await svc.accidentQuery.listMine(driver.id, { limit: query.limit, cursor: query.cursor });
        if (!result.ok) {
          res.status(422).json({ error_code: result.error.error_code, status: 422, title: result.error.title });
          return;
        }
        res.status(200).json(result.value);
      }),
    ),
  );

  // ── Verify telemetry hash chain (read) ──────────────────────────────────────────────────
  // OWN-SCOPED, exactly like `GET /:id` below: `fn_verify_accident_chain` takes only the report id,
  // so without resolving the accident own-scoped first, a DRIVER holding accident:read could verify —
  // and existence-probe — any accident id in the tenant. `accident:update` is the scope-lift.
  router.get(
    "/:id/telemetry/verify",
    authenticate({ env: infra.env }),
    requirePermission(asPerm("accident:read")),
    asyncHandler((req, res) =>
      withClient(pool, async (client) => {
        const svc = makeServices(client, infra);
        const driverId = await ownScopeDriverId(req, svc, "accident:update");
        const owned = await svc.accidentQuery.getOne(req.params.id!, driverId);
        if (!owned.ok) {
          const status = owned.error instanceof NotFound ? 404 : 422;
          res.status(status).json({ error_code: owned.error.error_code, status, title: owned.error.title });
          return;
        }
        const result = await svc.accidentQuery.verifyChain(req.params.id!);
        if (!result.ok) {
          res.status(422).json({ error_code: result.error.error_code, status: 422, title: result.error.title });
          return;
        }
        res.status(200).json(result.value);
      }),
    ),
  );

  // ── Acknowledge (cancels escalation) ─────────────────────────────────────────────────────
  router.post(
    "/:id/acknowledge",
    authenticate({ env: infra.env }),
    requirePermission(asPerm("accident:acknowledge")),
    idempotency({ idempotency: idem }),
    asyncHandler((req, res) =>
      writer(req, res, async (tx, ctx) => {
        const principal = ctx.principal as Principal;
        const svc = makeServices(tx.client, infra);
        const result = await svc.accident.acknowledge(tx, req.params.id!, {
          userId: principal.userId,
          email: principal.email,
          roles: principal.roles,
        });
        if (result.ok) {
          const { accidentId, acknowledgedAt } = result.value;
          return ok({ status: 200, body: { accident_id: accidentId, acknowledged_at: acknowledgedAt } });
        }
        return err(result.error);
      }),
    ),
  );

  // ── Single accident detail (read; driver + admin) ────────────────────────────────────────
  // Registered after /me and /:id/telemetry/verify so the literal paths win the match.
  // A driver (accident:read without the fleet-wide accident:update) only ever resolves their own
  // report; anything else 404s rather than leaking another driver's incident.
  router.get(
    "/:id",
    authenticate({ env: infra.env }),
    requirePermission(asPerm("accident:read")),
    asyncHandler((req, res) =>
      withClient(pool, async (client) => {
        const svc = makeServices(client, infra);
        const driverId = await ownScopeDriverId(req, svc, "accident:update");
        const result = await svc.accidentQuery.getOne(req.params.id!, driverId);
        if (!result.ok) {
          const status = result.error instanceof NotFound ? 404 : 422;
          res.status(status).json({ error_code: result.error.error_code, status, title: result.error.title });
          return;
        }
        res.status(200).json(result.value);
      }),
    ),
  );

  return router;
}
