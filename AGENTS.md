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
| `foundation/` | Geometry, color, anchors, pointer values, matrices | None |
| `painting/` | Canvas/Paint/Path/TextPaint contracts | None |
| `text/` | Text styles, paragraphs, layout contract | None |
| `layout/` | Box constraints and layout algebra | None |
| `render/` | Mutable render tree, layout, paint, hit testing, dirty state | None |
| `animation/` | Curves, tweens, frame-clock controllers | None |
| `scheduler/` | Frame clock, scheduler phases, tickers | None |
| `widget/` | Immutable widgets, elements, state, bindings, controls | None |
| `backends/` | ASS and recording implementations of framework contracts | None |
| `libs/` | Sandbox, module registry, Define/DSL support | None |

### Host, entry points, and support

| Path | Responsibility |
| --- | --- |
| `host/` | mpv frame loop, ASS presenter, input, Define transport |
| `main.lua` | mpv entry point and scaffold assembly |
| `elxlib_load.lua` | mpv script-path bootstrap |
| `demo.lua` | executable showcase of rendering, input, and animation |
| `test/` | Lua unit/integration tests and the mp stub |
| `test/real_host/` | isolated mpv/mpv.net integration tests |
| `dev/` | design documents and non-production sketches |
| `fonts/` | bundled font metadata and generated glyph names |
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
libs provide sandbox/Define services and are consumed by host/entry assembly
```

The framework must remain usable without mpv. Only `host/`, `main.lua`, and
`elxlib_load.lua` may require `mp`. In particular, do not add `mp` imports to
`foundation/`, `painting/`, `text/`, `layout/`, `render/`, `animation/`,
`scheduler/`, `widget/`, `backends/`, or `libs/`.

Use bare module names such as `require 'widget.widget'`; do not add an
`elxosc.` prefix and do not introduce require cycles. Aggregate modules must
return the same class objects as their direct modules.

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
  readable module aliases (`local widget_mod = require 'widget.widget'`).
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
4. Run the complete checks listed below. A focused test is useful during
   iteration but does not replace the full suite before committing.
5. Review `git diff --check`, `git diff --stat`, and `git status --short`. Stage
   only the intended files for each commit. Splitting code, design, and guide
   changes into separate commits is encouraged.

## 7. Required checks

Run from the repository root. Local executable names are kept in the ignored
`project.conf`; copy `project.conf.tpl` before the first run and adjust it for
the current machine. The commands below use the default WSL tool names.

```text
luajit test/run.lua
emmylua_check .
uv run --group test python -m pytest -q test/real_host
```

The current local baseline is recorded in `dev/design/TESTING.md`; update the
current design/testing documents when the intentional test count changes.

The real-host fixture uses an isolated config and ownership-bounded cleanup.
Never replace it with a command that kills mpv by image name. Real-host tests
should skip only when the required host is genuinely unavailable.

Lua tests use `test/run.lua`; new files are named `test_*.lua` and must be
registered by the runner. Host modules may use `test/mp_stub.lua`, while
`test/real_host/` verifies behavior against a real process.

## 8. Documentation and commits

Current design documents live in `dev/design/`; historical records belong in
`dev/design/old/`. Use the direction document that owns the decision instead of
adding another long unindexed design note. Keep module READMEs short and link
to the relevant design direction.

Use concise conventional commits such as `feat:`, `fix:`, `refactor:`,
`test:`, and `docs:`. A commit message should identify the affected layer.
For a multi-part worktree, split commits by coherent purpose and ensure the
final summary lists the actual checks run. Do not commit credentials, portable
user configuration, generated local environments, or unrelated build output.
