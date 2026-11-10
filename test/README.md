# elxosc test-suite

Smoke/regression tests for the elxosc framework core, run by the pinned
[mpv-luatest](../mpv-luatest/README.md) development dependency. They use bare
**LuaJIT**: project modules load by bare names from this repository and
`elxlibs.*` from the sibling `elxlib`, without its native `init.lua` setup.

## Running

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

## Static analysis

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

Current baseline (2026-11-10): **2540 Lua checks** through both the project
adapter and direct dependency CLI; project runner regression **16 passed**;
`emmylua_check . --warnings-as-errors`: **No issues found**. The historical ASS
benchmark source is patched only for the current `std.class.new` signature in
its isolated fixture. The project Python suite is **47 passed**, with no skips
(real-host 17, runner 16, measurement CLI 11, benchmark CLI 3).
The initialized user-selected dependency checkout is `307bcc3`; the existing
gitlink change is preserved.
Framework commit `66e921c` passes checks in an independent clone: **41 Lua
checks**, the example's **2 checks**, **30 CLI regressions**, and zero EmmyLua
diagnostics.
Commands and scope are recorded in
[`dev/design/TESTING.md`](../dev/design/TESTING.md). The input contract in
[`dev/design/INPUT.md`](../dev/design/INPUT.md) is partially implemented through
root-space regions, per-rectangle sections, capture cleanup, structured pointer/key
values and dispatch results; the PlayerContext 6.3 contracts are implemented. R1/R2
now cover SlotSpec/Contribution assembly, transactional Define payloads and mount-only
WidgetTree behavior; the N3 Page/Route/Navigator slice is covered by the navigation regression
file, while multi-overlay contracts remain planned.

## Real host (Python + uv, first stage)

`test/real_host/` starts a **real** mpv.net/mpv process in a temporary, empty
`--config-dir` and queries its JSON IPC endpoint. It stages and loads the elxosc
directory package (rather than a standalone `main.lua`), with `--load-scripts=no`
to avoid loading the staged scripts twice and `--osc=no` to prevent the built-in
OSC from intercepting controller input. The fixture owns the complete
process tree: it sends IPC `quit` first, then uses a Windows Job Object (or a
POSIX process group) as a bounded fallback. It never searches for or kills
processes by image name. Existing Lua host tests above still use an `mp` stub;
these Python tests do not.

From this repository root:

```sh
uv run --group test python -m pytest -q test/real_host
# or, if pytest is already installed in your Python:
python -m pytest -q test/real_host
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
back `osd-dimensions`. The N3 demo test opens Page/Popup routes, sends real ESC
keypresses, checks results and retained State, then verifies that home releases ESC
to a separate host-script binding. The button fixture also sends real mpv `mouse` commands
through an isolated user `input.conf` to verify interactive double-click capture
and background fullscreen passthrough. These tests are not pixel-level OSD checks.
The Demo launcher test loads generated paused media and clicks the injected right
control and Close Demo button. On Windows, cursor input is restricted to a visible
window in the isolated process tree; it restores the cursor after the test and waits
for Main's input sections to become active. Button edges use mpv IPC keydown/keyup
at that native cursor position, exercising section-area selection and production
dispatch without relying on global desktop click injection. Other hosts use mpv
mouse/key commands. Native desktop button acceptance remains a manual check.
The thumbfast test loads a temporary protocol peer, keeps the native pointer
stationary over the timeline until AutoHide, checks one clear, and checks recovery
on a new move. It verifies the production transport and lifecycle; frame geometry
and ASS output are covered by Lua tests, without claiming external decoder pixels.

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
is loaded into the workspace entry. Commands, environment, results and the ASS
submission endpoint are documented in
[`dev/design/TESTING.md`](../dev/design/TESTING.md#真实播放器-timeline-hover-benchmark2026-11-05).

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

Nothing here is loaded by mpv: the directory has no `main.lua`, so mpv's script
auto-loader ignores it.
