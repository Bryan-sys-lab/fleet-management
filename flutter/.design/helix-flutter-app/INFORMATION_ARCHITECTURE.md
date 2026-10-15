# Information Architecture: Helix Flutter App

## Site Map

Routes are Flutter named routes; deep links use the `helix://` scheme (see URL Strategy).
There is **one app with two switchable shells** — no build variants. The session's roles pick the
shell at sign-in (DRIVER → Driver shell; FLEET_MANAGER/ADMIN/DISPATCHER/FINANCE/AUDITOR → Admin
shell); dual-role sessions can switch shells in-app without signing out.

### Shared auth flow (pre-session)
- Splash (boot: security checks → session restore) `/splash`
- Login `/login` · Signup `/signup` · Password reset `/password-reset`
- MFA challenge `/mfa`
- Offline PIN unlock `/pin`
- Consent gate `/consent`
- Suspended `/suspended` · Blocked (device integrity) `/blocked`
- Role switch (dual-role sessions) `/role-switch`

### Driver shell (phone, bottom tabs) — identity: cyan strand
- DriverTabs `/driver`
  - Home `/driver/home` — shift card, Mayday, rest banner, quick links
  - Refuel `/driver/refuel` — photo-first fuel purchase
  - Inspect `/driver/inspect` — DVIR
  - Accidents `/driver/accidents` — Mayday + accident report
  - More `/driver/settings` — grouped settings (badge = outbox count)
- Stack (pushed):
  - Clock in `/driver/clock-in` · Clock out `/driver/clock-out`
  - Trailer swap `/driver/trailer-swap`
  - Outbox `/driver/outbox` · Edit queued item `/driver/outbox/:id/edit`
  - My vehicle `/driver/my-vehicle`
  - Inbox `/driver/inbox` (notifications | flags | docs)
  - Anomaly detail `/driver/anomaly/:id` · Document detail `/driver/document/:id`
  - MFA setup `/driver/mfa-setup`

### Admin shell (phone-first, navigation rail on wide screens) — identity: violet strand
- AdminShell `/admin`
  - Overview `/admin/overview` — attention cards, KPI strip
  - Map `/admin/map` — live fleet map + vehicle drawer
  - Accidents `/admin/accidents` → Accident detail `/admin/accidents/:id`
  - Review `/admin/review` (shifts | inspections | fuel) → Shift detail `/admin/shifts/:id` · DVIR detail `/admin/inspections/:id` · Fuel detail `/admin/fuel/:id` · Import statement `/admin/import-statement`
  - Drivers `/admin/drivers` → Driver detail `/admin/drivers/:id`
  - More `/admin/settings`
    - Vehicles `/admin/vehicles` (create/edit/pair/report issue)
    - Tracker pairing `/admin/tracker-pair`
    - Vehicle issues `/admin/vehicle-issues/:vehicleId`
    - Fuel (admin pending) `/admin/fuel-pending`
    - Training `/admin/training` → Roster `/admin/training/roster`
    - Maintenance `/admin/maintenance`
    - Privacy / DSAR `/admin/privacy`
    - Inbox `/admin/inbox` (badge = exact unread from `GET /notifications/count`)

## Navigation Model

- **Primary (both shells)**: bottom tab bar, 5 items max, icon + label + optional badge; placement identical on every tab root; current tab marked by weight + indicator. At ≥1024dp the active shell promotes to a navigation rail with the same destinations (progressive enhancement).
- **Shell identity via the logo's twin strands**: Driver shell chrome = cyan (`#06B6D4` fills / `#0E7490` text tones); Admin shell chrome = violet (`#6D28D9`). The shell switcher shows the *other* strand, so switching reads as crossing between the two strands of the Helix.
- **Secondary**: pushed detail screens (list → detail is the core pattern; back restores scroll, filters, and input state), full-screen covers for focused tasks (photo capture, MFA setup, forms).
- **Utility**: grouped Settings (Account / Security / Profile / Device / Data) inside each shell's More tab; destructive actions (log out, discard queued write) visually + spatially separated and confirmed.
- **Shell entry & switching**: dual-role sessions land on RoleSwitch and may switch later from Settings → Account ("Switch to Driver/Admin experience"); single-role sessions land directly in their shell and the switcher is hidden. The choice persists per device and is re-validated against the session's roles on every sign-in (a stale choice falls back to RoleSwitch).
- **Deep links**: `helix://accident/:id`, `dvir/:id`, `fuel/:id`, `vehicle`, `notifications`, `outbox` — UUID-validated and role-gated; unknown targets are ignored, never crash.

## Content Hierarchy

### Driver Home
1. Shift state (on-duty time / no shift + assignment status) — answers "where do I stand right now?"
2. Mayday (hold-to-send) — the one emergency control, never below actions that could preempt it.
3. Clock in/out + vehicle & trailer summary — the primary daily job.
4. Rest banner (`next_eligible_clock_in_at`, online only) — explains why clock-in may be blocked.
5. Quick links (trailer swap, my vehicle, outbox badge) — secondary.

### Driver Refuel (photo-first)
1. Receipt photo (start) → 2. odometer photo + reading → 3. fuel card picker (`GET /fuel/cards`) + last-4 typed → 4. purchased-at timestamp → 5. submit. Progress implied by capture order; missing items listed under a disabled submit (MissingHint says what is missing).

### Driver Inspect
1. Template picker → 2. per-item controls (PASS/FAIL/NA or numeric within server bounds) → 3. FAIL only: note + photo (required, enforced client-side) → 4. defects-reviewed toggle (required) → 5. signature name → submit.

### Driver Accidents
1. Mayday button → 2. triage severity chips (hint only; server derives) → 3. statement → 4. witness + plate → 5. photo slots → submit.

### Admin Overview
1. Attention cards with exact counts (accidents, DVIR fails, shifts pending, fuel flagged, anomalies, expiring docs) — "at least" labels where the count is a first-page bound.
2. Fleet status counts (N5) → tap to Map.
3. KPI strip (distance, fuel cost KES, anomalies, vehicles, drivers).

### Admin Map
1. Map with status-coloured markers (never colour alone — legend doubles as filter) → 2. selected vehicle drawer (state, driver, position/offline, HOS rest end, odometer, quarantine reason) → 3. quick links (Accidents, Review).

### Admin Review
1. Segmented shifts | inspections | fuel → 2. filter chips (status/state; verified=false) → 3. rows with worst-severity badge → detail with verify/flag/reject/clear/adjust actions gated by permission.

## User Flows

### Sign in (driver, phone)
1. Splash → security verdict; blocked → Blocked screen.
2. Login with phone or email + password.
3. If `mfa_required` → MFA challenge (delivered 6-digit OTP or recovery code in one field).
4. Register this device (`POST /auth/devices`) after session exists — never a gate.
5. If consent not accepted → Consent gate (decline = sign out).
6. Roles: DRIVER only → Driver shell; admin role only → Admin shell; dual → RoleSwitch (switchable later in Settings).
7. Prefetch shift-active + vehicle-states, kick drain scheduler, connect realtime.

### Clock in (offline-tolerant)
1. Clock in → server assignment shown (no picker), last-accepted odometer shown.
2. Odometer entered (decrease or >500 km jump blocked client-side) + required gauge + photo.
3. Optional: location sharing toggle (starts sampler first so the flag is honest).
4. Submit → online: 201 + server `disclaimer` shown verbatim → Home. Offline: queued with stable Idempotency-Key, banner "It will send when you are back online."

### Mayday
1. Hold Mayday 2s (visible progress + haptic).
2. GPS fix + reason only; immediate escalation server-side.
3. Result: SENT / QUEUED / NO_GPS (explains what to do next).

### Admin accident response
1. Live alert banner (mayday/accident) → Open → Accidents list with escalation tier.
2. Accident detail: countdown to escalation, acknowledge (gated), telemetry hash-chain verify, media via 302.
3. Review queue → shift/inspection/fuel detail → verify / flag with reason / reject.

## Naming Conventions

| Concept | Label in UI | Notes |
|---|---|---|
| Vehicle assignment | Assignment | Never "job" or "trip" |
| Safety inspection | Inspection (DVIR in admin detail) | Driver UI says "Inspect" |
| Fuel purchase | Refuel (driver) / Purchase (admin) | Photo-first flow is "Refuel" |
| Emergency alert | Mayday | Never "SOS" or "panic button" |
| Queued offline write | Outbox / Queued | "Pending" chips on items |
| Hours-of-service | Rest / Hours | Rest banner explains blocks |
| Driver document review | Review | Queue name stays "Review" |
| Trailer change | Trailer swap | "Bobtail" is the no-trailer option |
| Role/admin surfaces | Admin (title: Helix Admin) | Backend roles beyond ADMIN map into "Admin" experience |
| Currency | KES, always two decimals | Decimal comma accepted on input |
| Times | Africa/Nairobi; operational dates | Server is authoritative |

## Component Reuse Map

| Component | Used on | Behavior differences |
|---|---|---|
| Screen + PagedList | All list/data screens | offlineTag, refreshControl, empty/error/loading states shared |
| FormShell | Refuel, Inspect, Accidents, Trailer swap, Clock in/out | Remount-on-success; queued/sent banner |
| Button family | Everywhere | primary/quiet/danger; disabled says what's missing |
| MaydayButton / HoldToConfirm | Home, Accidents; destructive confirms | Same gesture engine, different durations/actions |
| StatusBadge (N5) | Home, Map, drawers, lists | Colour + glyph + word; never colour alone |
| GaugePicker | Clock in/out, Refuel | No default; required |
| PhotoCapture + MediaThumb | All capture/report screens | 1080px/500KB budget; 302 reads |
| Segmented | Inbox, Review, admin lists | Badges where counts are exact |
| BottomTabs / NavigationRail | Both shells | Same destinations + badges; rail is the ≥1024dp promotion of the active shell |
| ErrorState | Everywhere | One action from the error catalogue |
| Skeleton | Every list/detail | Honours reduced motion |

## Content Growth Plan

- Lists are cursor-paginated (server keyset); the client never offsets. Filters are chips that preserve scroll position on change.
- Inbox (notifications/flags/docs) grows unbounded → cursor lists + badges from exact counts.
- Review queues grow with traffic → default window today (B-09), widenable; status filters.
- Training/maintenance/vehicles grow slowly → plain cursor lists with search where the list can exceed ~50 rows (virtualized).
- History screens (DVIR history, accidents) → cursor lists keyed by the driver.

## URL Strategy

- Pattern: `helix://<entity>/<uuid>` with a fixed allow-list: `accident`, `dvir`, `fuel`, `vehicle`, `notifications`, `outbox`.
- Dynamic segments are validated as UUID v4 before navigation; role-gated (e.g. `outbox` is driver-only).
- Query parameters: none (deep links carry intent only; filters are in-app state).
- Notification taps map to the same router via `targetFromNotification({entity, id})` using the identical validation.
