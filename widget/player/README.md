# Player widgets

`widget/player/` owns the default player shell and player-specific widget
composition. It remains mpv-free; host commands and snapshots enter through
`HostActions` and `PlayerProvider`.

## Public entry points

- `app.lua` — `Main`, `WindowLayer`, `DefaultApp` and `DefaultAppState`.
- `progress_bar.lua` — `ProgressBar`/`SeekBar`, the Widget front end for the
  fixed-layout player progress RenderObject.
- `icon_map.lua` — ModernX semantic control names mapped to the bundled
  Material Symbols Rounded glyph names.
- `init.lua` — aggregate entry preserving direct-module class identity.

The generic `WidgetsApp` ambient wrapper remains in `widget/app.lua`. That module
re-exports the player classes for compatibility; new player composition should
use `require 'widget.player'` or the direct player modules.
