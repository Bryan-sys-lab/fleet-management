# Design Brief: Helix Flutter App (driver + admin)

## Problem

A driver standing beside a truck at 6 a.m. — one hand free, glare on the screen, maybe gloves on, maybe no signal — has to clock in, photograph an odometer, answer a safety checklist, or send a Mayday. Meanwhile a fleet manager at HQ needs the same system's truth at a glance: which vehicles are moving, which drivers are out of hours, which fuel purchases look wrong. The previous implementation was contract-correct but, in the project's own ledger (D-01), "usable but looks like a prototype." This brief defines the Flutter implementation's design direction: a new visual identity that keeps Helix's logo and safety semantics but looks like a professional field instrument.

## Solution

One Flutter codebase, ONE app on ONE store listing ("Helix", Android + iOS), with **switchable shells**:
a Driver shell and an Admin shell selected from the session's roles. A dual-role user switches between
them in-app without signing out (choice persists per device, re-validated against the session's roles on
every sign-in); a driver-only or admin-only session lands directly in its shell. This replaces the Expo
app's build-time APP_VARIANT split — one app to maintain, one identity to brand. Every screen is
designed mobile-first for its real context: big gloved-hand targets, honest offline states (queued work
shown, never hidden), status legible by glyph + word + colour (never colour alone), and an admin shell
dense enough to run a fleet from a phone (scaling up to tablet via a navigation rail, never requiring it).
The visual system is "Field Instrument": warm paper surfaces, ink type, signage-condensed display type,
hairline rules, monospaced numerals — status is the only saturated colour on data, and the brand's own
accent is the Helix logo's twin strands: **cyan = Driver shell, violet = Admin shell**.

## Experience Principles

1. **Glanceable over glance-worthy** — information density is designed for a one-handed glance in glare; decoration never competes with data. Elevation comes from surface tone and hairlines, never shadow effects or gradients on data.
2. **Confidence over speed** — irreversible or emergency actions (Mayday, discarding queued work, verification decisions) require deliberate, visible commitment (hold-to-confirm, two-tap confirm). Everything else is one tap.
3. **The field is the constraint, not the device** — offline is a first-class state, not an error. Every data view designs four states: loaded, loading (skeleton), empty (with next action), and offline/queued (with exact sync status).

## Aesthetic Direction

- **Philosophy**: Dieter Rams functionalism executed as a precision field instrument. Restraint, mathematical spacing, colour-as-information, nothing decorative without function. Signage heritage in the display type (dispatching, routes, vehicle plates are a signage world).
- **Tone**: calm, authoritative, trustworthy under pressure. Not playful, not consumer-glossy, not "startup".
- **Reference points**: aviation/industrial instrument panels (legibility of N5-style status), Swiss transit signage (Barlow family heritage), paper operational checklists (bone/paper surfaces), Linear-grade craft in component states (focus, pressed, disabled all designed).
- **Anti-references**: generic AI SaaS look (purple gradients, glassmorphism, sparkle icons); neon "telematics startup" dark mode; Material 3 default purple; Instagram-style consumer chrome; anything that reads as a prototype (flat unstyled lists, pure black on pure white, no designed empty states).
- **Category-reflex test result**: fleet/logistics would reflexively produce navy + safety-orange, or teal-on-black "tracking app". This design refuses both: the primary chrome is warm bone + warm ink with no invented brand colour; the accent IS the Helix logo's own strands (cyan driver / violet admin), used for actions, selection, and live state — never decoration; status colours remain the only saturated colour on data. **Apple-grade craft is layered on top** — spring physics, velocity handoff, interruptible motion, and translucent materials — without abandoning field-instrument restraint.

## Existing Patterns

The new identity must respect the product's tested behaviour and semantics (these are guard-tested in the Expo app and carry over):

- **Helix logo** (double-helix mark) — unchanged; brand string "Helix" everywhere the OS sees it; scheme `helix://`; app names `Helix` (driver) / `Helix Admin`.
- **N5 vehicle status semantics with colour + glyph + word**: QUARANTINED ✕, OFFLINE ○, HOS_ALERT !, SPEEDING ▲, MOVING ►, IDLING ❚❚, PARKED P.
- **Component inventory carried over and elevated**: Screen/PagedList/FormShell containers, Button (56px phone / 64px admin min height), Field, Card, Segmented, GaugePicker (no default), MaydayButton (2s hold), PhotoCapture, MediaThumb, StatusBadge, Skeleton, Toast, PrivacyShield, LiveAlertBanner, OfflineBanner, PendingChip, Section.
- **Typography was Archivo + Public Sans** → new identity: Barlow Semi Condensed (display) + Barlow (body) + IBM Plex Mono (numerals).
- **Colours were asphalt/verge/hazard/brake/dust/paper/mist** → new palette (see DESIGN_TOKENS.md), same semantic roles, new values.
- **Two device scales kept** (phone vs admin), touch 56/64, chip 44/52, radius control 10/12 → 8/12, sheet 18/24 → 16/24.
- **Bilingual en/sw** (device locale default, persisted explicit override), **screenshot blocking** on auth/security screens, **PrivacyShield** in app switcher, **WCAG AA** everywhere, **1.3× text clamp**, **quiet toasts announced to screen readers**.

## Component Inventory

| Component | Status | Notes |
|---|---|---|
| HelixLogo / PrivacyShield | Port | Same SVG asset, new name |
| Screen / PagedList / FormShell | Port + elevate | Containers stay guard-enforced |
| Button / QuietButton / DangerButton | Port + elevate | Ink fill, 56/64 targets, full state set |
| Field / CheckRow / Segmented | Port + elevate | Label above input, blur validation |
| Card / Section / StatusBadge | Port + elevate | Tone-based elevation, hairline dividers |
| GaugePicker | Port | Required, no default — guard stays |
| MaydayButton | Port | 2s hold, progress fill, haptic |
| PhotoCapture / MediaThumb | Port | 1080px / 500KB budget, 302 reader |
| Skeleton / Toast / OfflineBanner / PendingChip / OfflineTag | Port | Announced states |
| LiveAlertBanner (admin) | Port | Mayday/accident banners |
| TopBar / BottomTabs (driver) | New (Flutter idiom) | Bottom nav ≤5, icon + label, badges |
| NavigationRail (admin tablet) | New (Flutter idiom) | Landscape admin shell |
| KeyValueRow / DataRow (admin tables) | New | Tabular mono numerals, 50+ virtualized |
| HoldToConfirm | New (extracted from MaydayButton) | Destructive confirms |
| BottomSheetHost | New (Flutter idiom) | Sheets for pickers/actions, swipe-dismiss + close |
| EmptyState / ErrorState | Port + elevate | Designed four states |

## Key Interactions

- **Hold-to-send Mayday** — 2s hold with visible progress + haptic; states SENT/QUEUED/NO_GPS.
- **Hold/double-tap confirm on destructive** — discard queued write, admin verify/reject decisions.
- **Photo-first forms** — receipt photo → odometer photo → card picker (last-4 typed) → submit; success shows queued/sent banner with flagged anomalies (FormShell pattern, remount after success).
- **Clock in/out** — odometer with last-accepted check, required gauge picker, photo, optional location sharing (honest flag), server disclaimer shown verbatim after clock-in.
- **DVIR** — template picker, per-item PASS/FAIL/NA or numeric with server bounds, FAIL requires note + photo, defects-reviewed toggle, signature.
- **Cursor lists everywhere** — keyset pagination, pull-to-refresh, infinite scroll, filter chips preserve position.
- **Offline writes** — outbox with per-item status, edit FAILED_REVIEW rows (new idempotency key), retry same key, discard with confirm; "Send now" manual drain.
- **Realtime** — listen-only; six events; invalidate-not-patch; snapshot on reconnect; 15s REST poll fallback.
- **Permission-aware UI** — hide admin actions only when the session carries a permission union; permissive fallback otherwise (server 403 decides).

## Responsive Behavior

- **One app, two shells, mobile-first everywhere.** All screens are phone-first (360–430dp).
- **Driver shell**: single-column portrait layout, **four bottom tabs** (Home, Work, Safety, More) with icon + label + badge, primary actions thumb-reachable (bottom), 56dp targets, body 16dp minimum, text clamp 1.3×. Frosted translucent tab bar; content scrolls underneath.
- **Admin shell**: same phone-first approach — bottom tabs (Overview, Map, Accidents, Review, More) with denser admin-scale type and 64dp targets; at ≥1024dp it promotes to a navigation rail + list/detail panes (progressive enhancement, never required). No tablet-only dependency anywhere.
- **Shell switching**: dual-role sessions pick a shell at sign-in and can switch in-app (account menu / Settings) without re-authenticating; the choice persists per device and is re-validated against the session's roles on every sign-in.
- **Orientation changes preserve list scroll, filters, and form state.**

## Accessibility Requirements

- WCAG AA minimum on every text/background pair in BOTH palettes (computed at design time — see DESIGN_TOKENS.md; all pairs ≥4.5:1 text, ≥3:1 UI).
- Status never colour-alone (word + glyph + colour); results and errors announced via live regions.
- Focus indicators on every interactive element; pressed states visible within ~100ms.
- Dynamic Type / system text scaling up to 1.3× without truncation; reduced-motion honoured (motion becomes instant, content fully visible).
- Keyboard/switch-access navigable (Android), TalkBack/VoiceOver labels on all icon-only affordances.
- Screenshot blocking on Login, MFA, PIN, MFA setup; recovery codes not selectable; PrivacyShield in app switcher; lock-screen notifications hide content.
- Driver app ships light-only by default (field glare); **dark ("Night Ops") ships in both shells** following system brightness, with data surfaces opaque in both palettes.

## Out of Scope

- FCM/Firebase push (accepted decision P-06 — gateway-only realtime + local notifications).
- Video capture (B-07 budget makes it impossible; photos only).
- Background location upload / foreground service (D-08 — open device question; clock-in copy states the app only sends while open).
- Web/desktop targets; iOS-first polish parity beyond functional parity.
- Swahili copy rewrite (D-02 needs a native speaker; keys ported as-is).
- Store submission, crash reporting, Play Integrity work (Phases 5–6 of the original plan).
