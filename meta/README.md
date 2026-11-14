# Extension type hints

`elxosc.lua` is development-only metadata. Load it as an EmmyLua workspace library;
never require it at runtime. It references the existing source types and selected
host builtins, without defining copies of the framework's classes.
Declarations use `@namespace elxosc` and references use `@using elxosc`; an
extension may choose its own namespace and import these types with `@using`.
Dedicated metadata tests and editor acceptance are currently deferred.

Configure an extension workspace with `examples/extension/.emmyrc.json.tpl`, replacing
the two dependency paths with the elxosc and elxlib checkouts. Keep the extension
source as the workspace root; add elxosc's `lib`, `player`, `define`, `host` and the
generated metadata file as libraries. Disable the editor's `import` to `require`
mapping: Define imports resolve registered packages, not files.

Use `local widgets = import_as('widgets')`, `import_as('material.slider')`,
`import_as('player')` or `import_as('mp')`. Literal package names select the catalog's
exact type, including scoped host functions. Widgets do not contain bind, DSL or
player context; use their owning packages. Dynamic strings have a plain table
fallback and need an explicit type when their fields are known.

`import` and Define's `require` inject names and return no value. Hints cannot track
arbitrary runtime environment writes. Default builtins are declared explicitly;
use `import_as` for additional fields. The example demonstrates declared subclasses
with `new_widget`/`new_state`, options and two extension packages.
When overriding a State constructor, call `widgets.State.__init(self)` before
initializing custom fields so the inherited resource lifecycle remains valid.
The payload uses only actual Define builtins and imported package members;
standard Lua globals such as `assert` and `tostring` are not implicitly provided.

The committed metadata is generated from the three static catalogs and host's
explicit builtin fields:

```text
python tools/generate_meta.py
python tools/generate_meta.py --check
```

To add extension packages, provide JSON declaration files in composition order:

```json
{"packages": [{"name": "example.controls", "type": "example.Controls"}]}
```

Types may be named types, arrays, or intersections such as
`example.Controls & example.Labels & string[]`. Define actual type fields in the
extension's Lua annotations. Generate one replacement metadata file for that
workspace; do not load both the committed and extended files:

```text
python tools/generate_meta.py --declarations first.json --declarations second.json --output generated/elxosc.lua
```

Same name/type declarations deduplicate. Same name with a different type fails,
including conflicts with built-in package names. Composition order is stable and
does not establish runtime priority. Validation completes before writing, so a
failed composition preserves an existing output. A missing Lua type is reported by
EmmyLua when the missing type is used. These declarations provide editor hints only: the extension still publishes
runtime exports with `mod` inside its Define payload transaction.

See [architecture](../dev/design/ARCHITECTURE.md) and
[Define protocol](../dev/design/HOST.md).
