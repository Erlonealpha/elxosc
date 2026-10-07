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
| `test_ass.lua` | ASS colour encoding, drawing emission, estimating text layout |

Nothing here is loaded by mpv: the directory has no `main.lua`, so mpv's script
auto-loader ignores it.
