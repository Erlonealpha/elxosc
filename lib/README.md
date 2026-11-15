# Framework library

`lib/src/` contains only the reusable framework. Source modules and `lib/*.lua`
collectors do not require player, Define, host or mp. Collectors expose the same
classes as direct modules, independently of extension registration.

Collectors expose selected source members, without attaching child module tables.
For example, `require('render').RenderStack` is a member export; the source module
is loaded through `require 'src.render.stack'` or the independent Define package
`import_as('render.stack')`. Named source values such as Anchor and Curves retain
their table identity. Package names and collectors do not form an object hierarchy.

Public layers are `foundation`, `painting`, `text`, `layout`, `render`, `animation`,
`scheduler`, `widgets`, `backends` and `material`. Basic widgets and runtime live
flat in `src.widgets.*`; Theme and styled controls live in `src.material.*`.
`material` reexports basic widgets and collects styled controls/value constructors;
`host/builtins.lua` owns the explicit default Define construction surface.
It exposes only the class factories; components and values use explicit package imports.

`export` organizes static declarations independently of extensions. Its module-level
API and `export.new()` contexts provide `export(name, source, append?)`, `get(name)`
and `collect()`. Collectors use separate contexts, so load order cannot mix their
declarations. For example:

```lua
local exports = require('export').new()
exports.export('controls', require 'src.widgets.text')
exports.export('controls', require 'src.material.slider', true).show('Slider')
local controls = exports.get('controls')
```

Each declaration snapshots the source's own fields. One show/hide selection affects
only that source; nested values/classes retain identity and sparse integer keys keep
their positions. Equal raw values deduplicate; different values under the same key
raise ValueError. Source metatables are neither consulted nor copied. `get` publishes
one package; `collect` validates all pending packages before publishing them in first
declaration order. Repeated reads share exports, but collection returns fresh
descriptors. Published packages reject further declarations/selections. This is
initialization organization; Define still owns scope loaders and payload transactions.

`package_catalog.collect()` lists every framework runtime source, collector, tool
and font resource using explicit declarations. It performs no directory scanning;
source `init` files alias collectors and annotation-only metadata is excluded.
Player and Define maintain their own catalogs; host joins the inventories and adds
scoped facades. Complete registration does not expand default builtins.

`module_loader.install(root)` supports public collectors and canonical sources,
including dot/slash paths, `.lua` suffixes and explicit `init` aliases. Application
sources use `player.src.*` and `define.src.*` under the repository root; they do not
add another bare `src` search root. Prefer canonical dot paths in project code.

`fonts/` owns bundled font metadata and the shared MaterialSymbols resource.
The old widget/widget.widgets/basic/layout collectors have been removed.
EmmyLua consumers add `lib` and the repository
root to their workspace packages. Tests also supply the independent sibling elxlib.

Module types use `elxosc.mod.<canonical require>`; framework instances/options use
`elxosc.*`, with styled controls under `elxosc.material.*`. Runtime require names
and class name strings retain their existing spelling.
Files use `@namespace elxosc` for declarations and `@using elxosc`
for short type references; styled controls also use `@using elxosc.material`.
The namespace resolves class-name templates without inline name casts.
Source init files return the layer collector without declaring another module type.
Extension consumers use the development-only [meta entry](../meta/README.md) for scoped imports and
default construction names.

See [architecture](../dev/design/ARCHITECTURE.md),
[widgets](../dev/design/WIDGETS.md) and [host](../dev/design/HOST.md).
