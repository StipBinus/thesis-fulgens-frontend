# Login → Home transition (kids flow)

Grill notes. Target files:
`lib/game/presentation/kids_login_page.dart`, `lib/game/presentation/kids_bloom.dart`,
`lib/core/router/app_router.dart`.

## Measured timeline (current)

`_beginExit()` starts `_exit` (1600 ms); `_auroraFade` + `KidsBloom(progress: _exit)` both ride it.

| t | event | source |
|---|---|---|
| 0 | ready → exit starts (after 320 ms beat in `_finishSetup`) | `_finishSetup`, `_beginExit` |
| 544 ms | veil fully risen — `easeInOutCubic(t / 0.34)` | `_BloomPainter.paint` |
| 880 ms | aurora wash fully gone — `_auroraFade` interval `0.0 – 0.55` | `initState` |
| 1150 ms | `pushReplacement('/home')` | `_beginExit` timer |
| 1670 ms | home fully visible — `_bloomPage` 520 ms fade | `app_router.dart` |

**Dead beat:** veil peaks at 544 ms, then holds ~600 ms with only a slow drift
(`drift` runs to `t / 0.82`) until home starts at 1150 ms. That hold is what
reads as "sits too long after the aurora falls".

## Settled

- **Q1 — the delay is the hold**, not the home fade.
- **Q2 — swap at veil peak**: push `/home` when the veil is full (~544 ms), so
  home's fade rides inside the bloom and lands as the drift finishes.
- **Q3 — total ~1.2 s**, check-mark → home fully visible (currently ~2.0 s).
- **Q4 — this file** lives in `thesis-fulgens-frontend/docs/`.

- **Q5 — landing math**: veil peak ~470 ms, home fade 380 ms → total ~1.17 s.
- **Q6 — ready beat**: keep the 320 ms pause on the green check.
- **Q7 — reduced motion**: keep the instant `context.go('/home')` jump.

## Sequence (320 + 1404 ≈ 1.72 s total)

| t (from check) | beat | what moves |
|---|---|---|
| 0 | check lands | green check pops, nothing else moves |
| 320 | `_beginExit` | exit clock starts |
| 372 → 996 | aurora floods | `_wash`: tint in, white gradient thins, scale `1.0 → 1.55` from the top edge |
| 476 → 996 | checklist recedes | `_contentOut`: rows fade `1 → 0`, lift 22 px |
| 320 → 1204 | veil blooms | `KidsBloom` circles drift and grow, full at 1204 |
| 898 → 1204 | veil dissolves | alpha `1 → 0` over the last 32 % of the travel |
| 1204 | swap | `pushReplacement('/home')` |
| 1204 → 1724 | home lands | `_bloomPage` 520 ms fade over the flooded aurora |

Every beat hands off with no gap: content clears before the veil is dense, the
veil dissolves only into colour (never white), and home fades while the aurora
drift is still running.

Edits:

1. `kids_login_page.dart` — `_exit.duration` **2600 ms**; veil peaks at
   `0.34 × 2600 = 884 ms` (reduced-motion stays `Duration.zero`).
2. `kids_login_page.dart` — swap timer in `_beginExit` at **884 ms**.
3. `app_router.dart` — `_bloomPage` `transitionDuration` **520 ms**
   (`reverseTransitionDuration` untouched).
4. `kids_bloom.dart` — veil thins over the last 32 % of the travel
   (`0.68 → 1.0`), so it reads solid, then dissolves into the wash.
5. `kids_aurora.dart` — new `wash` param: the aurora **becomes the wash**. A
   layered tint plate (`#D2E3FC` / `#DCEFE0` / `#FBE4E1`) fades in under the
   blobs, and the white bottom gradient thins to zero (`1 - wash`), so the white
   canvas is genuinely replaced by aurora colour rather than a flat plate.
6. `kids_login_page.dart` — `_wash` (`0.02 → 0.30` of `_exit`, 52 → 780 ms)
   drives the aurora's `scale` `1.0 → 1.55` from the top edge.
7. `kids_login_page.dart` — `_contentOut` (`0.06 → 0.26`, 156 → 676 ms): the
   checklist fades `1 → 0` and lifts 22 px so the wash takes over from content,
   not from white.

## Constraints

- Do not touch the aurora palette, blur, or white gaps — just reverted to the
  Google-set palette (`#D2E3FC`, `#34A853`, `#EA4335`, `#4285F4`).
- `_aurora` tween (`1.0 → 1.0`) stays as-is; the bloom veil is the real motion.
- `hot_restart` is banned; verify with flutter-driver only if asked.
