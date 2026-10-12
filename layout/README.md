# Layout

`layout/` owns the constraint algebra used by RenderObject layout. It is host-free
and intentionally small.

## Public entry points

- `constraints.lua` — `Constraints` bounds, tight/loose/unbounded/expand helpers,
  intersection, tightening, deflation, and finite-size checks.

The protocol is one-way: constraints go down, sizes go up, and the parent positions
children. Layout code must distinguish `unbounded()` (`0..∞`) from Flutter-style
`expand()` (tightly infinite before parent enforcement).

See [rendering](../dev/design/RENDERING.md) and the archived constraint comparison in
[`dev/design/old/DESIGN_CONSTRAINTS.md`](../dev/design/old/DESIGN_CONSTRAINTS.md).
