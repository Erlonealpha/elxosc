# Player widgets

`widget/player/` owns the default player shell and player-specific widget
composition. It remains mpv-free; host commands and snapshots enter through
`HostActions` and `PlayerProvider`.

## Public entry points

- `app.lua` — `Main`, `WindowLayer`, `DefaultApp` and `DefaultAppState`.
- `theme.lua` — `PlayerThemeData`/`PlayerTheme`, the typed ModernX layout and style profile.
- `layout.lua` — `PlayerLayout`, which selects geometry and assembles components.
- `geometry.lua` — finite original/reduced root-relative geometry; the `layout.lua`
  compatibility export returns the same function.
- `description.lua` — description preview, panel and keyboard lifecycle; its class
  remains available through the player aggregate and `layout.lua`.
- `timeline.lua` — `Timeline`, a media Slider specialization with chapter markers,
  cache ranges and seek phases; the mixed ProgressBar/SeekBar entry is removed.
- `tooltip.lua` — `PlayerTooltip`, standard Tooltip with player visual defaults;
  hover, fit, paragraph reuse and resource cleanup live in the standard component.
- `text_controls.lua` — `PlayerTimeDisplay` owns time-format toggles;
  `PlayerHoverText` aliases standard HoverText. Volume uses standard Slider.
- `metadata.lua` — host-independent title, URL/live, description, date and file-size
  normalization used by the player shell.
- `icon_map.lua` — ModernX semantic control names mapped to the bundled
  Material Symbols Rounded glyph names and typed size/variation defaults.
- `init.lua` — aggregate entry preserving direct-module class identity.
- `exports.lua` — explicit components for the protected Define `player` module;
  exports canonical classes, PlayerProvider/PlayerCapability, HostActions and
  `PlayerIcons`, excluding internal State, geometry and assembly helpers.
  `PlayerMain` names the existing `Main` class in this extension API.
- `extension_controls.lua` — `PlayerControlBar` fixed cells and `PlayerControlButton`
  themed icons for appended bottom controls.

The generic `WidgetsApp` ambient wrapper remains in `widget/app.lua`. That module
re-exports the player classes for compatibility; new player composition should
use `require 'widget.player'` or the direct player modules.

`DefaultApp` passes the 150ms frame-clock AutoHide fade through to Main. The fade is local to
MainEntry and does not affect Extension or WindowLayer state. `Main.window_top_bar` accepts
`auto`/`yes`/`no`; `auto` follows the PlayerSnapshot `fullscreen`, `border` and `title_bar`
fields, so the same policy controls both the visible top bar and the top wake zone.
The application converts top/bottom wake-zone heights using Main's effective scale;
scale changes replace the zone policy through the normal rebuild pipeline.

`Timeline` keeps a stable RenderTimeline over RenderSlider's drag/capture lifecycle for hover,
wheel, exact/keyframe
seek, chapter context-seek, cache/SponsorBlock ranges and markers. Normal and persistent cache
ranges use mpv's `seekable-ranges` data; the continuous demuxer cache duration is not painted as a
ModernX seekbar fill. Playback controls use `HostActions` for playlist,
chapter, track, volume and window commands; button hover/press tint and glow are paint-only.
Soft-repeat is frame-clock driven, while selector actions and track-list feedback remain explicit
host actions/messages. Seekbar hover uses an in-tree time/chapter tooltip and switches to the
optional thumbfast capability when the host reports it; unavailable capabilities retain a clear
disabled/loading/error tooltip path.
Standard Slider owns numeric selection; volume's linear/logarithmic conversion and
outer GestureDetector wheel steps remain in `controls.lua`. `progress_bar_height`
is retained as the existing PlayerThemeData configuration field.
Metadata fallback, idle state, and the description preview/panel also remain inside
the same tree; idle mode does not retain player pointer regions.
The description panel supports link selection/open through `HostActions`, while
optional download and SponsorBlock data remain capability-driven.
The default top/bottom backgrounds use ModernX's blurred one-pixel edge treatment rather than a
full gray controller fill.

Internal composition is divided between `controls.lua` (playback/timeline/track/volume),
`text_controls.lua` (text hover and click state), `visuals.lua` (styles and background edges),
and `data.lua` (snapshot selectors and formatting). These helpers are not a stable SDK.
Hover glow paints a second blurred glyph at the foreground position; disabled controls
use ModernX alpha 215 and do not claim clicks. Background source rectangles sit outside
the viewport to avoid an internal seam. Tooltip position/text updates paint directly,
reuse the input snapshot, and do not rebuild or relayout the player. Slider labels use
an explicit bottom-center anchor at the slider top, below any thumbfast preview.
AutoHide policy changes notify retained tooltip State at fade start, clearing
the external preview and suppressing requests until the next visible hover.
Nested visibility, controller replacement and capability loss use the same cleanup.
Thumbnail request, label and frame share rounded host-pixel coordinates; the theme's
`thumbnail_border`/`thumbnail_border_radius`/color/outline default to ModernX's
1px white frame with a black outline. The frame uses the existing Canvas.
Text hover uses fully opaque glow; the volume handle remains visible at the same size
before and during hover. `Main.left_controls`/`right_controls` accept `PlayerControlBar`
groups of scaled 24×24 cells with 45-unit steps. Left contributions start after the
visible volume controls; right contributions start to the left of pin. Each group
appends inward in registration order and hides if it cannot clear the center controls.
Empty groups reserve no space. `PlayerControlButton` shares the built-in icon styles.
The production Define targets are `app.extension`, `app.window_layer` (`set`/`replace`)
and `player.controls.left`/`right` (`append` only); the former single-button slot is
removed. See [PLAYER.md](../../dev/design/PLAYER.md).

`PlayerThemeData.layout_option` selects `original` or `reduced`. Both use the finite
`Positioned` parent-data contract for controller, seekbar, metadata, side controls and window
controls; the two profiles keep separate seekbar/title/chapter geometry rather than reusing a
single scale as a layout substitute.
