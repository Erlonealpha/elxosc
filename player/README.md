# Player

`player/` owns media state, actions, AutoHide and the default player composition.
It does not require mp. `require 'player'` returns explicit public components with
the same classes as `player.src.*`; internal State and assembly helpers stay in sources.

- `src/context.lua`: immutable PlayerSnapshot, PlayerStore, selector subscriptions,
  PlayerProvider/Scope and capability consumers. Retained readonly views own their
  data; discarded views use weak caches and can be collected.
- `src/actions.lua`: injected playback/window/preview actions and HostActionsScope.
- `src/ambients.lua`: PlayerApp explicitly wraps Theme, PlayerTheme, HostActionsScope
  and the framework WidgetsApp. Host assembly adds PlayerScope when a store exists.
- `src/app.lua`: Main, DefaultApp and WindowLayer on a single logical Theatre.
  Main and PlayerMain are the same public class.
- `src/composition.lua`: the four initialization Slot IDs and append ordering.
  Only initialization composition depends on Define's Slot primitives.
- `src/timeline.lua`, `src/render/timeline.lua`: media Slider/RenderSlider
  specializations for chapters, cache ranges and seeking; generic numeric/dirty/
  capture behavior is inherited from the framework.
- `src/auto_hide.lua`: frame-clock inactivity, scaled wake zones and local fade.
- `src/tooltip.lua`: player style and hover eligibility for nested AutoHide ancestors.
- `src/layout.lua`, `geometry.lua`, `controls.lua`, `visuals.lua`, `data.lua`,
  `description.lua`, `text_controls.lua`, `theme.lua`: default shell and media policy.
- `src/extension_controls.lua`: appended bottom button bars and themed buttons.

The targets are `app.extension`, `app.window_layer` (`set`/`replace`) and
`player.controls.left`/`right` (`append`). Right buttons append inward from pin;
empty groups reserve no space. Define assembles fresh descriptions before mounting.

AutoHide changes only Main. At fade start it refreshes descendant hover policies;
PlayerTooltip clears thumbfast immediately and blocks fading preview requests.
Nested hiding, controller replacement, capability loss and disposal preserve cleanup.
Input capture remains until fade completion. Thumbnail/frame/text use shared rounded
pixel coordinates and the existing white border/black outline.

`host/mpv_player_app.lua` owns mpv observer/actions/activity assembly and gives the
generic App one context cleanup hook. App still owns frame/tree/input/presenter resources.
Host Define adds `get_snapshot`/`on_update` to the player package without changing classes.

See [player design](../dev/design/PLAYER.md) and [host lifecycle](../dev/design/HOST.md).
