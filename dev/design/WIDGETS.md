# Widget、Element 与控件

本文负责声明式 Widget 树、Element 生命周期、State rebuild、绑定和控件 API。

## Widget 不可变

Widget 是轻量描述，不负责 layout/paint，也不在 mount 后修改自己的 child 或
options。构造器应复制/规范化 caller options；运行时变化放进 State 或 RenderObject
的明确 setter。

`Widget.can_update(old, new)` 以运行时类和 key 判断复用。相同类/等 key 保留
Element、State 和 RenderObject；key 改变或类型改变则重建对应实例。

## Element 生命周期

Element 负责：

1. mount Widget 并创建子 Element/RenderObject；
2. 在 rebuild 中按类型和 key reconciliation；
3. 将 RenderObject 子节点收集到正确父节点；
4. 更新 Inherited 依赖和 ParentData；
5. unmount 时调用 State.dispose 并断开运行时资源。

State 的 `init_state` 只在首次挂载调用，`set_state` 只包裹状态修改并将 element
加入 build 队列，`dispose` 必须释放 controller、ticker 和宿主订阅。State 不应在
build 中反复注册一次性宿主资源。

## BuildOwner、BuildScope 与 Binding

`BuildOwner` 是 Widget tree owner。它按 `BuildScope` 对 dirty Element 去重，以 depth 顺序
flush，并在每个 build pass 结束时处理 inactive Element 的 `finalize_tree()`。parent
rebuild 已经更新的 child 不得在同一 frame 重复 build。`WidgetsBinding` 是 Flutter-style
concrete singleton；每次 `WidgetsBinding:attach()` 创建一个 `WidgetTree` handle，handle
持有自己的 BuildOwner、root Element 和 RenderOwner/PipelineOwner。旧 `WidgetBinding`
入口仍是同一 class object，但直接构造应迁移到 `ensure_initialized():attach()`。

Element 的 runtime 生命周期允许：

```text
active → inactive → active
                 ↘ finalize → unmounted
```

本阶段只提供 inactive/finalize 基础语义，不宣称 GlobalKey 跨父节点 reparent。不同
tree handle 不得共享 dirty queue、BuildOwner、PipelineOwner、GlobalKey registry 或 root
frame state；它们共享 concrete Binding composition。App shutdown 只释放自己的 tree/owner，
不自动 dispose 共享 Binding。

## Key identity

Key 层级位于 `foundation/key.lua`：`Key → LocalKey → ValueKey/UniqueKey`；
`ObjectKey` 和 `GlobalKey` 由 `widget/key.lua` 扩展。LocalKey 只要求同一父 Element
的直接 children 唯一；重复 LocalKey 产生 BuildOwner diagnostic。GlobalKey 在一个
BuildOwner 内注册、查找和检测重复，unmount/finalize 后清理 stale entry。

Key 只用于 Widget/Element reconciliation。Define Slot 的 contribution identity、append
顺序和 priority 与 Widget.key 分离，Slot 不得覆盖 Widget.key。

## 控件层

`widget/widgets/` 按职责拆成：

- 布局：Padding、Align、SizedBox、Container、Flex/Row/Column、Stack、
  ConstrainedBox、LimitedBox、OverflowBox、UnconstrainedBox、FittedBox、
  OffsetBox、TransformBox、LayoutScaleBox；
- 内容：Text、Icon、CustomPaint；
- 输入：GestureDetector、Button 及其样式/变体、IconButton。

兼容聚合入口 `widget.widgets.basic` 和 `widget.widgets.layout` 只重导出独立模块
的同一对象。新增控件应优先创建独立模块，再补聚合入口、模块 README 和加载/行为
测试。

## 绑定和插槽

`Widget.id` 为 Define 期命名目标。`BindRegistry` 在 mount 前静态遍历 Widget 树，
向可接收 `child` 或 `children` 的目标写入 Widget：单子节点默认 replace，多子
节点默认 append；显式操作包括 replace_if_empty 和 insert。

绑定完成后不再管理运行时 Widget 树。后续 UI 变化必须由 State rebuild；绑定注册
表不提供回滚、运行时 unbind、scope shutdown 或 root rebuild。一个 scope 的多个
绑定按注册顺序保留，不引入 priority。

## WidgetsApp、DefaultApp、Main 与扩展区域

当前 N1 应用组合为：

```text
WidgetsApp
├── Theme
├── DisplayScope
├── DefaultTextStyle
└── HostActionsScope
    └── DefaultApp
        └── Theatre（单一逻辑 Overlay owner）
            ├── ExtensionEntry
            ├── MainEntry → AutoHide → Main
            └── WindowLayer（空根或受控内容）
```

`WidgetsApp` 只提供 host-independent ambient；`host/mpv_app.lua` 注入当前显示尺寸、
Theme 和受控 `HostActions`。`Text` 在没有显式 style 时读取 `DefaultTextStyle`。
Theme 不拥有播放器状态，DisplayScope 不拥有输入 section，HostActions 也不暴露原始
`mp` 给 Widget 层。

`DefaultApp` 是可替换的播放器应用根。`Main` 负责首版 ModernX 方向的顶部标题/窗口
控制、底部信息/时间线/播放控制和统一正数 scale；默认布局是流式布局而不是九宫格。
`AutoHide` 只包裹 MainEntry，隐藏 Main 不卸载或重置 Extension/Page 状态。WindowLayer
为空时返回 `SizedBox.shrink()`，不创建第二个 presenter 或 runtime root。

旧三行三列 scaffold、九个固定 id 和 `more` 已从当前生产入口删除。Define/Slot 仍是
初始化期扩展内容入口；扩展自己的 State、消息和配置/API 更新继续走正常 Widget/State/
Provider 生命周期，不能运行时 unbind、回滚或直接编辑 mounted Widget。

## OverlayEntry 与 Theatre

N2 的 `Overlay`/`Theatre` 是同一个 class object，不是第二套 runtime。一个 Entry 和它的
内容 subtree 只有一个 owner，builder 在 `OverlayEntryMountState` 的 mounted context 中
调用。Entries 按插入顺序生成单一 Stack：

- `visible` 决定自身是否参与绘制和输入；
- 顶部可见 `opaque` entry 使下方 entry `occluded`；
- `maintain_state = true` 时下方/隐藏内容保留 State，通过 `Offstage` 禁止 paint、命中和
  pointer regions；
- `maintain_state = false` 时内容从 child list 移除，并在下一次 build flush 中正常 unmount；
- `OverlayState` 发布 generation-stamped plan，分别记录 visible、occluded、paint、input
  和 mounted 状态；
- `remove()`、visibility/opaque/maintain_state 变化和 `mark_needs_build()` 都通过
  OverlayState 的唯一 authoritative entry list 驱动 reconciliation。

N2 不实现 Navigator、Route、PopupRoute、barrier 或 multi-surface；这些仍属于后续阶段
的决策范围。

## BuildContext、Provider 与播放器状态

当前 `BuildContext` 是 `Element` 的类型别名，并支持基于精确运行时 class identity 的
InheritedWidget 查询：监听式 `depend_on_inherited_widget_of_exact_type()` 和非监听式
`get_inherited_widget_of_exact_type()`。`widget/provider.lua` 在此基础上提供稳定的
`Provider.of(context)` / `Provider.maybe_of(context)` 入口；具体 Provider 可以通过
`SomeProvider.of(context)` 和 `SomeProvider.maybe_of(context)` 查询最近的同类祖先。

6.3 提供 `PlayerSnapshot`、`PlayerStore`、`PlayerScope` 和 `PlayerProvider`。Store
只替换快照，不原地修改快照；订阅按注册顺序通知，并返回可幂等 `dispose()` 的句柄。
`PlayerScope` 在挂载时订阅 Store，在 State dispose 时清理订阅，再通过
`PlayerProvider` 通知依赖者。State 首次挂载和 inherited 依赖变化都会调用
`did_change_dependencies()`，随后进入正常 build/dirty 管线；更新仍然不直接修改已挂载
Widget。

Provider 的更新必须让依赖者走既有 dirty/build 管线；控件不能直接读取 `mp`，也不能
在 `build()` 中注册一次性 property observer。监听式查询只允许在 `build()` 或
`did_change_dependencies()` 中使用；`SomeProvider.read(context)` /
`SomeProvider.maybe_read(context)` 不建立依赖，适合 `init_state` 和事件回调。播放器
配置/API 热更新形成新 snapshot，由 Provider/State 或明确 RenderObject setter 消费；
扩展通过 Define 获得允许的 provider 和更新接口，更新本身不构成新的内容注入。
`PlayerProvider.of(context)` 找不到祖先时报错，`maybe_of` 返回 `nil`；这些 API 返回
Inherited Provider Widget，不是 `package:provider` 风格的业务值容器。

## 新控件检查表

- 选项表有 `_TypeNameOptions` 类型，构造器不修改调用方表。
- Widget 字段只保存声明式配置，副作用放到事件或 State 生命周期。
- 对应 RenderObject setter 正确区分 layout/paint dirty。
- 独立模块、聚合入口和 `std.class` identity 有测试。
- 需要 host 能力时通过回调、State 或 Define module 注入，不 require `mp`。
