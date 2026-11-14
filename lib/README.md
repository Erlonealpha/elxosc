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

`module_loader.install(root)` supports public collectors and canonical sources,
including dot/slash paths, `.lua` suffixes and explicit `init` aliases. Application
sources use `player.src.*` and `define.src.*` under the repository root; they do not
add another bare `src` search root. Prefer canonical dot paths in project code.

`fonts/` owns bundled font metadata and the shared MaterialSymbols resource.
The old widget/widget.widgets/basic/layout collectors have been removed.
EmmyLua consumers add `lib` and the repository
root to their workspace packages. Tests also supply the independent sibling elxlib.

See [architecture](../dev/design/ARCHITECTURE.md),
[widgets](../dev/design/WIDGETS.md) and [host](../dev/design/HOST.md).
