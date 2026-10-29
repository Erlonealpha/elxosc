# Player widgets

`widget/player/` owns the default player shell and player-specific widget
composition. It remains mpv-free; host commands and snapshots enter through
`HostActions` and `PlayerProvider`.

## Public entry points

- `app.lua` — `Main`, `WindowLayer`, `DefaultApp` and `DefaultAppState`.
- `theme.lua` — `PlayerThemeData`/`PlayerTheme`, the typed ModernX layout and style profile.
- `layout.lua` — `PlayerLayout` and independently measured original/reduced root-relative
  geometry built from `Stack`/`Positioned`.
- `progress_bar.lua` — `ProgressBar`/`SeekBar`, the Widget front end for the
  fixed-layout player progress RenderObject.
- `icon_map.lua` — ModernX semantic control names mapped to the bundled
  Material Symbols Rounded glyph names and typed size/variation defaults.
- `init.lua` — aggregate entry preserving direct-module class identity.

The generic `WidgetsApp` ambient wrapper remains in `widget/app.lua`. That module
re-exports the player classes for compatibility; new player composition should
use `require 'widget.player'` or the direct player modules.

`DefaultApp` passes the 150ms frame-clock AutoHide fade through to Main. The fade is local to
MainEntry and does not affect Extension or WindowLayer state. `Main.window_top_bar` accepts
`auto`/`yes`/`no`; `auto` follows the PlayerSnapshot `fullscreen`, `border` and `title_bar`
fields, so the same policy controls both the visible top bar and the top wake zone.

`PlayerThemeData.layout_option` selects `original` or `reduced`. Both use the finite
`Positioned` parent-data contract for controller, seekbar, metadata, side controls and window
controls; the two profiles keep separate seekbar/title/chapter geometry rather than reusing a
single scale as a layout substitute.
