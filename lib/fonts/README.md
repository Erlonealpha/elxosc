# Font resources

`fluent_icon_names.lua` is generated annotation data for the bundled Material
Symbols Rounded font; it is not a runtime module. `tools/gen_font_glyphs.py`
generates it. Font loading is provided by the host configuration.

`material_symbols.lua` supplies the named MaterialSymbols resource: font family,
variation validation/defaults and backend-neutral text intent. It does not build
widgets or resolve host fonts. `src.material.icons` reexports this same value;
the basic Icon keeps the bundled default and also accepts other font families.

See [Material](../src/material/README.md) and
[rendering](../../dev/design/RENDERING.md).
