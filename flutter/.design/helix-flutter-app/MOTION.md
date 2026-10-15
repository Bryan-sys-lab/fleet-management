# Motion Plan: Helix Flutter App

Produced with the `find-animation-opportunities` gate (frequency → purpose → speed → function).
This app is used every shift, all day: the verdict is *few, fast, functional*. Every suggestion uses
the shared motion tokens from DESIGN_TOKENS.md §5; nothing else may animate.

## Part 1 — Opportunities (survivors, ordered by leverage)

| # | Location | Today (design) | Purpose | Frequency | Suggested motion |
|---|---|---|---|---|---|
| 1 | `HoldToConfirm` / `MaydayButton` | Nothing yet — gesture must show commitment | Feedback (and slip prevention) | Occasional | Press: linear fill overlay `clip: inset(0 100% 0 0)` → 0 over `dur-hold` 2000ms; release before commit: 120ms `ease-out` snap-back; commit: haptic + state morph to SENT/QUEUED. Values from `dur-hold` (policy B-06, never hardcoded) |
| 2 | `BottomSheetHost` + map vehicle drawer | Instant appear | Spatial consistency (surface grows from its trigger edge) | Occasional | 280ms `ease-out`: `translateY(100%) → 0` + opacity 0 → 1; drag handle visible; swipe-dismiss and close button both dismiss along the same edge. Reduced motion: instant, fully visible |
| 3 | `Toast` | Instant appear/disappear | Preventing a jarring change; symmetric path | Occasional | Enter 200ms `ease-out` `translateY(24px) → 0`; exit same edge 160ms `ease-standard`; announced via live region; auto-dismiss 4s |
| 4 | `FormShell` success banner (queued/sent + anomalies) | Instant swap of form → confirmation | Preventing a jarring change (content teleports otherwise) | Occasional | 200ms `ease-out` fade + `translateY(8px) → 0` of the confirmation card; form itself remounts (no crossfade — the remount *is* the double-submit guard) |
| 5 | `StrandButton`, cards, rows (press) | No press feedback | Feedback | Tens/day | `transform: scale(0.97)` + 120ms `ease-out`; `accent-pressed` tone swap at the same instant; visible within ~100ms of touch-down (B4) |
| 6 | Splash logo | Instant | Delight at first-run only (rare tier) | First-run | 300ms `ease-out` opacity 0 → 1 of the logo tile on navy; nothing else moves; skipped entirely on warm start |

## Part 2 — Rejected candidates

- **Tab bar / shell-switch transitions** — navigation happens tens of times a day; the shell switcher itself is rare but the surrounding tab changes are not. **Rejected: frequency tier (tens/day);** selection changes by weight + indicator only, no motion.
- **Live map markers / vehicle-state rows** — data at ~1/s the user is actively reading and acting on. **Rejected: function — decoration on information-dense UI hinders.** Markers snap to position; no trails, no pulses.
- **Realtime-triggered list re-fetches** — invalidation lands every ~2s (throttled) and every 15s during poll fallback. **Rejected: frequency + function —** new data swaps in place; only the skeleton (initial load) animates, never refresh results.
- **Escalation countdown ticker (admin accident detail)** — a number the user is watching under pressure. **Rejected: function —** it updates in place (`mono-data`), no flip/scroll animation.
- **Skeleton shimmer on every refetch** — loading only. The shimmer is allowed once per cold load at `dur-fade`; **rejected on re-fetch** (would fight the 2s throttle).

## Part 3 — Verdict

This interface needs very little motion — six moments, four of them feedback/continuity for state
changes the user caused. The single highest-leverage item is **#1 (hold-to-confirm fill)**: it is the
only animation that carries safety weight (pocket-send prevention on Mayday, slip prevention on
destructive confirms), and it must remain visible-but-optional for reduced-motion users via the
labelled two-step fallback. Everything else is press feedback and symmetric enter/exit. If a screen
wants more than this, the answer is no.
