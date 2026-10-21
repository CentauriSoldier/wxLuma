# wxLuma redraw optimization results

Measured October 20, 2026 on the current Windows workstation. All UI component instances retain the actual/decoy/metatable design.

## Changes

- Unchanged generic, checkbox, radio and snapped numeric values avoid default-background invalidation.
- Pointer movement within the same drawn state/part and keyboard auto-repeat no longer repaint unchanged controls. Value changes during dragging still invalidate through their setters.
- Repeated enabled state and identical geometry avoid unnecessary native work. First layout and real size changes still lay out children.
- Radio groups invalidate members whose selected indicator changes; custom backgrounds retain their explicit refresh behavior.
- Stable native text bindings preserve caret and selection. Numeric editors still canonicalize input such as 004 to 4. Disabled text changes explicitly invalidate the surface that paints their text.
- Repeated identical dropdown layout no longer dismisses an open popup.

## Native paint-count checks

RedrawRegression.lua exercises 100 repeated unchanged operations per case. Checkbox values, snapped slider values, spinner values, pointer motion, surface motion, enabled state, input layout and key repeat each fell from 100 paints to zero. Repeated radio selection fell from 200 paints to zero. Changed values, focus changes, custom backgrounds, native editing and real layouts remain covered by passing checks.

## Fair active-game comparison

Three implementations ran in fresh processes with alternating order: original plain controls; the exact pre-optimization object snapshot; and optimized objects. Each implementation received the same workload, 120 warmup frames and 600 measured frames per trial, with two trials per workload.

The scene uses a separate native animated viewport alongside the HUD. Refreshing the decorated parent window can invalidate all its children, defeating dirty-control rendering. The viewport arrangement is identical for all three implementations, and its benefit is not attributed to the framework optimization.

- Target: 120 Hz; 8.333 ms budget. High-resolution 10 MHz monotonic clock.
- Client area: 1360 x 940. Each frame includes a 2 ms synthetic game-logic reservation.
- HUD: 22 wxLuma widgets, a 10,000-row scrolling list and 120 moving rectangles in the benchmark viewport.
- Heavy: 90 wxLuma widgets, four 10,000-row scrolling lists and 600 moving rectangles in the viewport.
- Model bindings are polled each frame. Most resource values change periodically; a quarter of meters animate continuously. Sliders step every six frames. Actions, native editor commits, continuous list scrolling and panel resizing remain active.
- The viewport redraws continuously. Unchanged child controls are not forcibly invalidated by the harness. Every dirty top-level control must finish its native paint without error before the frame completes.
- Rates count completed native UI paint batches, not monitor presentation or GPU game frames. There is no full game-world renderer in this benchmark.

| Workload | Implementation | Mean completed batches/s | Mean median UI ms | Mean median total work ms | Paint calls | Work frames over budget |
|---|---|---:|---:|---:|---:|---:|
| HUD | Original plain | 119.89 | 4.131 | 6.134 | 15020 | 52/1200 |
| HUD | Objects before optimization | 119.89 | 4.084 | 6.086 | 15020 | 62/1200 |
| HUD | Optimized objects | 119.90 | 2.477 | 4.479 | 7108 | 30/1200 |
| Heavy | Original plain | 91.71 | 8.214 | 10.216 | 54020 | 1200/1200 |
| Heavy | Objects before optimization | 91.20 | 8.285 | 10.287 | 54020 | 1200/1200 |
| Heavy | Optimized objects | 118.18 | 4.773 | 6.775 | 29432 | 353/1200 |

HUD: median UI work decreased 39.3% against the exact object snapshot; mean completion rate changed 0.0%.

Heavy: median UI work decreased 42.4% against the exact object snapshot; mean completion rate changed 29.6%.

The means above average two trial medians or rates, rather than computing pooled percentiles. All three implementations produced matching callback counts and final list selections. The optimized heavy workload approaches 120 batches/s on average, but 353 of 1,200 frames exceeded 8.333 ms; sustained deadline-perfect 120 Hz has not been established.

| Workload | Version | Round | Work p95 ms | Work p99 ms | UI p95 ms | UI p99 ms |
|---|---|---:|---:|---:|---:|---:|
| HUD | Old | 1 | 7.880 | 9.296 | 5.878 | 7.294 |
| HUD | Before | 1 | 8.242 | 10.448 | 6.238 | 8.446 |
| HUD | New | 1 | 7.229 | 8.987 | 5.228 | 6.984 |
| HUD | New | 2 | 7.762 | 8.733 | 5.755 | 6.731 |
| HUD | Before | 2 | 8.366 | 9.469 | 6.364 | 7.466 |
| HUD | Old | 2 | 8.225 | 9.429 | 6.224 | 7.428 |
| Heavy | Old | 1 | 13.431 | 17.617 | 11.428 | 15.615 |
| Heavy | Before | 1 | 13.224 | 16.905 | 11.222 | 14.902 |
| Heavy | New | 1 | 11.283 | 16.430 | 9.281 | 14.427 |
| Heavy | New | 2 | 11.232 | 16.468 | 9.230 | 14.466 |
| Heavy | Before | 2 | 14.203 | 17.263 | 12.201 | 15.260 |
| Heavy | Old | 2 | 14.589 | 18.269 | 12.588 | 16.267 |

The earlier forced-full-redraw results in GameStressResults.json remain historical data. They are not directly comparable to Game-mode results because their workload redraws the parent and every control continuously. The interrupted Dirty-mode diagnostic also animated the parent and masked child invalidation savings; it is not used for the comparison above.

## Validation and backup

- ObjectRegression.lua passed 1,680,764 checks, including RGB parity, callbacks, cache churn and repeated disposal.
- RedrawRegression.lua passed 38 targeted native paint-count and behavior checks.
- ListStress.lua --integration-only passed native input capture, radio navigation, panel cancellation, resizing, popup positioning, commit/cancel and shutdown.
- The complete pre-optimization Scripts tree is preserved, with hashes verified, in Backups/UI-before-redraw-optimization/Scripts. That is the Before implementation measured above.

## Repeat

Run GameStress.ps1 -Mode Game with PowerShell 7 for all twelve isolated trials. The aggregate result is GameStress-Game-Results.json; each trial also has its own JSON file. -Mode Full retains the forced-full-redraw workload. -Mode Dirty retains the parent-refresh diagnostic. Running a mode again replaces that mode's result files.
