# Redesign: Helix Flutter App — "Field Instrument + Apple craft"

Locked design decisions (2026-10-15), produced with the `apple-design` skill (vendored into
`.kilo/skills/apple-design` from github.com/emilkowalski/skills `skills/apple-design`, MIT).

## Direction

Keep the **Field Instrument** identity (bone-paper surfaces, ink signage type, Barlow Semi Condensed
display + IBM Plex Mono mono numerals, twin-strand shell identity: cyan = Driver, violet = Admin)
and layer **Apple-grade craft** on top: spring physics, velocity handoff, interruptible motion,
material depth (frosted chrome), and gestures — always with a visible tap fallback.

## Locked decisions

| Decision | Locked value |
|---|---|
| Aesthetic anchor | Field Instrument identity + Apple craft (springs, velocity, materials) — not a full Apple HIG restyle |
| Motion system | Spring tokens: `spring-ui` (damping 1.0 / response 0.35), `spring-drawer` (0.8 / 0.30), `spring-flick` (0.75 / 0.40); velocity handoff on gesture release; `ease-*` curves only for non-gesture entrances |
| Driver navigation | 4 tabs: Home / Work / Safety / More. Mayday stays largest control on Home. Refuel + Inspect → Work hub; Accidents + Outbox + Inbox → Safety hub |
| Gestures | Drag-dismiss sheets with momentum projection + detents; swipe actions on Outbox rows; mark-read swipe on Inbox rows; hero-tag support on `HelixCard`. Every gesture keeps a visible tap fallback |
| Chrome depth | Frosted translucent nav bar / tab bar / sheets (blur 20/16); data surfaces stay opaque bone/ink |
| Rollout | Whole app at once (no pilot) |
| Dark mode | "Night Ops" ships in both shells, following system brightness (`ThemeMode.system`, `AppColors.setDark`) |

## What changed

- `lib/design/tokens.dart` — palette is now dark-aware (`AppColors.dark` flag + getters); added
  spring/material tokens (`frostChrome`, `frostSheet`, blur values).
- `lib/design/motion.dart` (new) — `AppSpring`, `springTo(...)`, `gestureVelocityToSpring`,
  `projectEndpoint` (Apple exponential-decay form), `rubberBand`.
- `lib/design/theme.dart` — `dark()` theme; `FrostedSurface` widget; NavigationBar/BottomSheet use frosted fills.
- `lib/design/components/sheet_host.dart` — spring-driven sheet, 1:1 drag tracking, velocity handoff to nearest detent, drag-dismiss, visible close button.
- `lib/design/components/swipe_row.dart` (new) — swipe-reveal actions with trailing tap-fallback menu.
- `lib/design/components/card.dart` — optional `heroTag` (Hero) on `HelixCard`.
- `lib/design/components/buttons.dart` — removed hardcoded danger-pressed literal; now token-driven.
- `lib/app/shells.dart` — driver tabs Home/Work/Safety/More; frosted tab bars; badge index 3.
- `lib/app/router.dart` — 4 driver branches; `/driver/work` and `/driver/safety` hubs; Refuel/Inspect/Accidents are sibling routes.
- `lib/app/app.dart` — `ThemeMode.system`; `AppColors.setDark` follows platform brightness.
- `lib/screens/driver/work_screen.dart` (new), `lib/screens/driver/safety_screen.dart` (new).
- `lib/screens/driver/home_screen.dart` — quick links moved to tabs; Mayday/shift/rest remain.
- `lib/screens/driver/outbox_screen.dart` — rows are `SwipeActionRow` (Retry/Discard by swipe; menu tap fallback); deliberate discard keeps HoldToConfirm.
- `lib/screens/shared/inbox_screen.dart` — unread rows swipable to mark read (gated on `notification:manage`).
- `lib/screens/driver/inspect_screen.dart` — hardcoded `#F7E3E1` → `statusDanger.withOpacity(0.10)`.
- `lib/i18n/en.dart`, `lib/i18n/sw.dart` — added `nav.work`, `nav.safety`, `nav.inbox`, `inbox.markRead`.

## Still to verify (no Flutter toolchain in this environment)

- `flutter analyze` — expect clean (0 issues) once compiled on a machine with Flutter.
- `flutter test` — 26/26 suites previously green; re-run after this change set.
- Emulator screenshot review of driver Home / Work / Safety and admin Overview / Map / Review at
  360/375/≥1024dp, light + dark, all four screen states (loaded/loading/empty/error/offline).
- Google Maps SDK key for the admin map (open item P-10) is unrelated to this redesign.

## Docs also updated

`DESIGN_TOKENS.md` §5–6, `MOTION.md`, `DESIGN_BRIEF.md`, `INFORMATION_ARCHITECTURE.md`.
