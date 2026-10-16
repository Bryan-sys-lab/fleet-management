# Design Tokens: Helix Flutter App — "Field Instrument"

Derived from the design brief (Rams functionalism, signage heritage, colour-as-information).
Palette strategy: **Restrained** — tinted neutrals + one accent ≤10% + status colours as information.
60/30/10: 60% bone background, 30% paper/surfaces, 10% ink + status colour on data. Both palettes are
intentional (light = Daylight Field, dark = Night Ops), **not** inversions. Every text pair below
was computed with the WCAG relative-luminance formula at design time; results are in §1.4.

**Brand accent = the Helix logo's own strands.** The accent is not an invented brand colour: it is
lifted from the logo. The double helix has two strands, and so does the app — the **cyan strand**
(`#06B6D4 → #0EA5E9 → #3B82F6`) is the Driver shell's identity, the **violet strand**
(`#6366F1 → #8B5CF6 → #D946EF`) is the Admin shell's identity; the **navy** (`#0F172A`) is the brand
moment (splash, logo tile, inverse bars). Strand colours never appear in data/status context.

Flutter implements these as `lib/core/theme/tokens.dart` (`AppColors`, `AppSpace`, `AppType`,
`AppRadius`, `AppMotion`), consumed by `AppTheme` — components never hardcode values.

## 1. Colour

### 1.1 Semantic tokens — Light ("Daylight Field", shipped default)

| Token | Value | Role |
|---|---|---|
| `color-bg` | `#F6F3EC` | Page background (warm bone; never raw white) |
| `color-surface` | `#FDFCF7` | Raised cards/rows (warm paper) |
| `color-surface-sunk` | `#EFEBE1` | Input wells, inset groups, code/data wells |
| `color-surface-inverse` | `#0F172A` | Inverse bars (logo navy; summaries, pressed nav) |
| `color-text` | `#191713` | Primary text (warm ink; never pure black) |
| `color-text-secondary` | `#57503F` | Secondary/metadata text |
| `color-text-tertiary` | `#6E6759` | Placeholder/disabled — **never for essential copy** |
| `color-text-inverse` | `#F6F3EC` | Text on inverse surfaces |
| `color-line` | `#D8D2C4` | Hairline borders, dividers |
| `color-line-strong` | `#B7AF9C` | Input outlines needing a perceivable edge |
| `color-brand-navy` | `#0F172A` | Logo navy — splash, logo tile, inverse bars, shell switcher |
| `color-accent` | `#06B6D4` | Driver strand (logo cyan): primary action fill, live/active indicators |
| `color-accent-text` | `#0E7490` | Accent as text/links/focus rings on light (AA-safe tone of the same strand) |
| `color-accent-pressed` | `#0891B2` | Pressed accent fill (ink text keeps 6.4:1) |
| `color-accent-quiet` | `#DFF3F8` | Selected-row background (state change, not border toggle) |
| `color-admin-accent` | `#6D28D9` | Admin strand (logo violet): admin shell identity, primary fills, selected states |
| `color-admin-accent-quiet` | `#EEE9FD` | Admin selected-row background |
| `color-status-ok` | `#166B3F` | MOVING / healthy / verified |
| `color-status-danger` | `#9E2B1F` | SPEEDING / errors / destructive / brake |
| `color-status-warn` | `#8A5A00` | HOS/pending review text; fill `#F5B400` |
| `color-status-info` | `#2A5EA8` | PARKED / informational |
| `color-status-neutral` | `#5C6468` | OFFLINE |
| `color-status-plum` | `#7A1F5C` | QUARANTINED |
| `color-status-amber` | `#A85500` | HOS_ALERT |
| `color-status-olive` | `#7A6100` | IDLING |

Status colours keep the N5 semantics verbatim (colour + glyph + word, never colour alone):
QUARANTINED ✕ plum · OFFLINE ○ neutral · HOS_ALERT ! amber · SPEEDING ▲ danger ·
MOVING ► ok · IDLING ❚❚ olive · PARKED P info.

### 1.2 Semantic tokens — Dark ("Night Ops", defined, deferred use)

Reserved for admin night-dispatch; not shipped in v1 (driver app is light-only by field-glare decision).

| Token | Value | Token | Value |
|---|---|---|---|
| `bg` | `#141310` | `surface` | `#211F19` |
| `surface-sunk` | `#0C0B09` | `text` | `#ECE9E0` |
| `text-secondary` | `#A8A394` | `line` | `#3A372E` |
| `accent` | `#22D3EE` | `admin-accent` | `#A78BFA` |
| `status-ok` | `#5CB87E` | `status-danger` | `#E0776A` |
| `status-info` | `#7FA8E8` | `status-neutral` | `#8A9189` |
| `status-warn` | `#D9A22E` | | |

### 1.3 Primary action

Primary buttons are **strand-filled**: Driver shell = logo cyan `#06B6D4` with ink text (7.37:1);
Admin shell = violet `#6D28D9` with white text (7.10:1). The brand strand is the app's one brand
colour — never used for data or status, so "selected/live" never confuses with "submit".
Quiet buttons are ink text on surface with a hairline; danger buttons are status-danger filled.
Focus rings and links use `color-accent-text` `#0E7490` (4.83:1 on bone — AA-safe tone of the
same strand; the bright strand tone is reserved for fills and indicators on navy).

### 1.4 Computed contrast (light unless noted)

| Pair | Ratio | Verdict |
|---|---|---|
| text on bg | 16.15:1 | AAA |
| text-secondary on bg | 7.22:1 | AAA |
| text on surface | 17.42:1 | AAA |
| text on surface-sunk | 15.04:1 | AAA |
| status-ok on bg / surface | 5.91 / 6.37 | AA |
| status-danger on bg / surface | 6.72 / 7.25 | AAA/AA |
| status-warn(text) on bg | 5.35:1 | AA |
| status-info on bg | 5.80:1 | AA |
| status-plum on bg | 8.70:1 | AAA |
| status-neutral on bg | 5.45:1 | AA |
| status-amber on bg | 4.78:1 | AA |
| status-olive on bg | 5.36:1 | AA |
| bone on ink (quiet-pressed bars) | 16.15:1 | AAA |
| accent-text `#0E7490` on bg | 4.83:1 | AA |
| accent-text on surface | 5.22:1 | AA |
| ink on accent fill `#06B6D4` (primary button) | 7.37:1 | AAA |
| white on admin-accent `#6D28D9` (admin primary) | 7.10:1 | AAA |
| admin-accent text on bg | 6.41:1 | AAA |
| bone on brand-navy (inverse bars) | 16.11:1 | AAA |
| Dark: accent on bg / admin-accent on bg | 7.65 / 4.39 | AAA / AA |
| Dark: text on bg / secondary on bg | 15.30 / 7.37 | AAA |

## 2. Spacing (4dp base)

`space-1: 4 · space-2: 8 · space-3: 12 · space-4: 16 · space-5: 24 · space-6: 32 · space-7: 48 · space-8: 64`
Screen gutters: phone 16 / admin 24. Card padding: phone 16 / admin 20. Stack gaps: 8 (tight) / 12 (group) / 16 (section).
Touch targets: phone **56**, admin **64** (chips 44 / 52) — unchanged from the tested product behaviour.

## 3. Typography

Signage system: one family pair + mono numerals.

- **Display**: `Barlow Semi Condensed` (600/700) — headers, tab labels, status words, plate-like numerals.
- **Body**: `Barlow` (400/500/600) — all body copy, buttons, fields.
- **Mono**: `IBM Plex Mono` (400/500) — odometers, money (KES), countdowns, coordinates, counts, IDs.
Fonts bundle as assets (no runtime fetch); Latin subset covers en + sw.

| Token | Phone | Admin | Line height |
|---|---|---|---|
| `display` | 30 / 700 | 36 / 700 | 1.1 |
| `title` | 24 / 700 | 28 / 700 | 1.15 |
| `lead` | 19 / 600 | 22 / 600 | 1.3 |
| `body` | 16 / 400 | 17 / 400 | 1.5 |
| `body-strong` | 16 / 600 | 17 / 600 | 1.5 |
| `caption` | 13 / 500 | 14 / 500 | 1.4 |
| `button` | 16 / 600 | 17 / 600 | 1.2 |
| `mono-data` | 16 / 500 | 17 / 500 | 1.3 (tabular) |

Rules: body never below 16px; captions ≥13px; text scaling clamped at 1.3×; no inline one-off sizes;
status words always `title`/`body-strong` with the glyph — never colour alone; numerals in data rows
are `mono-data` right-aligned.

## 4. Layout

- Radii: `control: 8` · `card: 12` · `sheet: 16` · `full: 999` (phone); admin `control: 12 · card: 16 · sheet: 24`.
- Max content width: driver none (full-bleed single column); admin content 960dp, list/detail panes at ≥1280dp.
- Elevation = surface tone step + hairline (`color-line`), **no drop shadows** on data surfaces;
  floating elements (sheets, toasts) get a single soft shadow token: `0 8px 24px rgba(25,23,19,.14)`.
- Theming: light is the shipped theme for both shells; dark tokens exist for admin night use.
- Icons: **Material Symbols Rounded, 24dp, one family everywhere** (locked in design review — no mixed
  families, no emoji, no icon-font drift). Status glyphs (✕ ○ ! ▲ ► ❚❚ P) render as text glyphs inside
  `StatusBadge`, not as icons.

## 5. Motion

| Token | Value | Use |
|---|---|---|
| `dur-press` | 120ms | Button/card press feedback (`scale(0.97)`) |
| `dur-fade` | 200ms | Toasts, banners, skeleton shimmer |
| `dur-sheet` | 280ms | Bottom sheets, vehicle drawer |
| `dur-hold` | 2000ms | Mayday/hold-to-confirm fill (product policy B-06) |
| `ease-out` | `cubic-bezier(0.23, 1, 0.32, 1)` | Entrances, reveals (non-gesture UI) |
| `ease-in-out` | `cubic-bezier(0.77, 0, 0.175, 1)` | Position/state moves (non-gesture UI) |
| `ease-standard` | `cubic-bezier(0.4, 0, 0.2, 1)` | Defaults (non-gesture UI) |
| `spring-ui` | damping 1.0 / response 0.35 | Anything a finger touches: buttons, sheets, toggles — critically damped, no overshoot |
| `spring-drawer` | damping 0.8 / response 0.30 | Sheets, drawers, momentum releases — slight physical overshoot |
| `spring-flick` | damping 0.75 / response 0.40 | Throw-style flicks to a projected rest point |

Motion rules:
- **Springs for anything touchable.** Fixed-duration curves are used only for non-gesture entrances; every gesture-driven move uses `spring-ui`/`spring-drawer`/`spring-flick` from `lib/design/motion.dart`, starting from the live on-screen value so it stays interruptible and redirectable mid-flight.
- **Velocity handoff:** on gesture release the spring starts at the finger's exact velocity, so drag → animate is one continuous motion. Release points project to the nearest detent via the exponential-decay form (apple-design §5–6).
- **Rubber-band at edges:** progressive resistance past a boundary, never a hard stop.
- **Only `transform` and `opacity` animate.** Reduced motion: durations → 0, content instantly visible, hold-to-confirm falls back to a labelled two-step confirm.
- **Materials (frosted chrome):** navigation bar, tab bar and sheets use a translucent blurred backing (`blurChrome` 20 / `blurSheet` 16 over `frostChrome`/`frostSheet` fills); content scrolls underneath. Data surfaces stay opaque — hierarchy is material depth + hairlines, never glass on data.


## 6. Breakpoints / device scales

- **Phone (primary target — all shells are mobile-first)**: 360–430dp width. Driver shell = bottom
  tabs; Admin shell = bottom tabs on phone, promoting to a navigation rail + list/detail panes at
  ≥1024dp (progressive enhancement, never a requirement).
- **One codebase, ONE app, TWO SHELLS** (no build variants): session roles pick the shell
  (DRIVER → cyan strand; admin roles → violet strand); dual-role sessions switch in-app via the
  shell switcher, persisted per device and re-validated on sign-in.
- The admin "scale" (denser type, 64dp targets, 24dp gutters) is a shell-scale setting, applied in
  whichever shell is active; the driver scale (56dp, 16dp gutters) likewise.

## Deviations from the always-dark-mode default (recorded)

**Dark mode ("Night Ops") now ships in both shells**, following the system brightness. Driver glare
is mitigated by keeping data surfaces opaque (warm bone/ink in light, warm graphite in dark) with
status as the only saturated colour on data in both palettes. Dark tokens are defined alongside
light in `AppColors` and flip through `AppColors.setDark(bool)`. No raw `#000`/`#fff` anywhere in
either palette. The accent is the logo's own strand colours (cyan driver / violet admin), ≤10% of
any screen as fills; `#0E7490`/`#6D28D9` are the AA-safe tones of the same strands used wherever the
bright tone would fail contrast. The palette is deliberately not guessable from "logistics = navy + orange".
