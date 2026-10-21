# wxLuma active UI stress comparison

Measured on the current Windows workstation on October 20, 2026. Values are native UI paint-batch completion rates, not monitor-presented or GPU game frame rates.

## Method

- Target: 120 Hz, or 8.333 ms per logical frame.
- Fresh process for every trial; old/new order reversed in the second round.
- Each trial: 120 warmup frames and 600 measured frames; 1,200 measured frames per implementation per workload.
- Same 1360 x 940 client area, artwork, values, callbacks and scripted inputs.
- HUD: 22 top-level widget instances, one 10,000-row list and 120 moving background rectangles.
- Heavy: 90 top-level widget instances, four 10,000-row lists and 600 moving background rectangles. Native child controls add further work.
- Lists scroll continuously; meters, sliders and scrollbars change every frame. Scripted actions and text commits occur every 12 frames; the panel resizes every 30 frames.
- Every frame includes a fixed 2 ms synthetic CPU game-logic budget. This is a time reservation, not a full game simulation.
- The complete background and all top-level widgets are explicitly invalidated and synchronously painted every frame, including otherwise static controls. This is a demanding full-redraw workload.
- QueryPerformanceCounter-backed clock at 10 MHz. The benchmark temporarily requests 1 ms timer resolution and restores it on exit.
- Draw wrappers capture native paint errors. Each frame verifies every requested top-level control paint completed; callback counts and final selection match between versions.
- Old code comes from the separate pre-conversion backup, with ListPlain used for both ordinary and dropdown lists. New code uses the shared actual/decoy/metatable implementation and the corrected skin cache.

## Results

| Workload | Old mean paint batches/s | New mean paint batches/s | New throughput change | Old mean median work ms | New mean median work ms |
|---|---:|---:|---:|---:|---:|
| HUD | 98.16 | 98.08 | -0.08% | 9.833 | 9.853 |
| Heavy | 40.31 | 37.84 | -6.13% | 23.396 | 24.191 |

These are arithmetic means of two trial rates and two trial medians; they are not pooled percentiles. The HUD difference is within observed run-to-run variation. Heavy-workload throughput was about 6.1% lower for the object version in this run.

| Workload | Version | Round | Paint batches/s | Work median ms | Work p95 ms | Work p99 ms | UI-only median ms | Frames over 8.333 ms |
|---|---|---:|---:|---:|---:|---:|---:|---:|
| HUD | Old | 1 | 100.63 | 9.555 | 12.154 | 14.654 | 7.553 | 600/600 |
| HUD | New | 1 | 100.17 | 9.639 | 11.978 | 13.853 | 7.637 | 600/600 |
| HUD | New | 2 | 96.00 | 10.068 | 12.725 | 14.211 | 8.066 | 600/600 |
| HUD | Old | 2 | 95.69 | 10.112 | 12.758 | 15.027 | 8.110 | 600/600 |
| Heavy | Old | 1 | 40.52 | 23.279 | 34.147 | 46.440 | 21.276 | 600/600 |
| Heavy | New | 1 | 36.76 | 25.177 | 38.785 | 44.096 | 23.175 | 600/600 |
| Heavy | New | 2 | 38.91 | 23.205 | 39.342 | 51.902 | 21.203 | 600/600 |
| Heavy | Old | 2 | 40.09 | 23.512 | 33.419 | 47.293 | 21.510 | 600/600 |

Neither version met the 120 Hz budget under these forced full-redraw workloads. The object pattern had little effect on the HUD trial and a measurable cost in the heavy trial. These measurements do not isolate the dominant native rendering cost and do not establish a universal maximum frame rate. Updating only dirty controls, using smaller UI regions or batching drawing would require separate measurements.

## Regression fixes and validation

- Corrected a conversion-induced ControlSkin local-variable shadowing error: natural bitmap allocation dimensions must remain separate from optional requested dimensions used by cache metadata.
- Corrected a conversion-induced Dropdown shadowing error: popup placement uses the field height independently of the popup height.
- Pre-fix files are preserved in Backups/GameStress-before-skin-fix. The original pre-conversion backup remains unchanged.
- ObjectRegression.lua passed 1,680,764 checks, including natural/scaled cache churn, callback parity, RGB rendering and repeated disposal.
- ListStress.lua --integration-only passed native capture, radio navigation, panel cancellation, resizing, popup anchoring, commit/cancel and close checks.

## Repeat

Run GameStress.ps1 with PowerShell 7 to repeat all eight trials. It writes GameStressResults.json and individual trial JSON files beside the test. Framework modules and the production launcher are not modified by the benchmark.
