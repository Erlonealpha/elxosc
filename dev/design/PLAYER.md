# MPV 播放器应用与扩展页面

本文定义现有 elxosc 框架上的播放器应用层。它不改变基础 Widget/Element/RenderObject
和 Define 的核心不变量，而是记录 `WidgetsApp`、`DefaultApp`、播放器 Main、Extension、
WindowLayer 与同一 logical root 内 OverlayEntry 的组合方式。

## 应用构成

当前结构如下：

```text
WidgetsApp
├── Theme / DisplayScope / DefaultTextStyle / HostActionsScope
└── DefaultApp
    └── Theatre（单一逻辑 owner）
        ├── ExtensionEntry
        ├── MainEntry → AutoHide → Main
        └── WindowLayer
```

`Main` 是播放器内置固定 UI 的所有者；标题栏、窗口控制、底部信息、时间线和播放控制
由播放器定义，scale 是统一正数配置并使用流式布局。`ExtensionEntry` 是当前唯一的
扩展内容边界；`WindowLayer` 由一个 Navigator 管理逻辑页面，没有初始 Page 时只有空根
语义，不创建额外 presenter/root。

当前默认入口公开的 Define/Slot 清单只有 `app.extension`（`set`/`replace`）。Main
标题栏、窗口控制、底部播放器骨架和 `window_layer` 不是扩展的隐式 target；它们只能
由播放器入口或未来另行批准的应用组合提供。

`AutoHide` 只包裹 MainEntry。Main 隐藏时通过 `Offstage` 禁止绘制、命中和 pointer
regions，但 ExtensionEntry 的 Element/State 不被卸载或重置。

旧 `main_layout.lua` 三行三列 scaffold、九个固定 id 和 `more` 已从当前生产入口删除。
Navigator/Route 由 N3 单独接入，不是 N1/N2 的隐式副作用；host-level 多 overlay 仍延期。

## Define 是扩展唯一入口

Define 是用户扩展向播放器提供内容的唯一入口。扩展通过 Define 传入 sandboxed
Lua 内容，当前可以：

- 向 DefaultApp 暴露的初始化 Slot 提供 Widget；
- 声明扩展自己的 StatefulWidget、配置和事件处理；
- 使用宿主注入的受控 API 与播放器通信；
- 在自己的 Entry 内容中管理 State 和消息生命周期。

Define 本身只负责 transport、sandbox、scope、模块和内容交付。它不规定扩展内容
的运行时行为，不替扩展决定状态机、页面内部交互、配置响应或 overlay 使用方式。
扩展内容可以使用播放器预先提供的更新接口，也可以在 Define 允许的范围内设计
自己的消息/API 协议。

当前实现仍保持初始化期 Define 语义：每个 `scope_id` 只接受第一个成功 payload。
贡献先 transaction staging，seal 后由一个 assembler 生成 fresh Widget description；
Binding 只 mount/update/dispose，不能运行时 unbind、回滚或直接编辑已挂载 Widget 树。
OverlayEntry 是 runtime State/Widget lifecycle，不是 Define 的第二条内容入口。

## 应用区域所有权

当前应用公开的最小组合边界为：

| 区域 | 所有者 | 扩展能力 |
| --- | --- | --- |
| `main` | DefaultApp/Main | 播放器固定 UI；扩展只能通过明确 Slot 影响允许内容 |
| `extension` | DefaultApp | 一个初始化期 Widget 内容边界，内部布局由扩展负责 |
| `window_layer` | WindowLayer/Navigator | 空根或受控 Page/Popup 内容，不创建第二个 runtime |

Main、Extension 和 WindowLayer 的初始内容在挂载前组装；WindowLayer 的运行时页面变化由
NavigatorState 的 `push`/`pop`/`set_pages` 驱动，不重新执行 Define。同一区域冲突仍必须
在 mount 前报告 scope、target 和 operation。

## 配置和对外接口热更新

本阶段的“热重载”收缩为**配置热更新和对外接口数据更新**，不包含 Lua 源码或扩展
模块代码重载。

默认支持的流程是：

```text
user config / public API data
    → parse and validate
    → immutable Config/API snapshot
    → Provider/State or explicit RenderObject setter
    → existing dirty propagation
    → scheduled frame
```

规则如下：

- 配置信息默认可以在 mpv 运行期间热更新；
- 播放器对外公开的数据/API 更新接口由播放器维护稳定版本和生命周期；
- 扩展需要响应更新时，可以订阅预先提供的接口，也可以在自己的 Define 内容中
  设计消息/状态协议；
- 更新接口不是第二个扩展注册入口，不能绕过 Define 注入新的 Widget 内容；
- 更新不重新执行扩展源代码，不清空 `package.loaded`，不改变 Widget class identity；
- 结构变化通过扩展自己的 State/build 或 DefaultApp 公开的受控更新接口完成，不能直接
  修改已挂载 Widget；
- 配置/API 订阅必须在扩展或 State 销毁时清理，不能重复注册。

Lua 代码热重载暂不属于本阶段。它涉及 class identity、State 保留、controller、
宿主回调和 mpv script-message 清理，应作为独立的开发工具设计。

### 6.3 当前实现

当前已提供以下最小更新链路：

```text
mpv property / host API event
    → validate / create PlayerSnapshot
    → PlayerStore:replace
    → PlayerScope subscription
    → State.set_state
    → BuildOwner / Scheduler frame
    → PlayerProvider dependents rebuild
```

核心入口位于 `widget/player_context.lua`，不依赖 mpv；宿主桥位于
`host/mpv_player_context.lua`。`App` 接受可选 `player_store` 并把 root 放入
`PlayerScope`。`MpDefine` 可以把同一个 Store 暴露为受控的 `player` module。

Snapshot 使用新对象表达新状态，Store 不修改调用方数据。订阅按注册顺序执行，返回
的句柄支持幂等 `dispose()`；App shutdown、State unmount 和 Define 扩展生命周期必须
清理 observer/subscription。配置/API 更新不重新执行 Define 源码，也不改变 Widget
class identity。

6.3 的 Provider 语义是最小 InheritedWidget 模型，不是 `package:provider` 兼容层：
监听式 `of` / `maybe_of` 返回 Provider Widget 并建立依赖，非监听式 `read` /
`maybe_read` 只读取最近的精确运行时类型。State 首次挂载和依赖更新经过
`did_change_dependencies()`；`init_state`、事件回调和 dispose 不得使用监听式查询。

## N3 Page/Route/Navigator

Navigator 是同一 logical Theatre 内的运行时页面 owner：

```text
Navigator
└── NavigatorScope
    └── Theatre
        ├── Route content
        └── PopupRoute barrier + content
```

`Page` 是不可变、惰性的 key/class/builder 描述；`Route` 保存 entry、状态和
`RouteResult`。`NavigatorState` 按 Page class/key 对齐并复用 Route；Page class 或 key 变化
会创建新 Route，重复 key 被拒绝。`push` 追加 Page，`pop(value)` 先移除当前 Page 并让
Theatre 在下一次 build flush 中卸载 entries，再按顺序调用 `on_pop`、完成 result、调用
`on_dispose`。同一个 result 只完成一次。

`PopupPage` 使用一个 `PopupRoute` 生成 barrier/content 两个 entries。barrier 是真实
`ModalBarrier` Widget：dismissible barrier 调用当前 Navigator 的 pop，非 dismissible
barrier 仍消费其区域输入但不伪造 pop。页面默认注册 ESC；有可 pop route 时 host 才启用
navigation section，无可 pop 内容时不抢占用户默认 ESC 绑定，KeyEvent 只在 section 已选中
后交给 NavigatorState。首版不提供 focus traversal、Hero、restoration、browser parser、
nested Navigator 状态恢复或复杂 transition 协商。

### N3 Demo

`main.lua` 通过 `demo.initial_pages()` 把演示首页放进 WindowLayer 的 Navigator。
`demo.lua` 的 Page builder 在 mounted context 中取得 Navigator handle；按钮事件复用
该 handle，返回结果通过 `RouteResult` 更新首页 State。

- 首页 **N3 Navigation → Open Page** 打开 opaque Page；**Back with result** 返回
  `Page: done`，ESC 返回 `Page: dismissed`。
- **Open Popup** 显示遮罩和居中卡片；**Confirm / Cancel** 分别返回
  `Popup: confirmed / cancelled`。点击遮罩或 ESC 显示 `Popup: dismissed`，点击卡片
  空白处保持弹窗打开。
- 首页的 **Result / Returns** 显示最近结果和完成次数；打开页面前修改原有计数，返回后
  可检查其 State 保留。首页不占用 ESC，继续执行宿主自己的绑定。

也可在 mpv 控制台执行 `script-message elxosc-demo page` 或
`script-message elxosc-demo popup`；不带参数仍为原有计数演示。页面打开期间重复打开命令
会被忽略。`user-data/elxosc-demo-route`、`elxosc-demo-result` 和 `elxosc-demo-returns`
提供对应观测值，Demo dispose 会释放消息注册及待完成的 result 订阅。

## N2 逻辑 Overlay 与未来 host layers

当前 `Overlay`/`Theatre` 是 framework 内单一 logical root 的 runtime；它不是 host-level
`osd_overlay`，也不改变 Bind priority。一个 Entry 和内容 subtree 只有一个 owner：

```text
Theatre
├── ExtensionEntry
├── MainEntry
└── WindowLayerEntry
```

Entries 按插入顺序生成一个 Stack。`visible` 控制自身 paint/input，顶层可见 `opaque`
entry 使下方 entry occluded；`maintain_state` 决定下方内容是通过 `Offstage` 保持挂载
还是在下一次 build flush 中 unmount/dispose。`OverlayState` 发布 generation-stamped
plan，分别记录 visible、occluded、paint、input 和 mounted 状态。N2 不实现 Route、
PopupRoute、barrier、ESC result 或 multi-surface。

未来 host-level `OverlayHost/OverlayRegistry` 仍可管理独立命名 layer：

```text
OverlayHost
├── main       → Canvas/RenderOwner/AssPresenter
├── extension  → Canvas/RenderOwner/AssPresenter
├── popup      → Canvas/RenderOwner/AssPresenter
└── system     → Canvas/RenderOwner/AssPresenter
```

每个未来 layer 才具有独立的：

- root Widget/RenderOwner；
- ASS Canvas 和 presenter；
- dirty/cache 状态；
- visible、z、input policy 和生命周期；
- create/update/remove 操作。

`overlay.z` 控制未来 host presentation 的视觉优先级：数值越高的 layer 在视觉上越靠前；
相同 z 使用稳定的注册顺序作为 tie-breaker。z 只影响呈现，不影响 Widget
reconciliation、应用区域冲突或 Define scope 优先级。

未来 host layer 的输入路由按可见且 interactive 的 layer 从高 z 到低 z 查询；选中
layer 后使用该 layer 的 RenderOwner 路径和 capture 规则。passive layer 不应因为 z 高
就吞掉背景输入，modal/exclusive layer 必须明确声明拦截策略。

所有 host overlay 输出仍然是当前帧静态 ASS；不能使用 `\move`、`\t` 代替 FrameClock。
未来 host layer 的更新、删除、z 调整和分辨率变化都必须可重复且有缓存策略。

## 实施分期

### 6.3 PlayerContext 和公共更新接口

- 完善 `BuildContext` 的 `of/maybe_of` 使用模式；
- 提供只读播放器状态/API snapshot 和订阅生命周期；
- 配置解析、校验、不可变快照和热更新；
- 扩展只通过 Define 获得这些接口。

### 6.4 N1 DefaultApp/Main（已实现）

- `WidgetsApp` 提供 Theme、DisplayScope、DefaultTextStyle 和 HostActionsScope；
- `DefaultApp` 通过单一 Theatre 组装 Main、Extension 和 WindowLayer；
- Main 使用统一 scale、流式顶部/底部骨架和受控 window/playback actions；
- AutoHide/Visibility/Offstage 只隐藏 Main，不卸载 Extension State；
- 旧九宫格、固定 region id 和 `more` 从当前生产入口删除；
- Define/Slot 仍只在 mount 前组装内容，mounted Widget 不被外部直接修改。

### 6.5 N2 Overlay runtime（已实现）

- OverlayEntry builder 在 mounted context 执行，Entry/State/Element 只有一个挂载 owner；
- visible/opaque/maintain_state、occluded plan 和 paint/input eligibility 有离线证据；
- remove、visibility/opaque/maintain_state 变更和 mark_needs_build 通过唯一 entry list
  驱动真实 mount/update/dispose；

### 6.6 N3 Navigator（已实现最小切片）

- Page/Route/Navigator 使用同一个 Theatre，Page builder 只在 mounted context 执行；
- class/key reconciliation 保留稳定 Route/Element，重复 key 和空 root pop 有明确边界；
- push/pop、RouteResult、on_pop/on_dispose、PopupRoute barrier/content 和 ESC 已覆盖；
- host 只在 `NavigatorState:can_pop()` 时启用 `elxosc-navigation`，不创建第二个 presenter；
- focus、restoration、Hero、复杂 transition、nested state restoration 和 browser parser 延后。

### 6.7 OverlayHost

- 多个 AssPresenter/OSD overlay 的创建、更新、移除和 z 排序；
- 每层独立 dirty/cache 和 input policy；
- overlay 重叠输入、隐藏清理和真实 mpv 回归；
- layer policy、input callback 和移除流程使用非监听 Provider read，Widget build
  才使用监听式 lookup；
- 把 DefaultApp/Theatre layer 和未来 host overlay layer 的职责明确分开。

### 6.8 可扩展播放器 Shell

- Main 的标题栏、时间线、底部和两侧控件；
- 可隐藏的顶层控件和 auto/always/never visibility 状态；
- N3 之后的 Shell 页面产品和未来 host layer 的组合；
- Shell 的 build 使用监听式 Provider，init/event/resource 回调使用非监听 read，
  依赖变化资源通过 `did_change_dependencies` 更新；
- 配置/API 热更新驱动 State/Provider，而非代码重载。

## 非目标

- 不把 Define 改成运行时 Widget tree manager；
- 不新增第二条扩展内容注入通道；
- 不默认支持 Lua 源码热重载；
- 不把 overlay.z 变成 bind 或页面优先级；
- 不在本阶段承诺完整 Navigator API 或复杂页面导航；
- 不让根布局节点默认拦截播放器输入。

## 验收标准

- 扩展只能通过 Define/Slot 进入 DefaultApp 的初始化扩展边界；
- Main、Extension 和 WindowLayer 边界清晰，初始化冲突可诊断；
- 默认配置可运行时热更新，更新经过 snapshot/Provider/State 或明确 setter；
- 扩展代码不因配置/API 更新而重新加载或重复注册；
- 同一逻辑 Overlay 的 entries 支持更新、隐藏、移除和真实 State dispose；
- hidden/occluded entry 没有绘制输出和交互区域，maintain_state 内容仍可保留；
- N1/N2/N3 的离线、stub 和 real-host 回归均已记录；host-level layer 仍另行验收。
