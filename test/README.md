# elxosc test-suite

Standalone smoke/regression tests for the elxosc framework core. They run on a
bare **LuaJIT** -- mpv is not needed: `elxosc.*` is loaded straight from this
repository and `elxlibs.*` from the sibling `elxlib` checkout, without running
elxlib's real `init.lua` (no ffi / DLL-path setup).

## Running

```sh
cd scripts/elxosc
luajit test/run.lua             # whole suite
luajit test/run.lua geometry    # only matching files
```

Exit code is `0` when everything passes, `1` otherwise.

## Static analysis

The project is also checked with the EmmyLua analyzer; run it from the project
root so `.emmyrc.json` (library paths, `runtime.special.raise`, ...) applies:

```sh
emmylua_check.exe .
```

Both gates are expected to be clean: `No issues found` and `ALL GOOD`.
The framework directories are meant to stay free of *all* diagnostics; the
test files disable the codes that stem from limits of the `std.class` model
(see the header in `test_widget.lua`).

Current baseline: **0 diagnostics / 521 checks**.

## Layout

| File | Contents |
| --- | --- |
| `run.lua` | Entry point; sets up `package.path`, runs every `test_*.lua` |
| `support.lua` | Bootstrap: makes the elxosc modules / `elxlibs.*` require-able |
| `framework.lua` | Tiny assertion/reporting helpers |
| `test_foundation.lua` | Geometry value types, colour, paint, path, canvas contract |
| `test_text.lua` | `TextStyle`, the `TextLayout` contract and wrapping |
| `test_scheduler.lua` | Frame clock contract, the two-phase scheduler, tickers |
| `test_layout.lua` | Constraints, the box set, owner driving, paint + hit test |
| `test_input.lua` | Pointer path resolution, gesture dispatch, hover tracking |
| `test_widget.lua` | Widget -> element -> render object, reuse, state rebuilds |
| `test_bind.lua` | Inherited widgets and `bind` (define-time named targets) |
| `test_define.lua` | Sandbox env primitives, the module registry (data + loaders), the define protocol |
| `test_dsl.lua` | The define DSL factories: `new_widget` / `new_state` / `builtins` |
| `test_host_define.lua` | `MpDefine`: the `mp` module, message routing, the window (`mp` stubbed) |
| `test_host_app.lua` | `App`: frame clock, overlay, `WidgetBinding`, the define window (`mp` stubbed) |
| `mp_stub.lua` | Shared `mp` stub for the host-layer tests (not a test file) |
| `test_ass.lua` | ASS colour encoding, drawing emission, estimating text layout |
| `constraints_examples.lua` | Fixtures: the 29 doc examples as elxosc widget trees (not a test file) |
| `test_constraints_examples.lua` | The 29 `flutter/constraints` examples: raw `ass-events` vs expected |
| `test_layering.lua` | Guard: only `host/` (and the entry points) may require `mp` |

Nothing here is loaded by mpv: the directory has no `main.lua`, so mpv's script
auto-loader ignores it.
