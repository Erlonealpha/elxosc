# elxosc test-suite

Standalone smoke/regression tests for the elxosc framework core. They run on a
bare **LuaJIT** -- mpv is not needed: `elxosc.*` is loaded straight from this
repository and `elxlibs.*` from the sibling `elxlib` checkout, without running
elxlib's real `init.lua` (no ffi / DLL-path setup).

## Running

```sh
cd scripts/elxosc
luajit test/run.lua             # whole suite
luajit test/run.lua flutter_runtime/lifecycle # matching group/file components
luajit test/run.lua -v          # full file/section/success logs
uv run --group test python -m pytest -q test/test_runner.py # CLI regression tests
```

Exit code is `0` when everything passes, `1` otherwise.

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

Both gates are expected to be clean: `No issues found` and `ALL GOOD`.
The framework directories are meant to stay free of *all* diagnostics; the
test files disable the codes that stem from limits of the `std.class` model
(see the header in `test_widget.lua`).

Current baseline (2026-10-27): **1682 Lua checks**, including **252 runtime checks**;
runner CLI regression: **14 passed**. Production EmmyLua checks are clean with
`--ignore 'tmp/**'` (local ignored drafts otherwise produce 18 duplicate-type/field
warnings). Real-host: **10 passed** in an isolated source copy with the entry enabled;
the user's disabled workspace entry gives **8 passed, 2 failed**. Commands and scope are recorded in
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
to avoid loading the staged scripts twice. The fixture owns the complete
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
The isolated host creates a unique temporary IPC socket/named pipe, is stopped
after the test, and has no user scripts. A missing host executable reports
**SKIPPED** with a reason. Hosts that exit, IPC startup timeouts, and unexpected
command or assertion failures fail the test.

The suite also includes elxosc integration tests. It loads
`main.lua`, sends `elxosc-demo`, checks that the host remains alive, and reads
back `osd-dimensions`. The N3 demo test opens Page/Popup routes, sends real ESC
keypresses, checks results and retained State, then verifies that home releases ESC
to a separate host-script binding. The button fixture also sends real mpv `mouse` commands
through an isolated user `input.conf` to verify interactive double-click capture
and background fullscreen passthrough. These tests are not pixel-level OSD checks.

## Layout

| File | Contents |
| --- | --- |
| `run.lua`, `runner.lua` | Bootstrap, recursive discovery, component filters and CLI options |
| `test_runner.py` | Real CLI subprocess checks: groups, filters, verbosity, failures, paths with spaces |
| `test_flutter_runtime/` | `core`, `binding`, `lifecycle`, `keys`, `paint`, `host_pipeline` runtime groups |
| `runtime_support.lua` | Mounted State probe and deterministic clocks for runtime tests |
| `support.lua` | Bootstrap: makes the elxosc modules / `elxlibs.*` require-able |
| `framework.lua` | Tiny assertion/reporting helpers |
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
| `mp_stub.lua` | Shared `mp` stub for the host-layer tests (not a test file) |
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
