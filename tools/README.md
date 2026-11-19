# Development tools

These tools are explicitly invoked for development. They are not loaded by the
production entry, do not change Widget/layout contracts, and do not add a Define
content entry point.

## Extension metadata

`generate_meta.py` derives package/type hints from the three owning catalogs and
host-selected builtins. `--check` verifies the committed `meta/elxosc.lua`;
repeatable `--declarations` composes extension JSON descriptors, checking names,
named type intersections and same-name conflicts before writing `--output`.
Generated metadata is editor input only. Setup and a typed payload example are
documented in [meta/README.md](../meta/README.md).
It declares `elxosc.meta.Builtins` table members for scope functions and the two
default class factories, without adding editor globals or implicit component exports.

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

`hover_driver.py` validates one shared direct-pointer workload on bare LuaJIT and
an isolated real host. It uses the production `MpFrameClock → Scheduler → App`
pipeline: a scoped mp boundary supplies logical time and requested timer delivery,
without replacing Scheduler state or manually duplicating render phases.

```text
uv run --group test python tools/hover_driver.py --frames 16 --adapter both --output tmp/hover-driver.json
uv run --group test python tools/hover_driver.py --scenes playing burst --frames 64 --adapter lua --output tmp/hover-lua.json
```

The versioned scenes cover paused fixed/varying time labels, playing/stationary
state updates, burst, clean frames, nested data, viewport/font replacement and
preview capability/leave. The two adapters share composition, state, event order
and logical frames. Both encode ASS; only the host submits real overlays and runs
an independent final `compute_bounds`. Both use the same estimate fallback at the
measurement boundary. Native text request record/replay and paced visible frames
are separate follow-up capabilities. Logical 240Hz timestamps are not measured FPS.

This command publishes behavior evidence, without performance timings: per-frame
ASS, ordered regions, hit paths/local points, dispatch/capture, player snapshots,
Tooltip/prepared text and actual draw positions/rows, preview actions, dirty/build/
layout/prepare/paint/present counts and enabled sections. It checks pointer/state/
requested timer conservation and compares normalized outputs. Heavy oracle work
is deliberately outside any future timed mode. CLI reports contain source/trace/
behavior/font hashes and runtime identity; dependencies changing during a run fail.

Native mouse/media observers and key callbacks are isolated only in the staged
driver. Input section/mouse-area policy and production frame/presenter deduplication
still run. This is not proof of native input delivery latency or key binding routing.
State updates precede pointer dispatch and the frame build, so a capability change
can dispatch once through the previous callback before that build clears it; the
oracle preserves this existing ordering.

`--frames` is bounded to 0–512, `--timeout` to 0.1–60 seconds, and JSON reports to
64 MiB. Timers, observer/event registrations, active sections, root/clock state and
owned overlay IDs are checked after shutdown; boundary slots and instance hooks
are restored on failure. The fixture exits via owned process cleanup. `--host` or
`ELXOSC_MPV_BINARY` selects the executable; local defaults come from `project.conf`.
Use `test/test_hover_driver.py` and `test/real_host/test_hover_driver_real.py` for
the related behavior/timeout/real renderer regressions.

`benchmark_player_hover.lua` investigates the offline Lua path;
`benchmark_real_player_hover.py` and `player_hover_probe.lua` measure real-player
input through ASS submission. Run the host probe separately from input tests and
memory probes because they share the physical mouse:

```text
uv run --group test python tools/benchmark_real_player_hover.py --seconds 4 --output tmp/player-hover.json
uv run --group test python tools/benchmark_real_player_hover.py --rates 240 --modes observe --debug true --seconds 4 --output tmp/player-hover-debug.json
```

The tool generates H.264 media with ffmpeg and supports 60/240 Hz input, pause/play
and debug toggles. Windows moves target a fixture-owned native window; only temporary
staging loads the probe. Production uses the `mouse-pos` observer; `mouse_move` is a
staging-only forced-binding experiment, not a replacement production input mode.
`--host` or `ELXOSC_MPV_BINARY` selects the executable.

Latency ends at the first ASS submission for each input sequence; repeated paints
from playback do not count as new input latency. Dirty counts include all frames.
Input and OS-move timing use the same monotonic clock; p50/p95 use nearest-rank.
The report records actual input rate, received events, tooltip submissions and
frame phases. It does not measure libass pixels, scan-out, external thumbfast or
ModernX. Short samples and probe overhead cannot establish universal frame rates.

The real hover trace records local prepare separately from layout (exclusive
timings), native text-call deltas and cache hits per frame. JSON distributions
include p50/p95/p99. Native shaping, cache work and ASS encoding remain synchronous;
moving measurement out of paint is a phase contract, not a throughput guarantee.
The probe also records each hidden native request's elapsed time, complete-frame
native counts, unique labels, input coalescing, ASS event/payload sizes, generations
and hashes of staged sources. `--warmup`, `--label-mode fixed`, `--milliseconds`,
`--cold`, `--font`, `--resize WIDTHxHEIGHT`, and `--scale` select text/environment
workloads. `--offline` disables native only in staging as a same-code estimate
control; `--thumbfast` uses a protocol peer, without thumbnail decoding.
`--title` supplies a generated long-media-title workload. A `--cold` refresh clears
the layout's result cache after warmup; it does not cool the host's font cache.

```text
uv run --group test python tools/benchmark_real_player_hover.py --warmup 3 --seconds 8 --rates 240 --modes observe --playback paused --milliseconds --cold --output tmp/hover-cold.json
```

Selected historical data:

- [Real-player scenes](../dev/benchmark/player-hover-real-2026-11-05.json)
- [Debug supplement](../dev/benchmark/player-hover-real-debug-2026-11-05.json)

Use each artifact's source version and environment when interpreting it. Playback
can rebuild the Main provider chain and refresh layout/input regions; compare the
same real scenes after an optimization rather than inferring performance from
paused or offline output.

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

Executable defaults come from `project.conf`. Selected historical reports keep
their original source and sampling scope:

- [Framework and ASS baseline](../dev/benchmark/framework-ass-baseline-2026-11-06.md)
- [Matching regression comparison](../dev/benchmark/framework-regression-2026-11-06.md)
- [ASS calibration](../dev/measure/ass-measure-2026-11-06.md)
- [Persistent measurement instance calibration](../dev/measure/ass-measure-reuse-2026-11-06.md)

These artifacts are references, not acceptance results for the current checkout.
Ordinary run results belong in local planning records; shared reports must explain
their method, versions and limitations.

`gen_font_glyphs.py` generates glyph metadata from the bundled font.

## Memory investigation

```text
luajit tools/investigate_memory.lua tmp/memory-lua.json
luajit tools/investigate_memory.lua tmp/memory-legacy.json tmp/player-context-legacy.txt
uv run --group test python tools/investigate_memory.py --host /path/to/mpvnet.com --seconds 60 --output tmp/memory-host.json
uv run --group test python tools/investigate_memory.py --host /path/to/mpvnet.com --seconds 60 --cases current_visible_no_present,ass_static,ass_dynamic,current_visible --output tmp/memory-controls.json
```

The optional Lua input is a saved `player/src/context.lua` revision, loaded
only in the fresh probe process. Five batches track weak references after two
full collections for snapshots/views, ordinary instances, dynamic classes, live
store replacement, Main reconciliation and mount/dispose. Windows also records
the probe process's private bytes/working set after GC. Batch heap includes
JIT metadata and weak-table capacity; it is not cumulative allocation. Cases
share a process, so retained objects from earlier cases affect later baselines.

The Windows host driver generates 720p/60 H.264 video and uses the existing isolated
fixture and owned window process. Default cases compare no UI, old/current snapshot
module with hidden Main and continuous display. Demo/debug are off. Only staging
enables the entry, suppresses activity after explicitly hiding Main, or disables
AutoHide for continuous display; every sample verifies visibility. It records
normal Lua heap plus initial/final full-GC samples, a 128-slot weak-reference ring,
private bytes and working set separately. Additional controls keep Main's Lua
build/layout/paint while suppressing ASS submission, or submit a simple static/
changing ASS label at 60 Hz without the framework. Final samples stop presentation,
then shut down App, each with a five-second wait and full GC; these are separate
from the measured interval's delta. `memory_host_probe.lua` is never loaded
by production. The old case replaces only the snapshot module, keeping all other
code and dependencies equal; it is not a historical full-application benchmark.

Run alone: these cases and real-host input tests share the physical mouse. Reports
retain versions, source hashes and finite samples; no user media is needed. Short
runs can identify retained Lua objects but cannot prove absence of long-term
native leaks. Process memory also includes decoder, GPU and libass allocations.
`--collect-each-sample` adds an isolated full-GC control for allocation high-water
growth; it is a diagnostic intervention and does not change production GC policy.
