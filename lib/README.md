# Framework library

`lib/src/` owns the host-independent framework implementation. `lib/*.lua` collects
each layer's exports regardless of whether Define exposes them. Collectors return
ordinary typed Lua tables and share the source modules' classes and nested values.

After bootstrap, `require 'foundation'` loads `lib/foundation.lua` and
`require 'src.foundation.geometry'` loads `lib/src/foundation/geometry.lua`.
The shared loader also accepts `src/foundation/geometry.lua` and explicit
`src/widget/init.lua`; these spellings resolve to the same canonical module table.
Prefer dot paths without a suffix in project code for EmmyLua file resolution.
Layers without an earlier source aggregate expose `src.<layer>.init` as the same
public collector. Existing animation/widget source aggregates retain their API.

Every layer has an entry: `foundation`, `painting`, `text`, `layout`, `render`,
`animation`, `scheduler`, `widget`, and `backends`. A collector exposes both flat
constructors and source namespaces, such as `render.RenderStack`/`render.stack` and
`widget.widgets.slider`. `widget.bind_module` names the source bind module because
`widget.bind` is its registry helper. Render's colliding normalizers are also
available as `normalize_slider` and `normalize_progress_indicator`.

`material.lua` selects the default construction surface previously assembled as
host builtins: widgets, geometry, styles, and class factories. `player.lua` exports
the explicit player components. They are usable without the extension system;
`extension/exports.lua` owns descriptors and import names, while `host/mpv_define.lua`
adds scope-aware mpv/player services and registers them.

`module_loader.install(repository_root)` sets the library/source paths and the
canonical source searcher. The mpv entry invokes it through `elxlib_load.lua`;
standalone consumers load it with `loadfile` and provide the sibling `elxlib` paths.
EmmyLua consumers add `lib` to `workspace.packages` in their local analyzer config.

Source ownership and invariants remain in each layer's README. See
[architecture](../dev/design/ARCHITECTURE.md) and [host protocol](../dev/design/HOST.md).

`fonts/` contains the bundled font and generated glyph metadata. Host fixtures and
offline measurement tools resolve these resources from `lib/fonts/`.
