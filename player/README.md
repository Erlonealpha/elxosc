# Player composition

`player/` is the host-independent application composition layer for phases 6.4, 6.6,
and Stage 4 navigation. It does not load `mp` or manage an overlay presenter. Pages assembly remains
Provider-free; the mounted `AutoHide` child performs Provider lookup at runtime.

## Public entry points

- `region.lua` — stable `Region` IDs and single/multi-child region definitions.
- `registry.lua` — `PageContribution` and the initialization-only
  `PagesRegistry`.
- `scaffold.lua` — `PlayerScaffold`, player-control `Main`, `Extension`,
  `ExtensionGrid` (`Grid` is its compatibility alias), and `More` widgets.
- `shell.lua` — `ShellConfig`, `ShellVisibilityController`, and the
  Provider-driven `PlayerShell` composition.
- `navigation.lua` — host-independent `Page`, `Route`, `RouteResult`,
  `Navigator`, and `NavigatorState` runtime reconciliation.
- `overlay.lua` — host-independent logical `Overlay`, `Theatre`, `OverlayEntry`,
  `ModalBarrier`, and `PopupRoute`; physical ASS presentation remains in `host/`.
- `widget/autohide.lua` — the shared host-independent `AutoHide` widget and its
  controller/state; player Shell names remain aliases for this implementation.
- `init.lua` — aggregate exports for the public classes.

Extensions register immutable Widget inputs before mounting:

```lua
local pages = PagesRegistry()
local scope = pages:scope('weather')

scope:fill(Region.GRID_TOP_LEFT, WeatherWidget(), { key = 'weather' })
scope:append(Region.MORE, MoreWidget(), { key = 'weather-more', order = 20 })

local root = pages:assemble({ middle_child = fallback_widget })
```

`fill` is for public single-child slots (`main.left`, `main.right`, and the
nine `grid.*` slots). `append` is for the keyed, ordered `more` region. `add`
selects the operation from the region cardinality. A duplicate single slot or
multi-child key is rejected with scope, region, operation, key, and sequence
diagnostics. `freeze()` seals the initialization set; later registrations are
errors. `assemble()` always creates a fresh `PlayerScaffold` tree and never
edits a previously assembled or mounted Widget.

The assembled tree has sibling entries:

```text
PlayerScaffold
├── Main                 -- player-owned controls
└── Extension
    ├── ExtensionGrid    -- the nine public grid regions
    └── More             -- ordered extension children
```

The scaffold keeps the existing three-by-three geometry. `main_layout.lua`
remains a compatibility facade that returns the legacy direct grid and keeps
the demo middle child supplied by the entry point.

PagesRegistry/PageContribution remain the initialization-time composition
registry and are separate from Navigator. Navigator owns one mutable Page list
at runtime, reconciles Page class/key identities into Route records, and does
not execute builders until a mounted route-content Widget builds. It does not
provide overlay, presentation, or host input behavior. `AutoHide` uses a
listening Provider lookup in `build`, non-listening reads for event callbacks,
and disposes its controller subscription with its State. `PlayerShell` keeps
its compatibility State as a composition wrapper and delegates visibility
entirely to `AutoHide`; the controller does not claim clicks or wheel input.
