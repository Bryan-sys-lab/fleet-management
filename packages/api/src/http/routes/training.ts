// packages/api/src/http/routes/training.ts
// Training / LMS routes (Phase 3, 12_training.sql). Reads use a pooled client and emit RFC7807 via
// result.error.toProblem(); the completion write runs through executeWrite so the audit entry, the
// outbox event and the idempotency completion commit in one transaction (D8).
//
// Route-order rule: `/lessons` and `/roster` are literal paths registered before `/lessons/:id`, and
// `/lessons/:id/complete` is a distinct method+path so it cannot be shadowed.
//
// The completing driver is resolved from the authenticated principal, never from the body: a driver
// can only ever complete a lesson as themselves.

import { Router, type Request, type Response } from "express";
import { z } from "zod";
import { Forbidden, err, ok, type IdempotencyService, type PermissionCode, type PoolLike, type Principal } from "@fleet/shared";
import { authenticate } from "../../middleware/authenticate";
import { idempotency } from "../../middleware/idempotency";
import { requirePermission } from "../../middleware/requirePermission";
import { asyncHandler, PROBLEM_CONTENT_TYPE } from "../problem";
import { executeWrite } from "../write";
import { parseBody, parseQuery } from "../validate";
import { withClient } from "../../db/withClient";
import { CursorQuerySchema } from "../pagination";
import type { Infra } from "../../app/compose";
import { makeServices } from "../../app/compose";

const asPerm = (code: string): PermissionCode => code as PermissionCode;
const ip = (req: Request) => req.ip ?? undefined;
const ua = (req: Request) => req.header("user-agent") ?? undefined;

const LessonCompleteSchema = z.object({
  quiz_score: z.number().int().min(0).max(100).optional(),
});

const CreateLessonSchema = z.object({
  course_id: z.string().uuid(),
  code: z.string().min(1).max(40),
  title: z.string().min(1).max(200),
  description: z.string().max(1000).optional().nullable(),
  content_url: z.string().url().optional().nullable(),
  duration_minutes: z.number().int().min(1).max(480).optional().nullable(),
  order_index: z.number().int().min(0).max(10000).optional(),
});

export interface TrainingRouterDeps {
  pool: PoolLike;
  idempotency: IdempotencyService;
  releaseClaim: (subject: string, key: string) => Promise<void>;
  infra: Infra;
}

export function createTrainingRouter(deps: TrainingRouterDeps): Router {
  const router = Router();
  const { pool, idempotency: idem, releaseClaim, infra } = deps;
  const writer = (req: Request, res: Response, fn: Parameters<typeof executeWrite>[3]) =>
    executeWrite(req, res, { pool, idempotency: idem, releaseClaim }, fn);

  // ── Lesson catalogue (cursor) ────────────────────────────────────────────────────────────
  router.get(
    "/lessons",
    authenticate({ env: infra.env }),
    requirePermission(asPerm("training:read")),
    asyncHandler((req, res) =>
      withClient(pool, async (client) => {
        const query = parseQuery(CursorQuerySchema, req);
        const svc = makeServices(client, infra);
        const result = await svc.training.listLessons({ limit: query.limit, cursor: query.cursor ?? null });
        if (!result.ok) {
          res
            .status(result.error.httpStatus)
            .type(PROBLEM_CONTENT_TYPE)
            .json({ ...result.error.toProblem(), instance: req.requestId });
          return;
        }
        res.status(200).json(result.value);
      }),
    ),
  );

  // ── Manager roster ───────────────────────────────────────────────────────────────────────
  router.get(
    "/roster",
    authenticate({ env: infra.env }),
    requirePermission(asPerm("training:review")),
    asyncHandler((req, res) =>
      withClient(pool, async (client) => {
        const query = parseQuery(CursorQuerySchema, req);
        const svc = makeServices(client, infra);
        const result = await svc.training.roster({ limit: query.limit, cursor: query.cursor ?? null });
        if (!result.ok) {
          res
            .status(result.error.httpStatus)
            .type(PROBLEM_CONTENT_TYPE)
            .json({ ...result.error.toProblem(), instance: req.requestId });
          return;
        }
        res.status(200).json(result.value);
      }),
    ),
  );

  // ── Course catalogue (cursor) — admin picks the course a lesson belongs to ───────────────
  router.get(
    "/courses",
    authenticate({ env: infra.env }),
    requirePermission(asPerm("training:read")),
    asyncHandler((req, res) =>
      withClient(pool, async (client) => {
        const query = parseQuery(CursorQuerySchema, req);
        const svc = makeServices(client, infra);
        const result = await svc.training.listCourses({ limit: query.limit, cursor: query.cursor ?? null });
        if (!result.ok) {
          res
            .status(result.error.httpStatus)
            .type(PROBLEM_CONTENT_TYPE)
            .json({ ...result.error.toProblem(), instance: req.requestId });
          return;
        }
        res.status(200).json(result.value);
      }),
    ),
  );

  // ── Create a lesson (admin uploads training content + rules) ────────────────────────────
  router.post(
    "/lessons",
    authenticate({ env: infra.env }),
    requirePermission(asPerm("training:manage")),
    idempotency({ idempotency: idem }),
    asyncHandler((req, res) =>
      writer(req, res, async (tx, ctx) => {
        const principal = ctx.principal as Principal;
        const input = parseBody(CreateLessonSchema, req);
        const svc = makeServices(tx.client, infra);
        const result = await svc.training.createLesson(tx, {
          courseId: input.course_id,
          code: input.code,
          title: input.title,
          description: input.description ?? null,
          contentUrl: input.content_url ?? null,
          durationMinutes: input.duration_minutes ?? null,
          orderIndex: input.order_index ?? 0,
        });
        if (!result.ok) return err(result.error);
        tx.audit({
          action: "CREATE",
          entity_table: "app.training_lessons",
          entity_id: result.value.id,
          actor_user_id: principal.userId,
          new_value: { course_id: input.course_id, code: input.code, title: input.title },
          request_id: req.requestId,
          ip_address: ip(req),
          user_agent: ua(req),
          endpoint: req.path,
          http_method: req.method,
        });
        return ok({ status: 201, body: result.value, resourceId: result.value.id });
      }),
    ),
  );

  // ── Complete a lesson (current driver) ───────────────────────────────────────────────────
  router.post(
    "/lessons/:id/complete",
    authenticate({ env: infra.env }),
    requirePermission(asPerm("training:complete")),
    idempotency({ idempotency: idem }),
    asyncHandler((req, res) =>
      writer(req, res, async (tx, ctx) => {
        const principal = ctx.principal as Principal;
        const input = parseBody(LessonCompleteSchema, req);
        const svc = makeServices(tx.client, infra);
        // Only a driver profile can hold an enrolment; an admin without one cannot self-complete.
        const driver = await svc.drivers.findByUserId(principal.userId);
        if (!driver) return err(new Forbidden("Only a driver can complete a training lesson"));
        const result = await svc.training.completeLesson(tx, driver.id, req.params.id!, input);
        if (!result.ok) return err(result.error);
        tx.audit({
          action: "UPDATE",
          entity_table: "app.training_enrollments",
          entity_id: result.value.id,
          actor_user_id: principal.userId,
          new_value: { lesson_id: req.params.id, status: result.value.status, quiz_score: input.quiz_score ?? null },
          request_id: req.requestId,
          ip_address: ip(req),
          user_agent: ua(req),
          endpoint: req.path,
          http_method: req.method,
        });
        return ok({ status: 200, body: result.value, resourceId: result.value.id });
      }),
    ),
  );

  // ── Single lesson ────────────────────────────────────────────────────────────────────────
  // MUST stay after `/lessons` and `/lessons/:id/complete`.
  router.get(
    "/lessons/:id",
    authenticate({ env: infra.env }),
    requirePermission(asPerm("training:read")),
    asyncHandler((req, res) =>
      withClient(pool, async (client) => {
        const svc = makeServices(client, infra);
        const result = await svc.training.getLesson(req.params.id!);
        if (!result.ok) {
          res
            .status(result.error.httpStatus)
            .type(PROBLEM_CONTENT_TYPE)
            .json({ ...result.error.toProblem(), instance: req.requestId });
          return;
        }
        res.status(200).json(result.value);
      }),
    ),
  );

  return router;
}
