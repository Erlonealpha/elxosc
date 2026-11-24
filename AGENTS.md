# elxosc Repository Guide

## 1. Mission and source of truth

`elxosc` is a LuaJIT UI framework for mpv/mpv.net. It builds a Flutter-like
Widget → Element → RenderObject pipeline and emits backend-neutral drawing calls
that are currently rendered as ASS `osd-overlay` events.

Read documentation in this order:

1. `dev/design/DESIGN.md` — the current architecture, contracts, and roadmap.
2. The direction document relevant to the change:
   `ARCHITECTURE.md`, `RENDERING.md`, `INPUT.md`, `WIDGETS.md`, `HOST.md`,
   `PLAYER.md`, `TESTING.md`, or `ROADMAP.md`.
3. The README in the module being changed.
4. `codestyle.md` for EmmyLua and Lua formatting rules.

`dev/design/old/` contains historical design records. They explain past
decisions, but they are not the current API contract. When code and an old
document disagree, use the current code and current design documents.

## 2. Repository map

### Framework layers

| Directory | Responsibility | Host dependency |
| --- | --- | --- |
| `lib/*.lua` | Layer collectors, namespaces, material construction surface | None |
| `lib/src/foundation/` | Geometry, color, anchors, pointer values, matrices | None |
| `lib/src/painting/` | Canvas/Paint/Path/TextPaint contracts | None |
| `lib/src/text/` | Text styles, paragraphs, layout contract | None |
| `lib/src/layout/` | Box constraints and layout algebra | None |
| `lib/src/render/` | Mutable render tree, layout, paint, hit testing, dirty state | None |
| `lib/src/animation/` | Curves, tweens, frame-clock controllers | None |
| `lib/src/scheduler/` | Frame clock, scheduler phases, tickers | None |
| `lib/src/widgets/` | Immutable widgets, elements, state, bindings, basic controls | None |
| `lib/src/material/` | Design themes, button family, styled numeric controls | None |
| `lib/src/backends/` | ASS and recording implementations of framework contracts | None |
| `define/` | Sandbox, module registry, Define/DSL/Slot support | None |
| `player/` | Media state/actions, shell, Timeline and AutoHide | None |

### Host, entry points, and support

| Path | Responsibility |
| --- | --- |
| `host/` | mpv frame loop, ASS presenter, input, Define transport |
| `main.lua` | mpv entry point and scaffold assembly |
| `elxlib_load.lua` | mpv script-path bootstrap |
| `demo.lua` | executable showcase of rendering, input, and animation |
| `test/` | Lua unit/integration tests and the mp stub |
| `test/real_host/` | isolated mpv/mpv.net integration tests |
| `mpv-luatest/` | Pinned Git submodule for offline tests; development only |
| `dev/` | design documents and non-production sketches |
| `lib/fonts/` | bundled font metadata and generated glyph names |
| `tools/` | offline generation utilities |

Every major framework directory has a local `README.md`. Keep that README
focused on ownership, public entry points, and invariants rather than copying
the full design documents.

## 3. Dependency partitions

The intended dependency direction is:

```text
foundation → painting/text → layout → render → widget → host → main
                         scheduler ────────────────┘
backends implement painting/text contracts and are consumed by host
define provides construction services consumed by player/host/entry assembly
player provides media components and policies consumed by host/entry assembly
```

The framework must remain usable without mpv. Only `host/`, `main.lua`, and
`elxlib_load.lua` may require `mp`. In particular, do not add `mp` imports to
`lib/src/foundation/`, `lib/src/painting/`, `lib/src/text/`, `lib/src/layout/`, `lib/src/render/`, `lib/src/animation/`,
`lib/src/scheduler/`, `lib/src/widgets/`, `lib/src/material/`, `lib/src/backends/`, or `define/` or `player/`.

Use bare module names such as `require 'src.widgets.framework'`; do not add an
`elxosc.` prefix and do not introduce require cycles. Aggregate modules must
return the same class objects as their direct modules.
`lib/module_loader.lua` configures both public collectors (`require 'foundation'`)
and canonical source modules (`require 'src.foundation.geometry'`). Slash paths with
`.lua` and explicit `init` are runtime aliases; prefer dot paths in project code.
Layer collectors are framework APIs independent of Define. `lib/material.lua` owns
the framework construction surface; `host/builtins.lua` selects default Define
builtins; `host/package_catalog.lua` owns import descriptors. Application source
modules use `player.src.*` and `define.src.*`; lib must not import those packages.
Framework collectors export source members, without attaching child module tables.
Load source modules or exact registered subpackages separately. Named exported values
such as Anchor and Curves may remain tables; module names do not imply nested fields.
Basic widgets must not require Material. Material reexports basic widget members;
visual defaults belong to its wrappers, while numeric render controls receive explicit
configuration. Old widget/widget.widgets/basic/layout module paths are removed.

## 4. Non-negotiable framework contracts

### Layout and rendering

- Constraints go down, sizes go up, and the parent positions children.
- `RenderObject` layout is finite and converges under its incoming
  `Constraints`; infinite or invalid sizes are rejected at the boundary.
- Widgets are immutable descriptions. Runtime changes go through `State` and
  rebuilds; mounted Widget trees are not edited in place.
- `RenderObject` instances are mutable and persistent between frames. Dirty
  propagation must distinguish layout from paint.
- `OffsetBox` and `TransformBox` scale are paint-only. `LayoutScaleBox` scale is
  layout + paint. The target RenderObject setter, not the controller, decides
  the invalidation category.
- Transform support is limited to finite positive axis-aligned scales and
  translations. Do not silently approximate rotation, skew, zero/negative
  scales, or arbitrary affine layout.

### Text and ASS

- `TextStyle.align` is `left`, `center`, or `right`; ASS maps these to `\an4`,
  `\an5`, and `\an6`.
- An explicit `TextPaint.anchor` overrides style alignment. Icon and special
  drawing code may use the full nine-anchor contract.
- `TextPaint.offset` is visual paint data; it does not alter logical layout or
  hit testing.
- ASS animation is frame-clock driven static output. Do not generate PTS-based
  `\move` or `\t` tags.

### Define, Pages, and updates

Define is the sole extension-content ingress and currently an initialization-time
Widget construction protocol, not a runtime tree manager:

- Each `scope_id` accepts only its first `define` payload; later payloads warn
  and are ignored.
- Multiple binds from one scope remain allowed and execute in registration
  order.
- Cross-scope conflicts follow target type and bind operation; there is no
  priority system.
- Bindings are applied before mounting. They do not provide runtime unbind,
  scope shutdown, root rebuild, or tree rollback.
- The planned `Pages` layer exposes controlled entry points for Define content to
  contribute to `Main`, the 3x3 grid, `more`, and public overlay layers. Define
  transports extension content; the extension owns its internal runtime behavior.
- Configuration and public-API hot updates are data/event updates, not a second
  content ingress and not Lua source/module hot reload. They flow through
  snapshots, State/Provider, or explicit RenderObject setters.
- Do not add Navigator APIs or change these semantics without updating the
  current design documents and tests first.

## 5. Coding style and type contracts

- Use four spaces, single-quoted project strings, expanded function bodies, and
  readable module aliases (`local widget_mod = require 'src.widgets.framework'`).
- Every `std.class.new` has explicit inheritance, instance fields, an Options
  type when it accepts options, and a constructor `---@overload` returning
  `self`.
- Reuse named aliases for closed string unions. Do not append `| string` to a
  closed set because it disables invalid-value checking.
- Constructors must not mutate caller-owned options tables. Normalize into a
  fresh config/object instead.
- Do not use file-wide diagnostic suppression in production modules. Add local
  type information or use a narrowly scoped suppression only for a documented
  test/third-party limitation.
- Keep every changed file free of trailing whitespace and preserve a final
  newline.

## 6. Development workflow

1. Inspect `git status`, the current design document, and the relevant module
   README before editing. Treat existing worktree changes as intentional until
   inspected.
2. Make the smallest coherent change in the owning layer. Update the relevant
   module README or design direction when a public contract changes.
3. Add tests for public behavior, invalid boundaries, lifecycle/dirty behavior,
   module loading, and aggregate/direct-module identity as applicable.
4. Format changed Lua files with `python tools/format_lua.py write` and verify
   them with `python tools/format_lua.py check`. Explicit paths select files or
   directories; without paths, the tool selects staged, modified and untracked Lua files.
   For code changes, run the complete Lua suite and EmmyLua checks listed below.
   Select real-host tests by affected behavior; normally run only the related
   files or cases rather than the full real-host suite.
5. Review `git diff --check`, `git diff --stat`, and `git status --short`. Stage
   only the intended files for each commit. Splitting code, design, and guide
   changes into separate commits is encouraged.

## 7. Required checks

Run from the repository root. Local executable names are kept in the ignored
`project.conf`; copy `project.conf.tpl` before the first run and adjust it for
the current machine. The commands below use the default WSL tool names.

```text
git submodule update --init --recursive
python tools/format_lua.py check
luajit test/run.lua
emmylua_check .
```

Record actual commands, source versions, results, failures, and untested scope
in the active local plan's acceptance records, or local work notes when no plan
applies. Report the checks actually run in the commit or handoff. Update design
and testing documents when strategy, coverage responsibilities, supported behavior,
or tool usage changes; test counts alone do not require design changes.

`luafmt.toml` configures EmmyLua `luafmt` for LuaJIT; its executable comes from
the `luafmt` entry in `project.conf`, with PATH as fallback. Explicit paths select
Lua files/directories; the default scope is the current Git changes.
`.luafmtignore` excludes local plans, scratch, generated metadata and third-party
sources. Formatting aligns annotations; completeness and correctness still need
code review and EmmyLua analysis. Details and direct CLI usage are in
`tools/README.md`.

Run real-host tests when changes affect behavior they cover, such as script
loading, presentation, input, Define wiring, or player integration. In most cases,
run only the affected test files or cases, for example:

```text
uv run --group test python -m pytest -q test/real_host/test_player_extensions.py
```

Documentation-only changes and changes without relevant host impact do not need
real-host tests. Avoid running the full real-host suite by default; use it when
host impact is broad or cannot reasonably be bounded, or when explicitly requested.
Report the selected scope and the reason for a full run. Passed checks do not need
repeating without new changes, failures, or unresolved concerns.

The real-host fixture uses an isolated config and ownership-bounded cleanup.
Never replace it with a command that kills mpv by image name. Real-host tests
should skip only when the required host is genuinely unavailable.

Lua tests use `test/run.lua`, which delegates to the pinned `mpv-luatest`
development dependency. New files are named `test_*.lua` and are discovered
automatically. Host modules may use the `test/mp_stub.lua` compatibility import, while
`test/real_host/` verifies behavior against a real process.

Runner behavior, owned by mpv-luatest: automatic discovery of
`test_*.lua`, including nested group directories whose names start with `test`.
Use slash-separated group/file filters and `-v` for full logs; default logs show
failures and the summary. Keep project/elxlib bootstrap and compatibility
configuration in `test/`; shared runner/assertion/stub changes belong to the
independent submodule. Test that repository independently and revalidate elxosc
before updating its gitlink. See `dev/design/TESTING.md` for setup and ownership.

## 8. Documentation and commits

Current design documents live in `dev/design/`. They describe architecture,
observable behavior, invariants, technical rationale, and support boundaries.
Use the direction document that owns the decision and keep module READMEs short.
`ROADMAP.md` records capability gaps and dependencies, not implementation stages.

Development context belongs primarily in the local `.plan`: investigations and
working notes in `work/`, implementation stages and decisions in the active plan,
and execution results and manual feedback in its acceptance records. Do not append
task progress, session history, local environment handling, or test-run logs to
design documents. The parent repository must remain readable without `.plan`;
public links and contracts must not depend on local plan IDs or files.

`dev/design/old/` preserves historical design rationale and is not a destination
for new development logs. Keep benchmark or measurement artifacts in `dev/` only
when their methods, source versions, and limits make them useful shared references;
ordinary run results belong in local planning records.

Use concise conventional commits such as `feat:`, `fix:`, `refactor:`,
`test:`, and `docs:`. A commit message should identify the affected layer.
For a multi-part worktree, split commits by coherent purpose and ensure the
final summary lists the actual checks run. Do not commit credentials, portable
user configuration, generated local environments, or unrelated build output.
