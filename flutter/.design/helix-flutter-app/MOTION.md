# Motion Plan: Helix Flutter App

Produced with the `find-animation-opportunities` gate (frequency → purpose → speed → function).
This app is used every shift, all day: the verdict is *few, fast, functional*. Every suggestion uses
the shared motion tokens from DESIGN_TOKENS.md §5; nothing else may animate. All gesture-driven
motion is **spring-based** (damping/response, velocity-aware, interruptible at any instant — see
the `apple-design` skill, §3–9) and degrades to instant under reduced motion.

## Part 1 — Opportunities (survivors, ordered by leverage)

| # | Location | Today (design) | Purpose | Frequency | Suggested motion |
|---|---|---|---|---|---|
| 1 | `HoldToConfirm` / `MaydayButton` | Fill overlay on hold | Feedback (slip prevention) | Occasional | Press: linear fill overlay over `dur-hold` 2000ms; release before commit: spring snap-back `spring-ui`; commit: haptic + state morph to SENT/QUEUED. Reduced motion: labelled two-step confirm |
| 2 | `BottomSheetHost` + map vehicle drawer | Instant appear | Spatial consistency (surface grows from its trigger edge) | Occasional | `spring-drawer` slide `translateY(100%) → 0` + opacity; drag tracks the finger 1:1; release projects to nearest detent carrying release velocity; drag-dismiss and close button both dismiss along the same edge. Frosted sheet surface; drag handle visible. Reduced motion: instant, fully visible |
| 3 | `Toast` | Instant appear/disappear | Preventing a jarring change; symmetric path | Occasional | Enter `spring-ui` `translateY(24px) → 0` + opacity; exit same edge; announced via live region; auto-dismiss 4s |
| 4 | `FormShell` success banner | Instant swap of form → confirmation | Preventing a jarring change (content teleports otherwise) | Occasional | `spring-ui` fade + `translateY(8px) → 0` of the confirmation card; form remounts (the remount *is* the double-submit guard) |
| 5 | StrandButton, cards, rows (press) | No press feedback | Feedback | Tens/day | `transform: scale(0.97)` + 120ms `ease-out`; `accent-pressed` tone swap at the same instant; visible within ~100ms of touch-down |
| 6 | Splash logo | Instant | Delight at first-run only (rare tier) | First-run | 300ms `ease-out` opacity of the logo tile on navy; nothing else moves; skipped entirely on warm start |

## Part 2 — Rejected candidates

- **Tab bar / shell-switch transitions** — navigation happens tens of times a day. **Rejected: frequency tier**; selection changes by weight + indicator only, no motion.
- **Live map markers / vehicle-state rows** — data read ~1/s while acting. **Rejected: function** — decoration on information-dense UI hinders. Markers snap; no trails, no pulses.
- **Realtime-triggered list re-fetches** — invalidation lands every ~2s (throttled) and every 15s in poll fallback. **Rejected: frequency + function** — new data swaps in place; only the initial skeleton animates.
- **Escalation countdown ticker (admin accident detail)** — a number watched under pressure. **Rejected: function** — updates in place (`mono-data`), no flip/scroll.
- **Skeleton shimmer on every refetch** — loading only; shimmer once per cold load at `dur-fade`; rejected on re-fetch.
- **Swipe-to-delete without confirmation** — destructive outbox/discard commits keep their deliberate hold ceremony; swipe reveals actions, the hold button remains the visible, always-available path.

## Part 3 — Verdict

This interface needs very little motion — six moments, four of them feedback/continuity for state
changes the user caused. The single highest-leverage item is **#1 (hold-to-confirm fill)**: it is the
only animation that carries safety weight (pocket-send prevention on Mayday, slip prevention on
destructive confirms), and it keeps its labelled two-step fallback for reduced-motion users.
Everything else is press feedback and symmetric enter/exit. If a screen wants more than this, the
answer is no.
