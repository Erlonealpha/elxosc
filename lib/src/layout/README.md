# Layout

`lib/src/layout/` owns the constraint algebra used by RenderObject layout. It is host-free
and intentionally small.

Source modules load as `src.layout.*`; the host-independent collector is
[`lib/layout.lua](../../layout.lua), available through `require 'layout'`.

## Public entry points

- `constraints.lua` — `Constraints` bounds, tight/loose/unbounded/expand helpers,
  intersection, tightening, deflation, and finite-size checks.

Constraints uses independent `elxlibs.dataclass` storage and shared methods.
Type guards/subclasses use dataclass interfaces; std reflection does not apply.
Custom defaults/equality, tight infinity and finite render boundaries remain;
fields are directly mutable and no freezing or implicit normalization is added.

The protocol is one-way: constraints go down, sizes go up, and the parent positions
children. Layout code must distinguish `unbounded()` (`0..∞`) from Flutter-style
`expand()` (tightly infinite before parent enforcement).

See [rendering](../../../dev/design/RENDERING.md) and the archived constraint comparison in
[`dev/design/old/DESIGN_CONSTRAINTS.md`](../../../dev/design/old/DESIGN_CONSTRAINTS.md).
