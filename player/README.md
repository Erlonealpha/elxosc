# Player composition

`player/` is the host-independent application composition layer for phase 6.4.
It does not load `mp`, manage an overlay presenter, or look up Providers while
assembling a tree.

## Public entry points

- `region.lua` — stable `Region` IDs and single/multi-child region definitions.
- `registry.lua` — `PageContribution` and the initialization-only
  `PagesRegistry`.
- `scaffold.lua` — `PlayerScaffold`, `Main`, `Grid`, and `More` widgets.
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

The scaffold keeps the existing three-by-three geometry. `main_layout.lua`
remains a compatibility facade that returns the legacy direct grid and keeps
the demo middle child supplied by the entry point.

Pages is a composition name, not Navigator: there is no route history, runtime
registry, Provider lookup during assembly, arbitrary z ordering, or mounted
Widget mutation here. Host-level presentation and overlay lifecycle belong to
`host/` in a later phase.
