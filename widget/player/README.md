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
- `tooltip.lua` — `PlayerTooltip`, an in-tree hover tooltip that preserves the
  wrapped control's pointer routing and disabled-state feedback.
- `metadata.lua` — host-independent title, URL/live, description, date and file-size
  normalization used by the player shell.
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

`ProgressBar` keeps a stable input RenderObject for hover, wheel, drag capture, exact/keyframe
seek, chapter context-seek, ranges and markers. Playback controls use `HostActions` for playlist,
chapter, track, volume and window commands; button hover/press tint and glow are paint-only.
Soft-repeat is frame-clock driven, while selector actions and track-list feedback remain explicit
host actions/messages. Seekbar hover uses an in-tree time/chapter tooltip and switches to the
optional thumbfast capability when the host reports it; unavailable capabilities retain a clear
disabled/loading/error tooltip path.
Metadata fallback, idle state, and the description preview/panel also remain inside
the same tree; idle mode does not retain player pointer regions.
The description panel supports link selection/open through `HostActions`, while
optional download and SponsorBlock data remain capability-driven.
The default top/bottom backgrounds use ModernX's blurred one-pixel edge treatment rather than a
full gray controller fill.

`PlayerThemeData.layout_option` selects `original` or `reduced`. Both use the finite
`Positioned` parent-data contract for controller, seekbar, metadata, side controls and window
controls; the two profiles keep separate seekbar/title/chapter geometry rather than reusing a
single scale as a layout substitute.
