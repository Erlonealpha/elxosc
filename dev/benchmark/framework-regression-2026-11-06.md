# Framework and ASS benchmark

Generated: 2026-11-05T19:43:36.060788+00:00

Core values are medians of per-round p50 values, in milliseconds.

| Scene | Nodes (Element/Render) | Reconcile | Dirty rebuild | Dirty layout | ASS paint |
| --- | --- | --- | --- | --- | --- |
| small | 12/7 | 0.1006 | 0.0974 | 0.0403 | 0.1038 |
| deep | 67/65 | 0.4514 | 0.4215 | 0.4134 | 0.1362 |
| wide | 258/129 | 3.6461 | 3.5932 | 1.0095 | 1.7067 |
| player | 313/175 | 5.9920 | 5.5336 | 1.8633 | 2.5116 |

Paint-only animation at simulated 240 Hz; cached Record replay is a staging experiment.

| Scene | Ticker | Full paint | Record replay | Layout frames |
| --- | --- | --- | --- | --- |
| small | 0.0085 | 0.1580 | 0.0683 | 0 |
| deep | 0.0097 | 0.1540 | 0.0127 | 0 |
| wide | 0.0175 | 2.0773 | 0.6747 | 0 |
| player | 0.0194 | 1.8335 | 0.7640 | 0 |

Comparison ratios are descriptive; full phase/round details are in JSON.

Record replay and direct ASS bytes are checked each iteration; host bounds are checked before timings.
CPU/OS load, JIT, GC and libass caches affect the distribution. No cross-machine budget is asserted.
