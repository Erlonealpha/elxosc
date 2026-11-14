# Widget

`lib/src/widget/` owns immutable Widget descriptions, Element lifecycle, State,
Provider, Binding, basic layout/input and the current framework controls. It does
not import player, Define, host or mp. `require 'widget'` collects the layer;
`src.widget.*` provides direct sources with the same class identities.

- `widget.lua`, `element.lua`, `state.lua` own the three-tree connection and rebuilds.
- `build_owner.lua`, `build_scope.lua`, `widgets_binding.lua` own dirty queues,
  finalization and tree handles; `binding.lua` retains the WidgetBinding class alias.
- `builder.lua` owns ContextBuilder and callback/context/result validation.
- `provider.lua`, `ambient.lua` own inherited values, display and default text.
- `app.lua` supplies only display, default text style, child and key through WidgetsApp.
- `visibility.lua` owns Opacity, Offstage and Visibility render wrappers.
- `overlay.lua`, `navigation.lua` own logical entries, pages, routes and results.
- `widgets/` contains current layout, text, gesture and styled controls. FPK-2 will
  flatten basic widgets and move design-specific controls and Theme to Material.

Widgets remain immutable. State rebuilds and persistent RenderObject setters own
runtime updates. ContextBuilder requires an active mounted context; all build
categories reject non-Widget results, preserve exceptions and support nil subtrees.
Define's SlotBuilder reuses this validation from outside the framework.

Each WidgetTree owns BuildOwner, root, keys and a PipelineOwner scope. App disposal
preserves the shared Binding and other trees. Failed mount/finalize/dispose still
release partial children and resources; injected owners/schedulers stay caller-owned.
WidgetBinding and RenderOwner remain class identity aliases.

Tooltip accepts `hover_enabled(context)` as an optional non-listening policy.
`TooltipState:refresh_hover_visibility()` reevaluates it, clears active hover resources
once when disabled and suppresses previews until eligible again. This callback does
not alter a wrapped child's pointer capture. PlayerTooltip supplies AutoHide policy
from the player layer; the basic Tooltip never recognizes player ancestors.

See [widgets](../../../dev/design/WIDGETS.md),
[rendering](../../../dev/design/RENDERING.md) and [player](../../../dev/design/PLAYER.md).
