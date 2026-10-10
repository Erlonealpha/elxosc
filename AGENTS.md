# Repository Guidelines

## Project Structure

`elxosc` is a LuaJIT UI framework for mpv/mpv.net. Framework code is split into
`foundation/`, `painting/`, `text/`, `layout/`, `render/`, `widget/`,
`scheduler/`, `backends/`, and `libs/`. The mpv boundary is limited to
`host/`, `main.lua`, and `elxlib_load.lua`. Lua tests live in `test/`; real-host
Python/uv tests live in `test/real_host/`. Design notes are under
`dev/design/`, and experimental sketches are under `dev/`.

## Development Commands

Run the complete Lua suite from the repository root:

```powershell
E:\lua\local\LuaJIT\bin\luajit.exe test\run.lua
```

Run static analysis:

```powershell
emmylua_check.exe .
```

Run real mpv/mpv.net tests:

```powershell
uv run --group test python -m pytest -q test/real_host
```

The real-host fixture uses an isolated config and ownership-bounded process
cleanup. Never replace it with commands that kill mpv by image name.

## Coding Style

Use four spaces, single-quoted strings, readable expanded function bodies, and
module aliases (`local widget_mod = require 'widget.widget'`). Every
`std.class.new` needs explicit inheritance, fields, Options types, and a
constructor overload. Do not use file-wide diagnostic suppression to hide
production errors. Constructors must not mutate caller-owned options tables.
Keep framework modules independent of `mp` and preserve the constraints
protocol: constraints down, sizes up, parent positions children.

## Testing Guidelines

Lua tests use the small runner in `test/run.lua`; name files `test_*.lua` and
register new files there. Test public behavior, invalid boundaries, module
loading, and aggregate/direct-module identity. Python tests use pytest through
uv and should skip only when the real host is unavailable.

## Commits and Reviews

Use concise conventional commits such as `feat:`, `fix:`, `refactor:`,
`test:`, and `docs:`. A change should describe affected layers, list commands
actually run, and call out skipped or unavailable checks. Do not include
credentials, portable user configuration, or generated local environments.

## Design Scope

Define is an initialization-time Widget construction tool, not a runtime tree
manager. Each `scope_id` accepts only its first `define` payload; later payloads
must warn and be ignored. Multiple binds from one scope remain allowed, and
cross-scope conflicts follow target type and bind operation without priority
rules. Do not add scope shutdown, runtime unbind, root rebuild, or Navigator
APIs without an explicit design update. Read `dev/design/` before changing the
define protocol, bind semantics, or planned navigation model.
