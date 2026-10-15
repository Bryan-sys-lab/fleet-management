# Screen Designs: Helix Flutter App

Combines the `frontend-design` skill (named concept, implement in the real stack) and the `ui-ux-kit`
surface profiles this app routes to: **B4 Mobile/Native** (primary) + **B3 App/Product UI** + **B2
Dashboard/Admin data rules** for the admin shell. Component layer sits on a re-themed Material 3
(`ColorScheme` seeded from these tokens) — never the library default look.

## The concept (Step 2.7)

**"The app is a field instrument panel — bone paper surfaces, ink signage type, hairline rules,
mono numerals — expressed through layout (single-column glanceable stacks), type (Barlow Semi Condensed
display + IBM Plex Mono data), colour (status is the only saturated colour on data; the logo's twin
strands drive shell identity), and motion (press feedback and hold-to-confirm only)."**

Falsifiable check: no avatar bubbles, no cards-on-cards, no shadow elevation, no gradient on data, no
emoji as icons, no purple-gradient chrome — the shell accent is the logo's cyan/violet, full stop.

## Shared component specs (the vocabulary)

Every component: full state set (default / pressed / focused / disabled / loading), Semantics labels,
reduced-motion aware, tokens only (zero literals).

| Component | Spec |
|---|---|
| `StrandButton` (primary) | Height 56 (driver) / 64 (admin); fill = active shell strand (`#06B6D4` ink text / `#6D28D9` white text); radius `control`; pressed = scale 0.97 + strand-pressed tone, 120ms ease-out; disabled = sunk fill + tertiary text; busy = inline spinner replaces label, width stable |
| `QuietButton` / `DangerButton` | Hairline ink text on surface / danger fill bone text; same metrics |
| `Field` | Label above input (`body-strong`), input `body`, sunk fill `#EFEBE1`, hairline `line-strong`; focus = 2px `accent-text` ring; error = danger ring + caption message below; helper text allowed; required marker "required" in caption (not just asterisk); numeric fields use `mono-data` + correct keyboard type; blur validation (never keystroke) |
| `Card` | `surface` fill, `line` hairline, radius `card`, space-4 padding; selected = `accent-quiet` fill (tone change, not border toggle); no shadows |
| `Section` | `lead`-weight group header + `caption` secondary line; 16dp gutters; hairline separators inside |
| `StatusBadge` | Glyph + word + strand-neutral chip (`sunk` bg, status colour text); N5 order; always ≥44dp tall |
| `Segmented` | Equal-width segments; active = `sunk` fill + ink weight 600; optional count badge from exact endpoints only |
| `PagedList` | One cursor list: skeleton → error (retry action) → empty (next action) → rows; pull-to-refresh; infinite scroll via `onEndReached`; offline tag when data is cached copy; virtualize ≥50 rows |
| `Skeleton` | `sunk` bars pulsing at `dur-fade`; reduced-motion = static; announced once |
| `ErrorState` | Catalogue message (en/sw) + exactly one action button from `ERROR_CATALOG`; `RATE_LIMITED` shows 15s countdown before retry |
| `EmptyState` | What this is for + the one next action; never a bare "No data" |
| `OfflineTag` / `PendingChip` | Caption chips marking cached data / queued writes |
| `Toast` | Bottom, above tab bar, 4s, announced to screen readers, `ease-out` enter/exit same edge |
| `GaugePicker` | 5-position radiogroup E / ¼ / ½ / ¾ / F; **no default** (guard-carried); glyph + letter + word |
| `HoldToConfirm` / `MaydayButton` | 2000ms linear fill overlay on press, 120ms ease-out snap-back on release; haptic on commit; accessibility actions + switch-access fallback; reduced-motion = labelled two-step confirm |
| `PhotoCapture` | Capture → grant → camera → resize ≤1080px → compress ladder ≤500KB → staged file; `UPLOAD_UNAVAILABLE` state if it cannot fit; no video |
| `MediaThumb` | 302-resolved presigned GET, memory/disk cached; placeholder = document glyph |
| `BottomSheetHost` | Modal bottom sheets for pickers/actions: drag handle, swipe-dismiss **and** explicit close, detents; never a desktop dialog on phone |
| `KeyValue` / `DataRow` | Admin data rows: label left, value right in `mono-data` (tabular); right-align numbers, left-align text |
| `PrivacyShield` | Logo on navy over the app switcher; screenshot blocking on Login/MFA/PIN/MfaSetup; recovery codes non-selectable |
| `ShellSwitcher` | Account-menu row showing the other strand's colour + label ("Switch to Admin experience"); hidden for single-role sessions |

## Auth flow (shared, both shells)

### Splash
Logo tile (navy gradient square, 88dp) centred on `bg`; brand navy moment; silent security verdict +
session restore; no progress spinner theatre — the app either boots or routes.

### Login
Wordmark "Helix" (`display`), one field ("Email or phone"), password with show/hide, primary submit
(strand-neutral: driver sessions haven't picked a shell yet → ink submit until a role is known),
quiet "Register this device" retry, footer help. Screen-capture blocked. Error via `ErrorState`
(catalogue message + one action); login `RATE_LIMITED` shows countdown.

### MFA challenge
One field accepting the delivered 6-digit OTP **or** a recovery code (4–16 chars); resend hint in
caption; logout quiet button; blocked from screenshots.

### PIN unlock
4-digit PIN with big square keys (56dp); attempts/lock/wipe announced; after 5 wrong → lock 15 min;
10 → local wipe + forced password login; "Log in with password" fallback always visible.

### Consent
GPS tracking consent in plain en/sw language; accept → continue; decline → sign out (guard-carried).

### Role switch (dual-role only)
Two large cards — Driver experience (cyan strand edge + truck glyph) / Admin experience (violet strand
edge + roster glyph) — one tap enters a shell; switchable later in Settings.

## Driver shell (cyan strand)

### Home — "where do I stand"
1. Greeting + driver name (from onboarding — the only name source), `lead` weight.
2. **Mayday** (hold 2s) — the single largest control, danger-adjacent but ink/chrome styled, never competing with submit buttons.
3. Shift card: on-duty duration (`mono-data`), vehicle plate chip, Clock out; or no-shift card with status badge, `noAssignmentHint` when null, Clock in.
4. Rest banner when `next_eligible_clock_in_at` is future (online only): "You can clock in at 18:30" with time in mono.
5. Quick links row: Trailer swap, My vehicle, Outbox (badge = queued count).

### Clock in
Assignment summary card (server-assigned, no picker) → last accepted odometer (`mono-data`) → odometer field (client blocks decrease / >500km jumps) → GaugePicker (required) → photo (staged) → optional plan notes → location-sharing toggle (starts sampler *before* the write so the flag is honest) → MissingHint list under disabled submit → on success: server `disclaimer` shown verbatim in a confirmation card → Home.

### Refuel (FormShell)
Steps in one scroll: receipt photo → odometer photo + whole-km reading → fuel card picker (bottom sheet, label · provider · pooled) → last-4 typed → purchased-at → submit. Success remounts the form + banner ("Saved. It will send when you are back online." + flagged anomalies with "See flags" action).

### Inspect (FormShell)
Template picker (bottom sheet) → per-item rows: PASS / FAIL / NA segmented or numeric field within server bounds (`unit` shown) → FAIL row expands: note + photo (both required) → defects-reviewed checkbox (required) → signature name → submit. Fail rows carry blocker severity chips when the template says so.

### Accidents
Mayday button → triage chips (MINOR/MODERATE/SEVERE, labelled "hint only") → statement → witness + plate → 4 photo slots → submit.

### Outbox
Count header + per-row cards: path caption, status chip (PENDING/INFLIGHT/FAILED_REVIEW), error code; actions: Edit (FAILED_REVIEW only → new idempotency key), Retry (same key), Discard (hold/double-tap confirm), "Send now" (manual drain); polls every 5s.

### Inbox
Segmented Notifications / Flags / Docs; unread dot; tap marks read only when the session holds `notification:manage`; rows deep-link via validated targets.

### Settings (More)
Grouped sections (Account / Security / Profile / Device / Data) exactly as the Expo app, with the shell switcher inside Account for dual-role sessions. Language toggle (English ⇄ Kiswahili), role switch, PIN/biometric/MFA, devices with revoke, outbox entry, two-tap logout with unsent-writes warning.

## Admin shell (violet strand, phone-first)

### Overview
Attention cards (exact counts where analytics provides them — never fake precision; first-page bounds get an "(at least)" caption), each tappable → its queue. Fleet status counts (N5 row) → Map. KPI strip: distance, fuel cost KES, anomalies, vehicles, drivers (`mono-data`, right-aligned).

### Map
Full-bleed map (google_maps_flutter) + status filter chips doubling as legend (glyph + word + colour); markers coloured by `display_state`; null-fix vehicles are **listed, not drawn** (OFFLINE) — never a floating (0,0) pin. Bottom sheet vehicle drawer: status badge, driver, position/offline, HOS rest end (`mono-data`), odometer, quarantine reason; quick links to Accidents/Review. 15s REST poll when the socket is down; stale-data card says so.

### Accidents → detail
List rows: mayday badge, reference (`mono-data`), escalation tier, acked state. Detail: countdown to escalation (`mono-data`, ticking), acknowledge (gated), telemetry hash-chain verify (VALID/INVALID per row), media via 302 thumbs, "Add photo" (slot OTHER), route-params row renders instantly if the fetch fails.

### Review (Shifts | Inspections | Fuel)
Filter chips (status/state; verified=false) preserve scroll; rows carry worst-open-severity badge. Detail: ShiftDetail (verify/flag-with-reason/force-close gated), DvirDetail (per-item results, FAIL in danger with blocker notes, photos, quarantine banner), FuelDetail (litres/cost KES `mono-data`, card last-4, OCR status + confidence %, verify with optional adjusted litres / reject with reason / clear payment — each gated). Import statement entry from the fuel header.

### Drivers → detail
Roster with status filter chips; inline create form; detail: devices (revoke with two-tap, gated `device:revoke`), revoke all sessions, suspend/reinstate (two-tap), read-only MFA state, approve (reveal-confirm).

### Admin More (Settings sub-screens)
Vehicles (list + create sheet + edit/pair/report-issue, gated), TrackerPair (camera IMEI scan + manual fallback + vehicle picker), VehicleIssues (list + report form), AdminFuel (pending OCR list), Training (lessons + roster), Maintenance (records + work-order form), Privacy (export/deletion requests), Inbox (exact badge from `GET /notifications/count`; mark-read only with `notification:manage`).

## State discipline (applies to every screen)

Every data view designs all four states: **loaded** (data or empty-with-next-action), **loading**
(skeleton, once-announced), **error** (catalogue message + one action), **offline** (cached copy +
OfflineTag; writes queued with exact status). Nothing static, nothing silent: async actions show a
busy state the moment they start; every action resolves with success/error feedback.

## Flutter implementation notes

- Material 3 `ThemeData` built from tokens (`ColorScheme.fromSeed` avoided — explicit scheme so the
  exact hexes hold); one styled base, re-themed; `google_fonts` not used at runtime — Barlow/Barlow
  Semi Condensed/IBM Plex Mono bundled as assets.
- Navigation: `go_router` (route table above, deep links, shell-per-branch), `StatefulShellRoute` for
  the tab shells; shell switch = swapping the active branch + persisted role choice.
- State: `flutter_riverpod`; server cache via a query layer mirroring TTLs (vehicle-states/shift 10s…);
  outbox on `sqflite`/`drift`; realtime via `socket_io_client`; secure storage `flutter_secure_storage`.
- Platform: `permission_handler`, `camera`, `geolocator`, `image_picker`-free (camera plugin direct),
  local notifications `flutter_local_notifications`, maps `google_maps_flutter`, screenshot blocking
  `screen_protector`, device integrity + cert pinning mirrored from the Expo hardening layer.
