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
  Each interaction retains its starting seek callback across rebuilds and releases
  it on end/cancel. Default controls pause on changed drag movement, then restore
  only their own pause; click and initially paused media keep their playback state.
- `src/auto_hide.lua`: frame-clock inactivity, scaled wake zones and local fade.
- `src/tooltip.lua`: player style and hover eligibility for nested AutoHide ancestors.
  PlayerTimeTooltip retains PlayerTimeWidth in State across parent rebuilds.
  The width helper prepares ten digit-run candidates per format/sign/suffix and
  shape environment, then checks every actual whole label. Observed width cannot
  shrink within that template; replacement environments reset it. Candidates are
  not a universal proportional-font upper bound. Helpers retain at most 32 templates.
- `src/layout.lua`, `geometry.lua`, `controls.lua`, `visuals.lua`, `data.lua`,
  `description.lua`, `text_controls.lua`, `theme.lua`: default shell and media policy.
- `src/extension_controls.lua`: appended bottom button bars and themed buttons.

The targets are `app.extension`, `app.window_layer` (`set`/`replace`) and
`player.controls.left`/`right` (`append`). Right buttons append inward from pin;
empty groups reserve no space. Define assembles fresh descriptions before mounting.

Time/description/file-size previews keep their allocated anchors while their
interactive content shrinks to a measured box (or time reservation). Long content
clips within the available width, so blanks and neighboring controls remain passive.

AutoHide changes only Main. At fade start it refreshes descendant hover policies;
PlayerTooltip clears thumbfast immediately and blocks fading preview requests.
Nested hiding, controller replacement, capability loss and disposal preserve cleanup.
Input capture remains until fade completion. Thumbnail/frame/text use shared rounded
pixel coordinates and the existing white border/black outline.

`host/mpv_player_app.lua` owns mpv observer/actions/activity assembly and gives the
generic App one context cleanup hook. App still owns frame/tree/input/presenter resources.
Host Define adds `get_snapshot`/`on_update` to the player package without changing classes.

`package_catalog.collect()` explicitly lists the root and all runtime sources.
Extensions use `import_as('player.context')` for snapshot/store primitives; the old
`player_context` package name has been removed. The root uses framework export to
collect selected public components; `PlayerIcons` remains the existing named API.
Module types use `elxosc.mod.player.*` and instances/options use `elxosc.player.*`.
The extension [meta entry](../meta/README.md) selects the host-augmented player type
for `import_as('player')`, including disposable snapshot subscriptions.

See [player design](../dev/design/PLAYER.md) and [host lifecycle](../dev/design/HOST.md).
## Local snapshot consumers

`player.src.context.PlayerSelector` subscribes to selected Store values and owns
replacement/disposal of its subscription. Without a Store association it reads the
nearest manual PlayerProvider snapshot. Main holds its default description;
timeline progress and time labels rebuild through local consumers. Other snapshot
changes, theme and display dependencies retain normal rebuild behavior.
PlayerProviderElement separates Store identity from full snapshot notification;
full lookups upgrade dependencies, and ordinary unmount clears registrations.
