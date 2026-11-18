# Widget、Element 与控件

本文负责声明式 Widget 树、Element 生命周期、State rebuild、绑定和控件 API。

## 当前组织

基础 widgets 与 Material 分层，player/Define 不属于框架目录。通用 WidgetsApp 与
host App 不默认加载或订阅 player。路径和资源边界见
[DESIGN.md](DESIGN.md#目录与模块入口)，扩展提示见 [meta](../../meta/README.md)。

## 组件归属

公共 collector 使用 widgets/material，基础源采用 src.widgets.*，
样式源采用 src.material.*。删除旧 widget、widget.widgets 和 basic/layout 二次整合入口，
所有调用者迁到 owning source 或新 collector。整合表仍仅导出成员，不附加子模块。
RenderSlider/RenderLinearProgressIndicator 的视觉字段由上层显式提供；Material wrapper
保留当前默认值。Icon 的 bundled font 默认作为资源兼容约定保留，字体/variation
约定独立于 glyph/layout 实现，Material 提供命名字体集合入口；自定义字体不携带该约定。

当前 runtime 与基础组件在 `lib/src/widgets/` 扁平
组织，Widget 基类对应 framework.lua；Element/State/Binding/Builder 等各保留功能文件。
布局、文字、CustomPaint、gesture、Provider、Visibility、Overlay/Navigator、通用
Tooltip/HoverText/Icon 属基础 widgets。设计 Theme 和整个按钮 family、现有有样式
Slider/LinearProgressIndicator 属 `lib/src/material/`，Material 重导出 widgets。
widgets 不反向 require Material/player/Define。

WidgetsApp 已只提供 display/default_text_style/child/key；默认文字保持 14px TextStyle。
Theme/PlayerTheme/HostActionsScope/PlayerScope 由 Material/player 的上层 assembly 明确包装。
PlayerContext、HostActions、Timeline 与 AutoHide 归 player；bind/DSL/Slot/SlotBuilder 归
define。ContextBuilder/call_context 与通用 callback/result 校验仍归框架，define.builder
复用该校验而保持 SlotBuilder 的挂载前参数边界。

RenderSlider/RenderLinearProgressIndicator 的数值、输入、layout/dirty 与配置校验留 render；
设计颜色/尺寸默认移到 Material wrapper，render 接收明确 config，不引用 Material Options。
Timeline 已迁到 player，继续继承同一 RenderSlider。HoverText 改用基础 gesture/text visual
机制解除 ButtonBase 依赖，保持 hover/点击效果。Icon 当前字体/variation API 与默认视觉
保持，生成的字体声明为框架资源；当前没有 RawIcon 或完整图标主题 API。

Tooltip 不再识别 AutoHide 类/私有 State hook。它提供通用取消/可见性清理边界，player
适配在 fade 开始立即释放 thumbfast，并维持淡出期间的现有 pointer capture。Opacity/
Offstage/Visibility 的 paint/input 生命周期不随 AutoHide 迁出而改变。

模块名和类型规则见 [架构](ARCHITECTURE.md)。

## Widget 不可变

`TextLayoutScope({layout, generation, child})`位于基础ambient模块，提供最近树作用域的
文本服务。Text显式text_layout优先；否则监听scope的layout identity及generation，
最后回落无宿主资源的module default。更新scope沿正常Inherited/build流程重新布局，
不替换可复用的RenderText。Tooltip在dependency更新时丢弃旧paragraph并请求paint；
其文本准备当前仍在paint，局部准备和帧内合并属于后续消费者能力。

Widget 是轻量描述，不负责 lib/src/layout/paint，也不在 mount 后修改自己的 child 或
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

当前只提供 inactive/finalize 基础语义，不宣称 GlobalKey 跨父节点 reparent。不同
tree handle 不得共享 dirty queue、BuildOwner、PipelineOwner、GlobalKey registry 或 root
frame state；它们共享 concrete Binding composition。App shutdown 只释放自己的 tree/owner，
不自动 dispose 共享 Binding。

dispose/finalize 在 BuildOwner 的锁定阶段执行；该阶段的 `set_state`、dirty scheduling、
直接 rebuild 和 root update 必须在产生副作用前报错。异常仍释放 State resources、
GlobalKey 和 Element/tree 引用，锁定状态在异常后恢复。已卸载 State 的 `set_state`
继续返回 false。`WidgetsBinding.shutdown()` 是显式 runtime 结束入口：清理 attached
trees 并释放 singleton registry；App shutdown 仍只结束自己的 owner scope。

`WidgetTree` 释放自己创建的 PipelineOwner；调用方注入的 PipelineOwner/Scheduler 由
调用方释放。Binding 不接管 host timer、presenter 或输入 section。

## Builder contract

Builder 回调按语义分为三类，不提供接受任意参数的统一回调：

1. `ContextBuilder`：`BuildContext -> Widget?`，由 `Page` 和 `OverlayEntry` 使用，只能在
   active mounted Element 的 build 阶段执行；
2. `SlotBuilder`：`(Widget|Widget[]|nil, opts) -> Widget?`，由 `SlotSpec` 在 seal 后的
   `CompositionAssembler` 阶段执行，此时不能读取 mounted context 或 Provider；
3. `StatelessWidget:build` / `State:build`：由 Element rebuild 管线调用，使用同一个
   `Widget|nil` 返回值边界。

`lib/src/widgets/builder.lua` 提供 `call_context`、`validate_context` 和 `validate_result`；
`define/src/builder.lua` 复用校验并提供 `call_slot`。它们只负责 callback/context/result 的边界验证，不持有 Widget tree 或
host 状态。nil 表示空子树；其他返回值在所属边界报 `TypeError`。Builder 抛出的原始错误
保持不变；失败 mount/rebuild 由 Element 的既有部分树清理和后续恢复语义处理。BuildScope
对重复 dirty 通知去重，因此同一 Entry 的多次 invalidation 在一次 flush 中只执行一次
builder。Builder 不得在 build 中注册一次性 host observer、修改 mounted Widget 或执行
Define source reload。

Overlay/Route 的完成通知通过 `BuildOwner:after_finalize()` 在子树 dispose 和锁释放后
执行，顺序为内容 State 清理 → Page.on_pop → result listeners → Page.on_dispose。
结果监听器可更新仍存活的 State；WidgetTree 在 layout 前处理这轮新增 dirty。

现有 class identity alias 见 `lib/src/widgets/README.md`；不保留旧模块路径 fallback。

## Key identity

Key 层级位于 `lib/src/foundation/key.lua`：`Key → LocalKey → ValueKey/UniqueKey`；
`ObjectKey` 和 `GlobalKey` 由 `lib/src/widgets/key.lua` 扩展。LocalKey 只要求同一父 Element
的直接 children 唯一；重复 LocalKey 产生 BuildOwner diagnostic。GlobalKey 在一个
BuildOwner 内注册、查找和检测重复，unmount/finalize 后清理 stale entry。

Key 只用于 Widget/Element reconciliation。Define Slot 的 contribution identity、append
顺序和 priority 与 Widget.key 分离，Slot 不得覆盖 Widget.key。

## 控件层

`lib/src/widgets/` 与 `lib/src/material/` 按职责拆成：

- 布局：Padding、Align、SizedBox、Container、Flex/Row/Column、Stack、
  ConstrainedBox、LimitedBox、OverflowBox、UnconstrainedBox、FittedBox、
  OffsetBox、TransformBox、LayoutScaleBox；
- 内容：Text、Icon、CustomPaint；
- 通用输入：GestureDetector、HoverText、Tooltip；
- Material 样式：Theme、Button 及其样式/变体、IconButton、Slider、LinearProgressIndicator。

widgets 和 material collectors 只重导出独立模块成员；旧 basic/layout 聚合已删除。
新增控件应优先创建所属层独立模块，再补 collector、模块 README 和加载/行为
测试。

生产模块表统一使用 `elxosc.mod.<canonical require>`，通过 `@namespace`/`@using` 简写。
直接模块和 collector 保持对象 identity。`{ name, exports }` 描述保留类型化成员，
基础 widgets 不包含 Slot/bind/DSL/player 内容；这些从 owning 包获取。
静态包由 framework/player/Define 各自 catalog 收集，host.package_catalog 合并注册；
默认 builtins 由 host.builtins 手选。扩展可通过 `import_as` 局部引用
完整包。类型名前缀不改变运行时 require 或 import 包名。

`Tooltip` 在原树中绘制 hover 标签，默认按实际 child 尺寸居中；显式 anchor/bounds
使用同一逻辑坐标空间。标签测量只在文本/样式改变时进行，pointer 移动只标记 paint，
保留输入 snapshot 和 child click/capture。AutoHide 隐藏和 State.dispose 调用 hover
清理 hook；外部预览由调用方通过 hook 接入，标准组件不读取宿主 capability。
`PlayerTooltip` 只提供播放器默认样式。

`Slider` 独立负责有限 `min <= max` 区间内的受控数值选择、可选 `divisions` 和
`secondary_track_value`。`on_changed(value)`、`on_change_start(previous_value)` 和
`on_change_end(final_value)` 分离；取消也通过 end 完成交互。缺少 changed 回调或
空区间禁用输入。Widget 发布新 value 才改变显示值，RenderSlider 始终复用，值更新
只标记 paint。默认水平轨道有留白、thumb/overlay 和明确 disabled 样式；无界布局使用
144 逻辑像素轨道加留白。当前支持 tap-and-slide；wheel 由外层 GestureDetector 决定。

`LinearProgressIndicator` 只读显示 0..1 进度，finite value 在边界 clamp；nil 表示
不确定进度，通过 State-owned ticker 在 Scheduler/frame clock 上更新 paint。确定进度
和 dispose 停止 ticker，不确定模式要求 Scheduler。它没有 thumb、seek 或 pointer API。
播放器 `Timeline`/`RenderTimeline` 在 Slider 基础上扩展章节/cache/range 绘制与媒体
seek phases，核心拖动/capture 复用 RenderSlider。原混合 ProgressBar/SeekBar 入口移除。
volume 的对数映射与 timeline seek 仍属于播放器业务层。
`HoverText` 复用 ButtonBase 的 foreground/glow paint-only 更新，播放器时间格式
切换保留在 `PlayerTimeDisplay` State。

参考本机 Flutter `9b575904345`：
[`slider.dart`](https://github.com/flutter/flutter/blob/9b575904345/packages/flutter/lib/src/material/slider.dart)
的受控数值、独立回调、空区间禁用和 track/thumb；
[`progress_indicator.dart`](https://github.com/flutter/flutter/blob/9b575904345/packages/flutter/lib/src/material/progress_indicator.dart)
的 determinate/indeterminate 划分和 ticker 生命周期。
这里实现该行为分离与当前框架绘制/输入契约，不宣称完整 Material、focus、semantics、
RangeSlider 或 SliderTheme shape API；ASS 动画仍为每帧静态输出。

## 绑定和插槽

Define 的公共组合边界由 `SlotSpec` 声明。`SlotWrap(SlotSpec(...))` 只存在于
初始化 Widget 描述中；`CompositionAssembler` 在 seal 后按当前组合树解析它，输出
fresh Widget 描述，mounted tree 不保留 Slot wrapper。普通 Widget 的 `id`、
`child/children` 不是自动公开的 Define target。

`bind(slot_id, widget, opts)` 收集不可变 `Contribution` 快照。允许的操作是：

- `replace`：最后一个有效贡献胜出，并重新读取 replacement 的 SlotSpec；
- `set`：保留 Slot host 的组合边界，首个有效贡献生效，后来者产生诊断；
- `append`：由 SlotSpec 处理 priority、生成 identity、数量限制和 `first`/`last`/
  `before`/`after` 相对位置。

贡献、默认值和 opts 在收集/组装时复制；caller 不能设置 append identity/key。
非法、未知或最终 unresolved 的贡献只产生带 scope/slot/op 的诊断并忽略，不修改
默认描述，也不执行 runtime unbind、rollback 或 root rebuild。`WidgetTree`/Binding
只负责 mount、update、rebuild、dispose，不再接受 bind registry 或执行 apply。

## WidgetsApp、DefaultApp、Main 与扩展区域

播放器应用组合为：

```text
PlayerApp
├── Theme / PlayerTheme / HostActionsScope
└── WidgetsApp（DisplayScope / DefaultTextStyle）
    └── PlayerScope（由播放器 host 适配提供）
        └── DefaultApp
            └── Theatre（单一逻辑 Overlay owner）
                ├── ExtensionEntry
                ├── MainEntry → AutoHide → Main
                └── WindowLayer（空根或受控内容）
```

`WidgetsApp` 只提供 host-independent display/default text ambient；`host/mpv_app.lua`
提供当前显示尺寸，`host/mpv_player_app.lua` 通过 PlayerApp 和 PlayerScope 包装主题、
受控 actions 与媒体状态。`Text` 在没有显式 style 时读取 `DefaultTextStyle`。
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

`Overlay`/`Theatre` 是同一个 class object，不是第二套 runtime。一个 Entry 和它的
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

Navigator 在同一 Theatre 上提供轻量 `Navigator`、`Page`、`Route`、`PopupRoute`、结果句柄和
`ModalBarrier`，不创建第二个 owner、Canvas 或 surface。`Page` builder 延迟到 mounted
route entry 中执行；相同 page class/key 复用 Route 和内容 Element，删除的 route 先从
Theatre reconciliation 中移除，再完成 result 和 dispose。空 root Navigator 不处理
pop/ESC；Popup 的 barrier/content 是同一 Route 的成对 entries。

## BuildContext、Provider 与播放器状态

当前 `BuildContext` 是 `Element` 的类型别名，并支持基于精确运行时 class identity 的
InheritedWidget 查询：监听式 `depend_on_inherited_widget_of_exact_type()` 和非监听式
`get_inherited_widget_of_exact_type()`。`lib/src/widgets/provider.lua` 在此基础上提供稳定的
`Provider.of(context)` / `Provider.maybe_of(context)` 入口；具体 Provider 可以通过
`SomeProvider.of(context)` 和 `SomeProvider.maybe_of(context)` 查询最近的同类祖先。

player 提供 `PlayerSnapshot`、`PlayerStore`、`PlayerScope` 和 `PlayerProvider`。Store
只替换快照，不原地修改快照；订阅按注册顺序通知，并返回可幂等 `dispose()` 的句柄。
只读视图被调用方持有时拥有 backing snapshot/table；正向缓存同时弱化 key/value，
反向映射只弱化 key。LuaJIT weak-key 表没有 ephemeron 语义，不能用强 value 回指
key 的缓存保存旧快照。丢弃的视图可回收，仍存活的原始快照可重新生成只读视图。
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
- 对应 RenderObject setter 正确区分 lib/src/layout/paint dirty。
- 独立模块、聚合入口和 `std.class` identity 有测试。
- 需要 host 能力时通过回调、State 或 Define module 注入，不 require `mp`。
