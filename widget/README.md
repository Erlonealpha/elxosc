# Widget

`widget/` owns the immutable declaration layer, Element lifecycle, State rebuilds,
binding, and the public widget library. It must remain independent of mpv.

## Public entry points

- `widget.lua` — Widget base classes and type/key reuse rules.
- `builder.lua` — semantic `ContextBuilder`/`SlotBuilder` contracts and runtime
  callback, mounted-context and `Widget|nil` result validation.
- `element.lua` — mounted Element classes and Widget-to-RenderObject connection.
- `state.lua` — State lifecycle, `set_state`, ticker/controller ownership.
- `build_scope.lua`, `build_owner.lua`, `binding.lua` and `widgets_binding.lua` — BuildScope,
  rebuild queue, inactive/finalize handling and render-tree assembly. `WidgetsBinding` is the
  canonical singleton composition; `WidgetBinding` is the same class alias. Use
  `WidgetsBinding.ensure_initialized():attach(...)` for each additional tree.
- `slot.lua` — initialization-only `SlotSpec`, `SlotWrap`, immutable
  `Contribution` snapshots and `CompositionAssembler`.
- `bind.lua` — the small Define `bind(slot_id, widget, opts)` facade.
- `provider.lua` — inherited Provider lookup with `of` and `maybe_of` helpers.
- `player_context.lua` — host-independent `PlayerSnapshot`, `PlayerStore`, selector
  subscriptions, `PlayerScope`, `PlayerProvider`, and the `PlayerCapability` state
  consumer.
- `ambient.lua` — `ThemeData`, `Theme`, `DisplaySnapshot`, `DisplayScope` and
  `DefaultTextStyle` application ambients.
- `actions.lua` — the host-independent `HostActions` callback contract and scope,
  including relative/absolute seek, playback, playlist/chapter, track/audio, window and
  message actions with capability presence checks.
- `visibility.lua` — `Opacity`, `Offstage`, `Visibility`, `AutoHideController` and `AutoHide`,
  including frame-clock fade and optional top/bottom-hover reveal policies.
- `overlay.lua` — the single-owner `Overlay`/`Theatre` runtime and `OverlayEntry` lifecycle.
- `navigation.lua` — immutable `Page`/`PopupPage`, runtime `Route`, `Navigator`, results and
  the host-independent `ModalBarrier`.
- `app.lua` — generic `WidgetsApp` ambient wrapper and compatibility aggregate for player classes.
- `player/` — default player shell components (`Main`, `WindowLayer`, `DefaultApp` and
  `Timeline`); `widget/app.lua` retains the `WidgetsApp` ambient wrapper and compatibility
  exports for the player classes.
- `key.lua` — `ObjectKey` and `GlobalKey` extensions over the foundation key hierarchy.
- `widgets/` — independent layout, content, input, button, Tooltip, Slider, HoverText
  and progress-bar widgets, including
  `Stack`/`Positioned` root-relative placement;
  `basic.lua` and `layout.lua` are compatibility aggregates.

Widgets are immutable after construction. Runtime changes use State or explicit
RenderObject setters. Define contributions are sealed and assembled into a fresh
Widget description before mounting; the binding only mounts, updates and disposes
that description and never applies contributions itself.

`PlayerStore:subscribe_selector()` receives a selected value only when that value
changes; the default comparison is structural for readonly snapshot tables. Missing
capabilities return an explicit `unavailable` state, while host adapters publish
`loading`/`available`/`error` through immutable snapshots.
Readonly views keep their backing data alive while retained by callers. Forward
view caches use weak keys and values so discarded snapshots and nested views can
be collected on LuaJIT; a live store retains only its current snapshot.

### Builder contract

Builders remain semantic categories rather than one variadic callback:

- `ContextBuilder`: `BuildContext -> Widget?`; used by `Page` and `OverlayEntry`,
  and called only from an active mounted Element context;
- `SlotBuilder`: `(Widget|Widget[]|nil, opts) -> Widget?`; used during sealed
  initialization assembly and never receives a mounted context;
- `StatelessWidget:build` and `State:build`: mounted Element rebuild callbacks,
  validated through the same `Widget|nil` result boundary.

`widget.builder.call_context` rejects an inactive/unmounted context, while
`call_slot` preserves the pre-mount assembly boundary. All categories allow nil
to mean an empty subtree and reject other return values with a named `TypeError`.
Builder exceptions preserve their original error; failed child creation is cleaned
up by the normal Element/BuildOwner mount path, and a failed rebuild keeps the
previous child reachable until a later successful rebuild. Repeated invalidation
is coalesced by the owning BuildScope. Builders must not register one-shot host
resources, mutate mounted Widgets, or reload Define source.

The R1 operations are `replace`, `set` and `append`. `replace` is last-valid-wins,
`set` is first-valid-wins with a diagnostic for later values, and `append` is
ordered by the SlotSpec's priority/identity/position rules. `SlotWrap` is an
initialization declaration and must not remain in the mounted tree. Invalid or
unresolved contributions are diagnosed and ignored without mutating the caller's
Widget or options tables.

The concrete WidgetsBinding is shared within one runtime. Each attached WidgetTree owns its
BuildOwner, root Element, PipelineOwner/RenderOwner scope, dirty state and GlobalKey registry;
disposing one tree does not dispose the shared Binding or other trees.

Disposal/finalization locks the BuildOwner against rebuilds and State mutations.
Failed disposal still releases child States, resources and keys; failed mounts clean
up their partial tree. Overlay/Route result notifications run after finalization,
when surviving State may safely rebuild. `WidgetsBinding.shutdown()` explicitly
ends the runtime and permits a later clean initialization. Injected schedulers and
PipelineOwners remain caller-owned; internally created PipelineOwners are released
with their tree. App shutdown also finishes host cleanup when user disposal throws.

### Migration aliases

`WidgetBinding` and `RenderOwner` remain identity aliases during migration. Production
App construction uses `widget.widgets_binding` and `render.pipeline_owner`; retained
callers are the `widget/binding.lua`/`build_owner.lua` ownership annotations, render
node owner annotations, the implementation in `render/render_owner.lua`, and older
flat `test/test_*.lua` fixtures. `widget/framework.lua` is not a runtime entry point.
The Key hierarchy is defined only in `foundation/key.lua` and `widget/key.lua`.

Delete the old exports in the next breaking-name migration after converting those
callers/annotations and documenting external migration. Keep identity regression
tests until that removal commit; migrate the RenderOwner implementation and its type
name together. Roll back a failed migration as one commit, never introduce a second
class or fallback constructor. New callers use canonical names.

`PlayerStore` replaces immutable snapshots and exposes disposable subscriptions.
`PlayerScope` owns the subscription and rebuilds a `PlayerProvider` through the normal
State/BuildOwner frame pipeline. `SomeProvider.of(context)` and
`SomeProvider.maybe_of(context)` are listening lookups and are valid from `build()` or
`did_change_dependencies()`. `SomeProvider.read(context)` and
`SomeProvider.maybe_read(context)` are non-listening lookups for initialization and event
callbacks. They do not read `mp` or mutate a mounted Widget.

The Provider API follows the project's minimal `InheritedWidget` model: `of` returns the
Provider Widget, not a `package:provider` value-container result. Lookup uses exact runtime
class identity. `BuildContext` is currently an `Element` alias for implementation
simplicity; callers must treat it as a read-only context handle.

`WidgetsApp` supplies the application ambients without requiring `mp`. `DefaultApp` owns one
logical `Theatre` with stable Main, Extension and WindowLayer entries. `Main` uses a configurable
uniform layout scale, a flow-based player shell, fixed-layout `Timeline` and explicitly
injected `HostActions`. Progress/buffer/handle updates use paint-only RenderObject setters;
bar height and layout scale remain layout-affecting. `AutoHide` only changes the Main entry;
the Extension entry remains mounted and keeps its State when Main is hidden.

`AutoHide` uses a persistent `Opacity` render object for fade transitions. Fade-out retains
painting and pointer capture until completion; completed hidden content has no hit test or pointer
regions, while `maintain_state=false` unmounts it on the following build pass.
At policy changes it calls the internal `did_auto_hide_visibility_change()` hook
on retained descendant State. Player tooltips use this to release external hover
resources at fade start without changing ordinary input/capture eligibility.

Button hover/pressed visual changes use the persistent `RenderGesture`/`RenderTransformBox`/
`RenderDecoratedBox` setters; they do not default to rebuilding the button subtree. Hover scale
invalidates input as well as paint, while color/decoration changes remain paint-only.

`OverlayEntry` builders execute from a mounted entry context. Visible entries paint in insertion
order; an opaque entry makes lower entries occluded. Occluded or hidden entries remain mounted
through `Offstage` when `maintain_state` is true, otherwise they are removed and disposed on the
next build flush. `OverlayState` publishes a generation-stamped eligibility plan, while the
single Widget/Element/RenderObject owner remains authoritative.

The old nine-region scaffold, fixed grid ids and `more` are not part of the current application
entry. The default application exposes the controlled Define targets `app.extension`,
`app.window_layer` (`set`/`replace`) and `player.controls.left`/`right` (`append` only).
Main shell fields are not implicit targets. Config/API hot updates only feed
State/Provider or explicit setters. They do not mutate mounted Widgets or reload
extension code.

`Navigator` is the lightweight runtime page owner layered on the same `Theatre`. `Page` builders
are lazy and run only from mounted route entries. Matching page class/key pairs reuse their
`Route` and content Element; removed routes are detached from the Theatre before their result is
completed and their dispose callback runs. `PopupPage` contributes a real barrier/content pair;
the barrier may dismiss the current route without creating another owner or presenter. A root
Navigator with no child route ignores pop/ESC.

See [widgets](../dev/design/WIDGETS.md), [host/Define](../dev/design/HOST.md), and
[player application](../dev/design/PLAYER.md).
