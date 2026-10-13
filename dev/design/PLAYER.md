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
在 mount 前应用，不能运行时 unbind、回滚或直接编辑已挂载 Widget 树。Pages API
是下一阶段在这一入口之上增加的内容注册/组装接口，不把 Define 变成通用运行时树
管理器。

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

## 多层 overlay

Pages 可以使用多个 host-level `osd_overlay` 层。overlay 是 presentation/host
概念，不是 Widget z-order，也不改变 Bind priority。

计划提供一个 OverlayHost/OverlayRegistry（名称待实现）管理多个命名 layer：

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

### 6.4 Pages/Main 组合层

- 把固定 Main UI 与 extension grid/more 分开；
- 定义 stable region id、single/multi child 规则和冲突诊断；
- 提供“扩展页面添加到 Pages”的公开接口；
- 保持 mounted Widget 不被外部直接修改。

### 6.5 OverlayHost

- 多个 AssPresenter/OSD overlay 的创建、更新、移除和 z 排序；
- 每层独立 dirty/cache 和 input policy；
- overlay 重叠输入、隐藏清理和真实 mpv 回归；
- 把 Pages layer 和 host overlay layer 的职责明确分开。

### 6.6 可扩展播放器 Shell

- Main 的标题栏、时间线、底部和两侧控件；
- 可隐藏的顶层控件和 auto/always/never visibility 状态；
- 3×3 grid、more 和多层 overlay 的组合；
- 配置/API 热更新驱动 State/Provider，而非代码重载。

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
