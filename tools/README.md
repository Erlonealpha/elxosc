# Development tools

These tools are explicitly invoked for development. They are not loaded by the
production entry, do not change Widget/layout contracts, and do not add a Define
content entry point.

## ASS measurement

The general host utility accepts already encoded ASS without report metadata:

```lua
local measure_mod = require 'host.ass_measure'
local service = measure_mod.AssMeasure({ res_x = 640, res_y = 360 })
local raw, err, kind = service:measure(ass_data)
local removed, cleanup_error = service:dispose()
```

It fixes and floors resolution at initialization, allocates one private hidden overlay
and reuses the native command table. `raw` is the host table unchanged, including `{}`
for an empty image; failures return nil/error/kind. Callers own disposal in both success
and exception paths. `dispose()` is idempotent after success; failed removal retains
the ID for an explicit cleanup retry but closes measurement. It does not cache bounds,
scan trusted ASS for NUL or produce report objects. Generators and external input
adapters validate their content. Existing AssCanvas/Paragraph output can be passed
directly; no Widget mounting or Record replay is required for ordinary measurement.

Run from the repository root with the test dependencies and a working mpv/mpv.net:

```text
uv run --group test python tools/ass_measure.py --output tmp/ass-measure.json --markdown tmp/ass-measure.md
uv run --group test python tools/ass_measure.py --input my-samples.json --repeats 3 --output tmp/custom-bounds.json
```

`--host` or `ELXOSC_MPV_BINARY` selects the executable. The tool uses the real-host
fixture's temporary config and ownership-bounded cleanup. It loads only its driver,
disables built-in OSC, and supplies the repository font directory. It waits for a
nonzero OSD viewport stable for 250 ms, rejects viewport changes during sampling,
and never retries a timed-out measurement. `--timeout` defaults to 5 seconds per
wait/IPC operation (maximum 60); fixture startup and cleanup have their own bounds.

Omitting `--input` selects six Widget/Element/RenderObject samples: Latin text, CJK
text, Material Symbols play icon, paint-only scaled text, clipped text and a composed
row. `ass_measure_samples.lua` paints to RecordCanvas, replays those drawing calls
into AssCanvas at (50, 50), and retains the logical box and operation names.

Custom input schema v1:

```json
{
  "schema_version": 1,
  "scene": "my-text",
  "scene_version": 1,
  "samples": [
    {
      "name": "label",
      "data": "{\\an7\\pos(50,50)\\fs24\\fnArial\\bord0}Label",
      "res_x": 640,
      "res_y": 360,
      "metadata": {"font_family": "Arial", "font_size": 24}
    }
  ]
}
```

Names must be unique and nonempty; 1–64 samples are allowed. `data` is a NUL-free
static `ass-events` payload and may be empty. Resolution is an integer in 1–16384;
scene version is a positive integer. Optional `metadata` and `logical` evidence
are retained without interpreting them as host metrics. Built-in requests use
640×360; actual OSD dimensions are recorded separately.

The CLI driver reuses one hidden measurement instance per resolution for the entire
batch, then disposes all instances. `tools/ass_measure_report.lua` audits raw bounds
and converts them to schema v1; `lifecycle` records instance/removal counts. Results distinguish `ok`,
`empty`, `unavailable`, and `error`; cleanup errors prevent success. Empty host
tables omit bounds. Nonempty bounds have `left/top/right/bottom/width/height` in ASS
request coordinates. The report keeps all repeats, stability, payload/request
SHA-256, source commit, font-file hash, platform, actual OSD, mpv/FFmpeg/Lua versions,
available libass version logs and font fallback selection. JSON is the full artifact;
Markdown is a compact table.

Exit code is 0 for stable successful/empty measurements, 1 for invalid input,
host/command/timeout/cleanup errors or unstable results, and 2 for an unavailable
host/API. Failure reports contain no fabricated bounds. A missing real-host test
executable skips; the CLI always emits an explicit unavailable report instead.

Bounds describe renderer image rectangles and may include padding. They do not
prove precise glyph ink, baseline, ascent/descent, optical centering or scan-out.
Logical boxes and painted host bounds are deliberately compared as different
quantities. Font fallback and actual viewport affect measurements. The service
does not supply runtime text measurement or update the framework estimator.

## Hover probes

`benchmark_player_hover.lua` investigates the offline Lua path;
`benchmark_real_player_hover.py` and `player_hover_probe.lua` measure real-player
input through ASS submission. Their scenarios, reports and endpoint limits are in
[TESTING.md](../dev/design/TESTING.md).

## Framework and measurement benchmark

```text
uv run --group test python tools/benchmark.py --output tmp/core.json --markdown tmp/core.md
uv run --group test python tools/benchmark.py --baseline tmp/core.json --output tmp/core-comparison.json
uv run --group test python tools/benchmark.py --host-measure --host /path/to/mpv --output tmp/core-host.json
```

`benchmark_core.lua` runs on bare LuaJIT without `mp` or a stub. Fixed small, 64-level
deep, 128-child and default Main scenes measure description, mount/dispose, reconcile,
State dirty rebuild/finalize, Element/Render traversal, dirty/clean layout, dirty/cached
regions, Record/ASS paint and payload concatenation. Every iteration compares direct
ASS with replayed Record operations byte for byte outside timing. Dirty layout marks
all nodes before timing. These are phase samples, not a single production-frame sum.

Defaults are 100 measured iterations, 30 warmup iterations and three fresh LuaJIT
processes. JSON retains each round's mean/p50/p95/max; displayed p50/p95 are medians
of per-round percentiles. Comparisons require matching runtime/platform/JIT/clock,
viewport, scenario version, sampling and output hash. Ratios are descriptive with no
automatic threshold; shared machine load and GC/JIT noise must be considered.

`--host-measure` supplements the core result using the isolated fixture. It reads
the original service from Git (`--legacy-ref`, default `46bc4a2`) without checking out
or editing it, compares legacy/update/native-reuse for identical and changed ASS,
and checks bounds equivalence before timing. Cold requests, initialization and disposal
are separate; timed hot iterations include native/libass but no IPC or result cache.
Host order rotates across rounds. Live heap delta is not cumulative allocation.
Host default is 50 iterations/10 warmup per round. The host must be available;
the runner reports failure instead of silently replacing it with a stub.

`benchmark_animation.lua` adds a simulated 240 Hz clock/controller, paint-only offset
animation and an experimental cached Record replay for each scene. It verifies zero
layout frames and exact ASS equivalence. The cached run avoids render-tree traversal
but still encodes ASS every frame; it neither implements RepaintBoundary nor changes
the production renderer. Ticker/full-paint/replay costs and dirty counts are reported
separately. Host changed payloads vary both placement and text size; empty changed
payloads stay empty. Timed batches use libass warn logging, with font/version evidence
collected separately by the calibration CLI.

Executable defaults come from `project.conf`. Reports and statistical limitations
are documented in [TESTING.md](../dev/design/TESTING.md).

`gen_font_glyphs.py` generates glyph metadata from the bundled font.
