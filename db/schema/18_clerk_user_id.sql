-- =============================================================================
-- 18_clerk_user_id.sql
-- Add clerk_user_id to app.users so Clerk (managed auth) can map clerk_user_id
# → internal app.users.id. Nullable during migration; backfilled via Clerk
-- user.created / user.updated webhooks. Unique so one Clerk user maps to one
-- internal user.
-- =============================================================================

ALTER TABLE app.users
    ADD COLUMN IF NOT EXISTS clerk_user_id text UNIQUE;

CREATE INDEX IF NOT EXISTS users_clerk_user_id_idx
    ON app.users (clerk_user_id)
    WHERE clerk_user_id IS NOT NULL;

COMMENT ON COLUMN app.users.clerk_user_id IS
    'Clerk user ID (sub claim in Clerk JWT). Maps Clerk auth identity to internal app.users.id. Populated by Clerk webhooks (user.created / user.updated).';
