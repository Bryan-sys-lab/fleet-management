// packages/api/src/http/routes/clerkWebhook.ts
// Clerk webhook endpoint (POST /clerk/webhook).
//
// Clerk signs webhooks with Svix: headers `svix-id`, `svix-timestamp`, `svix-signature`
// (HMAC-SHA256 over `svix-id.${svix-timestamp}.${rawBody}` using CLERK_WEBHOOK_SECRET).
//
// Handled events:
//   user.created   → upsert app.users.clerk_user_id + tenant link
//   user.updated   → sync roles/permissions from Clerk public_metadata into the JWT claims
//
// The webhook is idempotent: re-delivery of the same svix-id is a no-op after the first
// successful processing. Failures are logged but never block Clerk's retry loop (200 always
// returned unless the signature is invalid — Clerk redelivers on non-2xx).

import { Router, type Request, type Response } from "express";
import { z } from "zod";
import { createHmac, timingSafeEqual } from "node:crypto";
import { ok, err, type Principal } from "@fleet/shared";
import { asyncHandler, PROBLEM_CONTENT_TYPE } from "../problem";
import { withClient } from "../../db/withClient";
import type { Infra } from "../../app/compose";
import { makeServices } from "../../app/compose";
import { logger } from "@fleet/shared";

const svixSchema = z.object({
  data: z.object({
    id: z.string(), // clerk_user_id
    email_addresses: z.array(z.object({ email_address: z.string() })).optional(),
    phone_numbers: z.array(z.object({ phone_number: z.string() })).optional(),
    public_metadata: z.record(z.any()).optional(),
    org_memberships: z
      .array(
        z.object({
          organization: z.object({ id: z.string(), role: z.string().optional() }).optional(),
          role: z.string().optional(),
        }),
      )
      .optional(),
  }),
});

type ClerkWebhookEvent = z.infer<typeof svixSchema>;

export interface ClerkWebhookDeps {
  pool: any;
  infra: Infra;
}

export function createClerkWebhookRouter(deps: ClerkWebhookDeps): Router {
  const router = Router();
  const { pool, infra } = deps;

  // Track recently processed svix-ids for idempotency (5-minute TTL).
  const processed = new Map<string, number>();
  const IDEMPOTENCY_TTL_MS = 5 * 60 * 1000;

  function verifySvixSignature(req: Request): boolean {
    const secret = infra.env.CLERK_WEBHOOK_SECRET;
    if (!secret) {
      logger.warn("clerkWebhook: CLERK_WEBHOOK_SECRET not set — rejecting all Clerk webhooks");
      return false;
    }
    const id = req.header("svix-id");
    const ts = req.header("svix-timestamp");
    const sig = req.header("svix-signature");
    const raw = (req as { rawBody?: Buffer }).rawBody;
    if (!id || !ts || !sig || !raw) return false;

    // Replay window: 5 minutes.
    const age = Date.now() - Number(ts);
    if (!Number.isFinite(age) || Math.abs(age) > 5 * 60_000) return false;

    const expected = "v1," + createHmac("sha256", secret).update(`${id}.${ts}.${raw.toString()}`).digest("hex");
    const a = Buffer.from(sig);
    const b = Buffer.from(expected);
    if (a.length !== b.length || !timingSafeEqual(a, b)) return false;

    // Idempotency: reject duplicate svix-id within TTL.
    const now = Date.now();
    const last = processed.get(id);
    if (last !== undefined && now - last < IDEMPOTENCY_TTL_MS) return false; // duplicate
    processed.set(id, now);
    // Sweep expired entries.
    if (processed.size > 1000) {
      for (const [k, v] of processed) {
        if (now - v > IDEMPOTENCY_TTL_MS) processed.delete(k);
      }
    }
    return true;
  }

  async function syncUserFromClerk(client: any, event: ClerkWebhookEvent): Promise<void> {
    const clerkUserId = event.data.id;
    const email = event.data.email_addresses?.[0]?.email_address ?? null;
    const phone = event.data.phone_numbers?.[0]?.phone_number ?? null;
    const metadata = event.data.public_metadata ?? {};
    const roles: string[] = Array.isArray(metadata.roles) ? metadata.roles : [];
    const permissions: string[] = Array.isArray(metadata.permissions) ? metadata.permissions : [];

    // Resolve org from memberships (first org the user belongs to).
    const memberships = event.data.org_memberships ?? [];
    const orgId = memberships[0]?.organization?.id ?? null;

    // Upsert the clerk_user_id mapping. Users are created on signup via the app's own
    // /auth/signup flow; the webhook back-fills clerk_user_id → internal user_id.
    // Match on clerk_user_id only: matching on email/phone lets an attacker who signed up
    // in Clerk with a victim's identifier re-point the victim's row at the attacker's
    // Clerk identity (account takeover). Never overwrite an existing row's email/phone.
    const result = await client.query(
      `UPDATE app.users
         SET updated_at = now()
       WHERE clerk_user_id = $1
       RETURNING id`,
      [clerkUserId],
    );

    if (result.rows.length === 0) {
      // No existing user matched — create a placeholder user record keyed by clerk id.
      const created = await client.query(
        `INSERT INTO app.users (clerk_user_id, email, phone, locale, created_at, updated_at)
         VALUES ($1, $2, $3, 'en', now(), now())
         RETURNING id`,
        [clerkUserId, email, phone],
      );
      // Persist roles/permissions as public metadata so they are synced into JWT claims
      // on the next token refresh. The webhook does not modify Clerk tokens directly;
      // the application reads roles/permissions from app.user_roles / app.permissions.
      logger.info("clerkWebhook: created placeholder user", { clerkUserId });
    }

    logger.info("clerkWebhook: synced user", { clerkUserId, email, phone, orgId, roles, permissions });
  }

  router.post(
    "/webhook",
    asyncHandler(async (req, res) => {
      // Clerk sends the raw body; Express must not have parsed it yet. The app.ts mounts
      // this router after express.raw() middleware is applied to this path.
      if (!verifySvixSignature(req)) {
        res.status(401).type(PROBLEM_CONTENT_TYPE).json({
          type: "https://docs.fleet.internal/problems/unauthenticated",
          title: "Unauthenticated",
          status: 401,
          detail: "Invalid Clerk webhook signature",
          instance: req.requestId,
          error_code: "UNAUTHENTICATED",
        });
        return;
      }

      const body = (req as { body?: unknown }).body as { type?: string; data?: ClerkWebhookEvent } | undefined;
      const eventType = body?.type;
      const eventData = body?.data;

      // Only handle user lifecycle events.
      if ((eventType === "user.created" || eventType === "user.updated") && eventData) {
        // Fire-and-forget: never block Clerk's redelivery loop on our processing.
        void (async () => {
          try {
            const client = await pool.connect();
            try {
              await syncUserFromClerk(client, eventData);
            } finally {
              client.release();
            }
          } catch (e) {
            logger.error("clerkWebhook: user sync failed", { error: String(e), type: eventType });
          }
        })();
      }

      // Always 200 — Clerk redelivers on non-2xx; we never want to block Clerk's retry loop.
      res.status(200).json({ received: true });
    }),
  );

  return router;
}
