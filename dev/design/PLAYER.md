# MPV 播放器应用与扩展页面

本文规划在现有 elxosc 框架之上构建播放器应用层。它不改变已有基础框架和
Define 的核心不变量，而是定义 Root、Pages、播放器主界面、扩展区域、配置热更新
和多层 overlay 的组合方式。

## 应用构成

目标结构如下：

```text
Root
└── Pages
    ├── Main
    │   ├── title bar
    │   ├── timeline
    │   ├── bottom buttons
    │   └── left/right buttons
    │       (controls expose stable ids and shortcut metadata)
    ├── 3x3 grid
    │   └── extension regions
    └── more
        └── extension regions
```

`Main` 是播放器内置页面和固定 UI 的所有者；标题栏、时间线、底部按钮、两侧按钮
等位置由播放器定义。3×3 grid 和 `more` 是扩展可以使用的稳定区域，但区域的布局
约束仍由 Pages/播放器控制，扩展只提供内容。

当前 `main_layout.lua` 的三行三列 scaffold 是这一模型的早期基础，不等同于最终
`Pages` API。下一阶段先把当前固定 region id 迁移为 Pages 的明确契约，再考虑页面
列表和导航；不自动引入 Navigator。

应用 Widget 树由 `MpvApp → MaterialApp → WidgetsApp` 建立 ambient 环境，并在其下
组合 `DefaultApp({ main, extension, popup })`。`DefaultApp` 的三个字段是同一 Widget
树内的声明式 child，按 Main、Extension、Popup 顺序绘制；它不等同于 host-level
overlay layer。需要独立 presenter、z-order、visibility、input policy 或 pointer
capture 的内容继续由 `OverlayHost` 管理，不能通过 `DefaultApp` 绕过 host layer 契约。

## Define 是扩展唯一入口

Define 是用户扩展向播放器提供内容的唯一入口。扩展通过 Define 传入 sandboxed
Lua 内容，内容可以：

- 向 Pages 暴露或注册页面内容；
- 向 3×3 grid 或 `more` 的命名区域提供 Widget；
- 声明扩展自己的 StatefulWidget、配置和事件处理；
- 使用宿主注入的受控 API 与播放器通信；
- 按播放器暴露的接口把自己的定义页面添加到 Pages。

Define 本身只负责 transport、sandbox、scope、模块和内容交付。它不规定扩展内容
的运行时行为，不替扩展决定状态机、页面内部交互、配置响应或 overlay 使用方式。
扩展内容可以使用播放器预先提供的更新接口，也可以在 Define 允许的范围内设计
自己的消息/API 协议。

当前实现仍保持初始化期 Define 语义：每个 `scope_id` 只接受第一个 payload，绑定
在 mount 前应用，不能运行时 unbind、回滚或直接编辑已挂载 Widget 树。`pages` 和
`overlay` 是 Define sandbox 中由宿主注入的 scope-bound 声明 facade；它们在 seal
后分别交给 Pages 和 OverlayHost 一次性组装，不把 Define 变成通用运行时树管理器。

## Pages 和区域所有权

计划引入 Pages 组合层，至少包含：

| 区域 | 所有者 | 扩展能力 |
| --- | --- | --- |
| `main` | 播放器 Shell | 使用固定子区域和稳定 id；扩展通过公开 API 影响允许的内容 |
| `grid.top_left` … `grid.bottom_right` | Pages | 提供 Widget 内容，按目标区域约束布局 |
| `more` | Pages | 提供一个或多个扩展入口，具体呈现由扩展内容决定 |

区域的 single-child/multi-child 规则、冲突策略和排序必须在 Pages API 中明确，不能
让扩展依赖底层 `BindRegistry` 的偶然遍历顺序。建议：

- 内置 Main 区域通常是 single-child 或固定内部结构；
- grid 区域默认使用稳定 slot，可声明 replace 或 ordered append；
- `more` 设计为多扩展容器，提供显式 order/key；
- 区域内容在挂载前组装，运行时变化由扩展自己的 State 或播放器公开更新接口
  驱动 rebuild；
- 同一区域的冲突应在 mount 前报告 scope、region 和 operation，而不是静默覆盖。

Pages 是组合和布局根，不是导航管理器。未来如果实现页面列表，也必须先定义
page/root 声明、生命周期和冲突诊断，再决定是否需要 Navigator 风格 API。

### 6.4 离线 Pages API

当前实现位于 host-independent 的 `player/` 模块。稳定区域 ID 由
`player.region.Region` 提供：

| 区域 | 基数 | Define 扩展操作 |
| --- | --- | --- |
| `main.title_bar`、`main.timeline`、`main.bottom` | single | 播放器拥有，拒绝扩展注册 |
| `main.left`、`main.right` | single | `fill` 或按区域推导的 `add` |
| `grid.top_left` … `grid.bottom_right` | single | `fill` 或按区域推导的 `add` |
| `more` | multi | 带 `key` 的 `append` 或按区域推导的 `add` |

`PageContribution` 是不可变组装输入，记录 region、widget、scope、key、order、
operation、全局 registration sequence 和 scope sequence。`PagesRegistry` 在
初始化期提供：

```lua
pages:fill(region, widget, { key = 'extension' }, scope_id)
pages:append('more', widget, { key = 'extension-more', order = 20 }, scope_id)
pages:add(region, widget, options, scope_id)
pages:freeze()
local root = pages:assemble({ middle_child = fallback_widget })
```

single 区域只能有一个 contribution；`more` 必须使用不重复的 key。`order` 只
影响同一 `more` 区域，缺省时使用 registration sequence；它不是权限或优先级。
非法 region、错误 operation、重复 single、重复 key 和 freeze 后注册都会生成包含
scope、region、operation、key 和 sequence 信息的诊断。拒绝的 contribution 不会
删除已经接受的内容，调用方仍可组装播放器基础 Shell。

`assemble()` 每次创建新的 `PlayerScaffold`、`Main`、grid 和 `more` Widget 描述，
不修改传入 Widget 或之前构造/挂载的树。组装阶段只消费不可变 Widget 输入，不进行
Provider lookup；动态状态仍由挂载后的 Widget/State/Provider 处理。这里的 Pages
不是 Navigator，没有 runtime registry、route history 或任意 z。

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
- 结构变化通过扩展自己的 State/build 或 Pages 公开的受控更新接口完成，不能直接
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

## 多层 overlay

Pages 使用多个 host-level `osd_overlay` 层。overlay 是 presentation/host 概念，不是
Widget z-order，也不改变 Bind priority。当前实现由 `host/overlay_host.lua` 提供
OverlayHost、OverlayRegistry、OverlayInputRouter 和初始化期
OverlayDeclarationRegistry：

```text
OverlayHost
├── main       → Canvas/RenderOwner/AssPresenter
├── extension  → Canvas/RenderOwner/AssPresenter
├── popup      → Canvas/RenderOwner/AssPresenter
└── system     → Canvas/RenderOwner/AssPresenter
```

每个 layer 具有独立的：

- root Widget/RenderOwner；
- ASS Canvas 和 presenter；
- dirty/cache 状态；
- visible、z、input policy 和生命周期；
- create/update/remove 操作。

扩展只能在 Define payload 中调用 `overlay.add(id, widget, options)`；`main` 和
`system` policy 保留给播放器/宿主，扩展声明默认使用 `extension`。Define seal 后
声明被冻结并由主机一次性 mount；后续可见性、State、Provider 和 RenderObject
更新不重新执行 Define，也不注册新的内容 layer。

`overlay.z` 控制视觉优先级：数值越高的 layer 在视觉上越靠前；相同 z 使用稳定的
注册顺序作为 tie-breaker。z 只影响呈现，不影响 Widget reconciliation、Pages
区域冲突或 Define scope 优先级。

输入路由按可见且 interactive 的 layer 从高 z 到低 z 查询；选中 layer 后使用该
layer 的 RenderOwner 路径和 capture 规则。passive layer 不应因为 z 高就吞掉背景
输入，modal/exclusive layer 必须明确声明拦截策略。

每个 overlay 的事件数据仍然是当前帧静态 ASS 输出；不能使用 `\move`、`\t` 代替
FrameClock。overlay 更新、删除、z 调整和分辨率变化都必须可重复且有缓存策略。

## 实施分期

### 6.3 PlayerContext 和公共更新接口

- 完善 `BuildContext` 的 `of/maybe_of` 使用模式；
- 提供只读播放器状态/API snapshot 和订阅生命周期；
- 配置解析、校验、不可变快照和热更新；
- 扩展只通过 Define 获得这些接口。

### 6.4 Pages/Main 组合层（当前）

- 把固定 Main UI 与 extension grid/more 分开；
- 定义 stable region id、single/multi child 规则和冲突诊断；
- 提供“扩展页面添加到 Pages”的公开接口；
- Pages 注册/组装阶段只使用不可变输入；Provider `read`/`maybe_read` 只在已经拥有
  BuildContext 的 Widget/State 生命周期和事件回调中使用，consumer Widget 才能在
  `build`/`did_change_dependencies` 中建立 Provider 依赖；
- 保持 mounted Widget 不被外部直接修改。

### 6.5 OverlayHost（当前）

- 多个 AssPresenter/OSD overlay 的创建、更新、移除和 z 排序；
- 每层独立 dirty/cache 和 input policy；
- overlay 重叠输入、隐藏清理和真实 mpv 回归；
- layer policy、input callback 和移除流程使用非监听 Provider read，Widget build
  才使用监听式 lookup；
- 把 Pages layer 和 host overlay layer 的职责明确分开；`main.lua` 使用一个
  OverlayHost，把播放器主 layer 与 Define seal 后的扩展 layer 放入同一共享 pipeline。

### 6.6 可扩展播放器 Shell（当前）

- `player/shell.lua` 提供 `PlayerShell`、`ShellConfig` 和
  `ShellVisibilityController`。Shell 组合播放器拥有的 title bar、timeline、bottom
  和 left/right controls，并复用已组装的 Pages grid/more；隐藏控制不会留下 ASS
  绘制或 pointer region。
- 控件显隐模式为闭合集合 `auto`、`always`、`never`：`auto` 初始隐藏，收到 pointer
  move 显示，pointer leave 隐藏；`always` 始终显示；`never` 始终隐藏。本阶段不引入
  idle timer。
- Shell 的 `build` 使用监听式 `PlayerProvider.maybe_of`；`init_state`、pointer
  event callback 使用非监听 `maybe_read`；Provider snapshot 变化在
  `did_change_dependencies` 中重新解析；controller subscription 在 `dispose` 清理。
- `main.lua` 通过 `user-data/elxosc-controls-visibility` 把已校验的配置/API 数据
  转换为 `PlayerStore` snapshot，更新经过现有 Provider/State frame pipeline，不重跑
  Define，也不替换 Shell State。
- host 只把 mouse move/leave 观察事件转发给 controller，不安装额外的点击抢占
  section；modal 行为仍通过 OverlayHost 显式 `input_policy = 'exclusive'` 管理。

## 非目标

- 不把 Define 改成运行时 Widget tree manager；
- 不新增第二条扩展内容注入通道；
- 不默认支持 Lua 源码热重载；
- 不把 overlay.z 变成 bind 或页面优先级；
- 不在本阶段承诺 Navigator 或复杂页面导航；
- 不让根布局节点默认拦截播放器输入。

## 验收标准

- 扩展只能通过 Define 进入 Pages、grid、more 或公开 overlay 接口；
- Main 的固定区域和扩展区域边界清晰，区域冲突可诊断；
- 默认配置可运行时热更新，更新经过 snapshot/Provider/State 或明确 setter；
- 扩展代码不因配置/API 更新而重新加载或重复注册；
- 多个 overlay 按 z 稳定呈现，支持更新、隐藏、移除和缓存；
- overlay 输入按 z 和 input policy 路由，passive 层不吞背景默认输入；
- 顶层控件隐藏后没有绘制输出和交互区域；
- Pages、overlay、配置更新和输入状态都有离线与真实 host 回归边界。
