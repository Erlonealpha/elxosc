# Material widgets

`require 'material'` reexports basic widgets and collects Theme/ThemeData,
Button/ButtonBase/ButtonStyle, ElevatedButton, OutlinedButton, TextButton,
IconButton, Slider and LinearProgressIndicator. It exports members, not source
module tables. `require 'src.material'` is a one-way collector alias.

Each styled class is defined once in `src.material.*`; direct imports and the
collector share class identity. Construction normalizes into fresh configuration
and does not modify caller options.

Slider and LinearProgressIndicator own their existing palette and size defaults.
The corresponding render sources receive explicit visual configuration and own
numeric validation, capture, layout/paint invalidation and painting. Indeterminate
progress still uses a State-owned frame-clock ticker. This is the existing widget
family, not a complete Flutter Material implementation.

`icons.lua` exports the named MaterialSymbols font resource also used by the
basic Icon. Fonts and generated glyph metadata stay in `lib/fonts/`.
Player Theme, Timeline and PlayerIcons are owned by player.

See [widgets](../../../dev/design/WIDGETS.md),
[basic widgets](../widgets/README.md) and [resources](../../fonts/README.md).
