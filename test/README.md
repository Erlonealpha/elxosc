# elxosc test-suite

Smoke/regression tests for the elxosc framework core, run by the pinned
[mpv-luatest](../mpv-luatest/README.md) development dependency. They use bare
**LuaJIT**: framework modules load as `src.*` from `lib/src/`, public collectors
load from `lib/*.lua`, and player/Define/host modules load from the repository root.
The sibling `elxlib` supplies `elxlibs.*`, without its native `init.lua` setup.

The isolated `real_host/test_ass_text_probe.py` captures ASS alignment spans with
production encoding, real viewport resize, font changes and virtual resolution.
It records raw data in ignored `tmp/ass-text-probe-*.json`, checks finite Latin
font-file references and keeps image bounds distinct from logical text size.
It starts no production App and is not a player hover benchmark.

## Running

The shared direct-pointer driver has focused Lua/Python regressions in
`test_hover_driver.lua` / `test_hover_driver.py`; the real renderer comparison is
`real_host/test_hover_driver_real.py`. It runs the same versioned scene through
production clock/scheduler/app phases, compares per-frame ASS/input/Tooltip/actions,
and verifies resource and process cleanup. The real-host scope is this one file;
it does not use the physical mouse or replace native binding tests. Driver CLI and
measurement limits are documented in [tools/README.md](../tools/README.md#hover-probes).
`test_hover_profiler.lua` covers nested/recursive scope accounting, multiple returns,
exceptions, bounded capacity and hook restoration. `test_hover_measure.py` checks
separate modes against validation and rejects unknown native replay requests.
The real-host fixture defaults to `quiet=True`; window minimization and focus
retention are separate from raster/behavior parity. App input tests use
`direct_input=True` and `DirectInput`, which serializes coordinates and events
into the staged production `MpInput`, acknowledges every event and avoids the
desktop cursor. Physical input tools must explicitly request `quiet=False`.

```sh
cd scripts/elxosc
git submodule update --init --recursive
luajit test/run.lua             # whole suite
luajit test/run.lua flutter_runtime/lifecycle # matching group/file components
luajit test/run.lua -v          # full file/section/success logs
uv run --group test python -m pytest -q test/test_runner.py # CLI regression tests
luajit mpv-luatest/run.lua --bootstrap test/bootstrap.lua # direct dependency CLI
```

Exit code is `0` when everything passes, `1` otherwise.

`test/run.lua` delegates to `mpv_luatest.suite`; `dependency.lua` locates the
root-level submodule and reports the initialization command when it is absent.
`support.lua` owns project/elxlib paths and `debug_msg`; `bootstrap.lua` configures
the primary `elxosc-input` section and legacy mouse persistence. The dependency
contains no project-specific adapter. `framework.lua`, `runner.lua`, and
`mp_stub.lua` are thin compatibility imports of its canonical module objects.
Core benchmark setup adds module paths without loading mp or the fake host.

The submodule URL is `https://github.com/Erlonealpha/mpv-luatest`. Publish the
recorded framework commit there before consumers initialize it. Upgrade the
submodule pointer after verifying the project suite, and commit that pointer
with the relevant adapter/documentation changes.

Discovery is automatic and sorted by relative path: `test_*.lua` files at the root
or recursively below directories starting with `test`. Other directories are ignored.
Each slash-separated filter component is a literal substring, with optional `test_`
prefix and `.lua` suffix. For example, `player/layout` selects
`test_player/test_layout.lua`; `flutter_runtime` selects the entire runtime group.
Both `-v filter` and `filter -v` work. Default output contains failures (with file,
section and test name) and the summary. `-h` shows usage; invalid options and empty
matches fail. Tests with failed assertions are never printed as successful.

The framework isolation test stages only lib and elxlib, with player/Define/mp
imports rejected, then mounts, paints text, dispatches input and disposes. Run
`uv run --group test python -m pytest -q test/test_framework_packages.py`.

## Static analysis

Check Lua formatting with `python tools/format_lua.py check`; it selects staged,
modified and untracked Lua files by default. Explicit paths select files or directories.
Formatter configuration, writing and checking are described in
[tools/README.md](../tools/README.md#lua-formatting).

The project is also checked with the EmmyLua analyzer; run it from the project
root so `.emmyrc.json` (library paths, `runtime.special.raise`, ...) applies:

```sh
emmylua_check .
```

`test_exports.lua` checks consumers annotated with canonical module types and
module/record/array intersections; Define tests cover standard descriptors,
local `import_as` packages, transactional rollback, and owned subscription cleanup.

Both gates are expected to be clean: `No issues found` and `ALL GOOD`.
The framework directories are meant to stay free of *all* diagnostics; the
test files disable the codes that stem from limits of the `std.class` model
(see the header in `test_widget.lua`).

Production analysis uses
`emmylua_check . --warnings-as-errors -i '**/tmp/**,**/meta/**,**/.plan/**'`; metadata generation
and editor acceptance are separate scopes. Runtime checks do not prove editor hints.

The isolated framework test checks initial require orders, catalog identity,
mount/paint/input/dispose and runtime source coverage. Module-loading tests reject
removed paths; Define tests cover explicit package construction/publication,
scoped loaders and the returning `require = import_as` alias without implicit
component injection. Testing strategy and evidence limits are in
[TESTING.md](../dev/design/TESTING.md). Actual run results belong in local planning
records and commit or handoff reports, without duplicating counts in this README.

## Real host (Python + uv)

`test/real_host/` starts a **real** mpv.net/mpv process in a temporary, empty
`--config-dir` and queries its JSON IPC endpoint. It stages and loads the elxosc
directory package (rather than a standalone `main.lua`), with `--load-scripts=no`
to avoid loading the staged scripts twice and `--osc=no` to prevent the built-in
OSC from intercepting controller input. The fixture owns the complete
process tree: it sends IPC `quit` first, then uses a Windows Job Object (or a
POSIX process group) as a bounded fallback. It never searches for or kills
processes by image name. Existing Lua host tests above still use an `mp` stub;
these Python tests do not.

Run real-host tests when changes affect behavior they cover, such as script loading,
presentation, input, Define wiring, or player integration. In most cases, select
only the affected files or cases. Documentation-only changes and changes without
relevant host impact do not need real-host tests. Avoid full real-host runs by
default; use the full suite when host impact is broad or cannot reasonably be
bounded, or when explicitly requested, and report why. Passed checks need not be
repeated without new changes, failures, or unresolved concerns.

From this repository root, for an extension-button change:

```sh
uv run --group test python -m pytest -q test/real_host/test_player_extensions.py
# or, if pytest is already installed in your Python:
python -m pytest -q test/real_host/test_player_extensions.py
```

`uv` resolves the declared pytest test dependency into the ignored local
`.venv` (the first run may need a package index). To use an already cached
dependency without network access, add `--offline` before `run`. Set
`ELXOSC_MPV_BINARY` to a full executable path (or a name on PATH) to select a
host explicitly; otherwise the search is `mpvnet.com`, `mpv.com`, `mpv.exe`.
When the workspace entry disables `demo_enabled`, set
`ELXOSC_TEST_DEMO_ENTRY=1` to enable that recognized switch only in the temporary
staged `main.lua`. The source file and Git index remain untouched; an unknown
entry pattern fails explicitly. Run without this option to test the workspace
entry as it stands, and report the two modes separately.
The isolated host creates a unique temporary IPC socket/named pipe, is stopped
after the test, and has no user scripts. A missing host executable reports
**SKIPPED** with a reason. Hosts that exit, IPC startup timeouts, and unexpected
command or assertion failures fail the test.

The suite also includes elxosc integration tests. It loads
`main.lua`, opens the injected Demo with `elxosc-demo-open`, sends `elxosc-demo`, checks that the host remains alive, and reads
back `osd-dimensions`. The navigation demo test opens Page/Popup routes, sends real ESC
keypresses, checks results and retained State, then verifies that home releases ESC
to a separate host-script binding. The button fixture sends real mpv `mouse`
commands and checks interactive double-click capture against a lower native
fallback section. The fallback records delivery without changing fullscreen.
This retains native section selection coverage; it does not prove every user's
input.conf precedence or desktop clicks. These tests are not pixel-level OSD checks.
The Demo launcher test loads generated paused media and clicks the injected right
control and Close Demo button. Demo, timeline drag, extension buttons and text
consumers send direct move/down/up events through a test-only bridge installed
in the staged App. The bridge isolates physical mouse observers and position
refresh, retains production activity/capture/dispatch and frame scheduling, and
confirms down before a drag move. It adds no production input API. Native section
and keyboard transport are independently checked; desktop acceptance remains manual.
The thumbfast test loads a temporary protocol peer, keeps the direct pointer
stationary over the timeline until AutoHide, checks one clear, and checks recovery
on a new move. It verifies the production transport and lifecycle; frame geometry
and ASS output are covered by Lua tests, without claiming external decoder pixels.

Text resize selects the owned video window and sets its restore rectangle outside
the virtual desktop with a nonactivating show mode. It waits for matching OSD
dimensions and retains real VO/libass. This path moves no cursor; its resized
window is offscreen instead of minimized. `WindowInput` rejects quiet processes
before touching desktop input. Screenshots and the explicitly native mouse
benchmark require a visible opt-in and are separate from automatic quiet tests.

`test_ass_measure.py` loads the standalone measurement driver and exercises the
host service with bundled fonts, repeat stability, custom JSON, clipping, empty
payloads, fixed-instance reuse/cleanup and resolution coordinates. It also verifies
the three benchmark strategies against real bounds. `test_ass_measure_cli.py` covers invalid
input, missing host and timeout reporting. CLI use and schema are in
[tools/README.md](../tools/README.md); reports are in
[dev/measure](../dev/measure/ass-measure-2026-11-06.md).

`test_benchmark_cli.py` runs the real four-scene core benchmark, checks no `mp` is
loaded, verifies output hashes and rejects incompatible baselines. Performance data
is produced separately by `tools/benchmark.py`; behavior tests do not assert speed.

The separate `tools/benchmark_real_player_hover.py` generates H.264 video with
ffmpeg and measures native Windows pointer moves through the production player,
frame loop and ASS presenter. It supports 60/240 Hz, pause/play, debug toggles and
a staging-only mouse_move experiment. Use `--output` to save statistics; no probe
is loaded into the workspace entry. Usage and the ASS submission endpoint are documented in
[tools/README.md](../tools/README.md#hover-probes); individual run environments
and results are recorded with their reports.

### Demo navigation

The default `demo_enabled` switch injects a right control next to pin and a shared
launcher in WindowLayer. Click the Demo control to open it; **Close Demo** disposes
the Demo, and reopening creates fresh State. From the mpv console:

```text
script-message elxosc-demo-open
script-message elxosc-demo page
script-message elxosc-demo popup
```

**Open Page** opens an opaque page; **Back with result** returns `Page: done`,
and ESC returns `Page: dismissed`. **Open Popup** creates a barrier and card;
**Confirm / Cancel** return `Popup: confirmed / cancelled`. Barrier click or ESC
returns `Popup: dismissed`; clicking empty card space keeps it open.

Home **Result / Returns** displays the latest result and completion count. Change
the original counter before opening a route to check retained home State. Home
releases ESC to the host. Repeated open commands while a route is open are ignored.
`elxosc-demo` without an argument runs the counter example. The observable
`user-data/elxosc-demo-route`, `elxosc-demo-result` and `elxosc-demo-returns` values
support lifecycle checks; disposal releases message handlers and result listeners.
These operations are reproducible checks, without recording a particular run's result.

## Layout

| File | Contents |
| --- | --- |
| `run.lua`, `dependency.lua` | Project entry and pinned dependency lookup |
| `runner.lua`, `framework.lua`, `mp_stub.lua` | Compatibility imports; shared implementation lives in mpv-luatest |
| `test_runner.py` | Real CLI subprocess checks: groups, filters, verbosity, failures, paths with spaces |
| `test_flutter_runtime/` | `core`, `binding`, `lifecycle`, `keys`, `paint`, `host_pipeline` runtime groups |
| `runtime_support.lua` | Mounted State probe and deterministic clocks for runtime tests |
| `support.lua`, `bootstrap.lua` | Project/elxlib paths, debug global and project stub configuration |
| `test_foundation.lua` | Geometry value types, colour, paint, path, canvas contract |
| `test_text.lua` | Options-only `TextStyle`/`TextPaint`, copying and invalid boundaries; default/overridden logical line advance and wrapping |
| `test_text_service.lua` | Native line spans, bounded cache, scope/generation, Tooltip invalidation and App session cleanup/recovery |
| `test_text_consumers.lua` | Ordered local preparation, final-label coalescing, no paint measurement, bounded content hits and time reservations |
| `test_multiline_text.lua` | Original byte ranges, whitespace, finite clusters, line limits/ellipsis, ASS row advances and bounded Tooltip preparation |
| `test_scheduler.lua` | Frame clock contract, the two-phase scheduler, tickers |
| `test_animation.lua` | Matrix2D, paint-only OffsetBox/TransformBox, layout scale, curves/tweens, controllers and State resource lifecycle |
| `test_layout.lua` | Constraints, fitted/finite scale boxes, crop/input mapping, owner driving, paint + hit test |
| `test_input.lua` | Root-space regions, transform clipping, structured dispatch, gesture dispatch, hover and capture |
| `test_widget.lua` | Widget -> element -> render object, reuse, state rebuilds, constrained text anchors, paint-only updates and scale boxes |
| `test_button_contract.lua` | Button options/style immutability and PointerEvent/KeyEvent construction |
| `test_icon.lua` | Icon options, nominal box/center anchor, optical offset, font/style propagation and aggregate identity |
| `test_bind.lua` | Inherited widgets and immutable SlotSpec/Contribution assembly |
| `test_player_context.lua` | Provider lookup, immutable snapshot views, Store subscriptions and State lifecycle |
| `test_define.lua` | Sandbox env primitives, transactional module/contribution publish and the define protocol |
| `test_export.lua` | Source snapshots/selection, raw identity, sparse arrays, conflicts, atomic publication and repeated collection |
| `test_module_loading.lua` | Canonical aliases, owning collectors, exact multi-level imports, protocol rollback and stable builtins |
| `test_dsl.lua` | The define DSL factories: `new_widget` / `new_state` / `builtins` |
| `test_host_define.lua` | `MpDefine`: the `mp` module, message routing, the window (`mp` stubbed) |
| `test_host_player_context.lua` | mpv property bridge, observer disposal and Define player updates (`mp` stubbed) |
| `test_host_app.lua` | `App`: frame clock, overlay, input areas/capture, demo output and the define window (`mp` stubbed) |
| `test_demo_navigation.lua` | Mounted demo buttons, retained home State, results, popup card/barrier hit testing, ESC and cleanup |
| `test_navigation.lua` | Page/Route reconciliation, push/pop results, Popup barrier and ESC |
| `test_presentation.lua` | RegionSnapshot isolation, ASS event boundaries, presenter retry/cache, clear and shutdown |
| `test_ass.lua` | ASS colour/anchor encoding, axis scaling, clipping, drawing emission, visual offsets and estimating text layout |
| `constraints_examples.lua` | Fixtures: the 29 doc examples as elxosc widget trees (not a test file) |
| `test_constraints_examples.lua` | The 29 `flutter/constraints` examples: raw `ass-events` vs expected |
| `test_layering.lua` | Guard: only `host/` (and the entry points) may require `mp` |

The real-host suite also includes `test_text_anchor.py`, `test_scale.py` and
`test_transform.py`, which
stage the corresponding Lua fixtures and ask the actual host/libass to compute
non-empty bounds for the text, Icon and finite-scale events. It checks ASS output
and host consumption; it does not claim exact glyph ink metrics or optical-centre proof.

`real_host/test_multiline_text.py` covers native line provenance, two/three-row
advances across all anchors/scales, blank rows, wrapping/ellipsis and constrained
clipping. It records per-row events, payload bytes and separate cold/hot layout,
paint and compute_bounds timings in ignored tmp/multiline-ATL-3.json. These timings
measure the isolated fixture rather than whole player frames or display latency.
The test-only multiline_preview.lua builds review pages with explicit expectations,
solid constraint boxes, dashed natural paragraph bounds, expected row centers and
paint anchors/offsets. It compares visible/clip/ellipsis under identical constraints.
Screenshots in tmp/multiline-ATL-3.png and tmp/multiline-ATL-3-overflow.png include
these guides; the guides represent logical layout rather than glyph ink or baselines.

`real_host/test_text_cache_endurance.py` runs 120 seconds of unique short/long
labels, sampling both cache limits and Lua heap while replacing environments. It
checks old-layout collection, a second App's independent lifetime and owned IDs.
The workload target and actual rate are separate; full GC samples and bounded
retention do not prove long-term native process memory stability.

Nothing here is loaded by mpv: the directory has no `main.lua`, so mpv's script
auto-loader ignores it.
