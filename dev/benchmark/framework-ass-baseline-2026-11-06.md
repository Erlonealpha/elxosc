# Framework and ASS benchmark

Generated: 2026-11-05T19:41:10.885269+00:00

Core values are medians of per-round p50 values, in milliseconds.

| Scene | Nodes (Element/Render) | Reconcile | Dirty rebuild | Dirty layout | ASS paint |
| --- | --- | --- | --- | --- | --- |
| small | 12/7 | 0.1044 | 0.1023 | 0.0404 | 0.0997 |
| deep | 67/65 | 0.3695 | 0.3399 | 0.3498 | 0.1227 |
| wide | 258/129 | 3.5200 | 3.3551 | 1.0049 | 1.8032 |
| player | 313/175 | 6.4452 | 6.3107 | 1.9282 | 2.8073 |

Paint-only animation at simulated 240 Hz; cached Record replay is a staging experiment.

| Scene | Ticker | Full paint | Record replay | Layout frames |
| --- | --- | --- | --- | --- |
| small | 0.0090 | 0.1532 | 0.0708 | 0 |
| deep | 0.0120 | 0.1978 | 0.0152 | 0 |
| wide | 0.0250 | 2.5153 | 0.7516 | 0 |
| player | 0.0273 | 2.2732 | 0.9181 | 0 |

Host values include synchronous native/libass work; no timed IPC.

| Sample | Payload | Legacy | Overlay update | Native reuse | Reuse/legacy |
| --- | --- | --- | --- | --- | --- |
| text-latin | same | 17.7647 | 0.0149 | 0.0140 | 0.001 |
| text-latin | changed | 17.2459 | 0.0154 | 0.0148 | 0.001 |
| text-cjk | same | 17.9012 | 0.0120 | 0.0110 | 0.001 |
| text-cjk | changed | 17.9328 | 0.0119 | 0.0112 | 0.001 |
| icon-play | same | 16.1411 | 0.0130 | 0.0124 | 0.001 |
| icon-play | changed | 16.0007 | 0.0132 | 0.0127 | 0.001 |
| scaled-text | same | 16.4550 | 0.0119 | 0.0113 | 0.001 |
| scaled-text | changed | 15.8936 | 0.0120 | 0.0114 | 0.001 |
| clipped-text | same | 15.8650 | 0.0180 | 0.0170 | 0.001 |
| clipped-text | changed | 16.1805 | 0.0182 | 0.0173 | 0.001 |
| composed-row | same | 16.1573 | 0.0187 | 0.0177 | 0.001 |
| composed-row | changed | 15.9283 | 0.0183 | 0.0173 | 0.001 |
| empty | same | 11.2780 | 0.0043 | 0.0036 | 0.000 |
| empty | changed | 11.1761 | 0.0048 | 0.0033 | 0.000 |

Record replay and direct ASS bytes are checked each iteration; host bounds are checked before timings.
CPU/OS load, JIT, GC and libass caches affect the distribution. No cross-machine budget is asserted.
