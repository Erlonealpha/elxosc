# Extension type hints

`elxosc.lua` is development-only metadata. Load it as an EmmyLua workspace library;
never require it at runtime. It references the existing source types and selected
host builtins, without defining copies of the framework's classes or editor globals.
Declarations use `@namespace elxosc` and references use `@using elxosc`; an
extension may choose its own namespace and import these types with `@using`.
Dedicated metadata tests and editor acceptance are currently deferred.

Configure an extension workspace with `examples/extension/.emmyrc.json.tpl`, replacing
the two dependency paths with the elxosc and elxlib checkouts. Keep the extension
source as the workspace root; add elxosc's `lib`, `player`, `define`, `host` and the
generated metadata file as libraries. Disable the editor's `import` to `require`
mapping: Define imports resolve registered packages, not files.

`elxosc.meta.Builtins` describes the payload's global/builtin names as table members.
The metadata uses a local table; it does not redefine the editor's `require`, `print`,
`import_as`, component constructors or other globals. Declare this type on a local
table capturing the actual sandbox functions, as shown in the extension template.
The narrowly scoped `undefined-global` annotations cover those dynamic bindings only.
There is no runtime `builtins` variable injected by the host.

Use `builtins.require('widgets')`, `builtins.import_as('material.slider')`,
`builtins.import_as('player')` or `builtins.import_as('mp')` from that local table.
Literal package names select the catalog's exact type, including scoped host functions.
Widgets do not contain bind, DSL or
player context; use their owning packages. Dynamic strings have a plain table
fallback and need an explicit type when their fields are known.

`import` injects names and returns no value. Define's `require` aliases `import_as`:
both return a scoped package without injecting its exports. They resolve registry
package names rather than framework source paths. Hints cannot track arbitrary
runtime environment writes. Default construction builtins contain only
`new_widget` and `new_state`; Define supplies `import`, `import_as`, `require`, `mod`
and `bind`, and host supplies `print`. Components, value types and application APIs
come from explicit package imports. The example demonstrates declared subclasses
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
