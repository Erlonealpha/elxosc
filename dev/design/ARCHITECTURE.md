# 架构与模块边界

本文说明各层负责什么、允许依赖什么，以及三棵运行时树、Pages 组合层和 host overlay
如何连接。更高层不能绕过契约
直接操作低层实现；需要新能力时应在拥有该语义的层增加接口。

## 分区

| 分区 | 所有权 | 主要入口 |
| --- | --- | --- |
| `foundation/` | 无宿主值类型和数学 | `geometry`, `color`, `anchor`, `transform`, `pointer_event`, `key_event` |
| `painting/` | 绘制契约和值对象 | `Canvas`, `Paint`, `Path`, `TextPaint` |
| `text/` | 文本意图和布局结果 | `TextStyle`, `Paragraph`, `TextLayout` |
| `layout/` | 约束代数 | `Constraints` |
| `render/` | 持久化渲染树 | `RenderObject`, `RenderOwner` 及 RenderBox |
| `animation/` | 值插值和控制器 | `Curve`, `Tween`, `AnimationController` |
| `scheduler/` | 帧阶段和时钟契约 | `FrameClock`, `Scheduler`, `Ticker` |
| `widget/` | 声明式 UI、生命周期和 Provider 状态 | `Widget`, `Element`, `State`, `WidgetBinding`, `PlayerStore` |
| `backends/` | 契约的具体输出 | `AssCanvas`, `AssTextLayout`, `RecordCanvas` |
| `libs/` | 受限 DSL 和模块共享 | `sandbox`, `ModuleRegistry`, `DefineSession` |
| `host/` | mpv 接线 | `App`, `MpFrameClock`, `MpInput`, `MpDefine` |

## 依赖规则

```text
foundation → painting/text → layout → render → widget → host → main.lua
                         scheduler ────────────────┘
backends → painting/text contracts
libs → widget/bind and host assembly
```

`render` 不认识 Widget，`widget` 不认识 mpv，`backends` 不读取 mpv 状态。宿主只
通过 `Canvas`、`TextLayout`、`FrameClock` 和输入值对象进入核心。所有模块使用裸
模块名并避免 require cycle；聚合入口必须返回直接模块导出的同一对象。

Pages 是播放器应用层的 Widget 组合契约，不是第四棵底层运行时树。它负责把固定
播放器 Main、3×3 grid 和 `more` 区域组装成一个或多个 Widget root，并暴露稳定的
扩展入口；最终仍由 Widget/Element/RenderObject 三棵树完成挂载和绘制。Define 是
扩展内容进入 Pages 的唯一入口，配置/API 热更新只是数据或事件输入，不是新的内容
注入通道。

## 三棵树的职责

### Widget tree

Widget 是不可变配置，描述子节点、选项、key 和 id。它不布局、不绘制、不持有跨帧
运行时状态。`StatelessWidget` 从输入构造子树，`StatefulWidget` 将可变状态放到
`State` 中并通过 `set_state` 请求 rebuild。

### Element tree

Element 是 Widget 的挂载实例，负责 mount/update/unmount、State 生命周期、key/type
复用、Inherited 依赖和 RenderObject 连接。相同 Widget 类型和 key 时尽量更新原
Element；结构性变化通过 reconciliation 产生新的子 Element。

### RenderObject tree

RenderObject 是跨帧持久的可变节点，负责 layout、paint、hit test、pointer path 和
dirty propagation。父节点把约束传下去，子节点返回尺寸，父节点写入
`parent_data.offset`。owner 负责 viewport、根节点、布局绘制和输入分发。

### Pages composition

Pages 位于播放器 Shell 和 Widget tree 之间的应用组合层：

```text
Root
└── Pages
    ├── Main
    ├── extension grid (3 × 3 stable regions)
    └── more (extension container)
```

Main 的标题栏、时间线、底部和两侧按钮由播放器拥有；扩展通过 Define 提供的
Pages/region API 填充允许的区域。Pages 不拥有运行时 unbind、树回滚或外部直接修改
mounted Widget 的能力。

### Host overlay layers

多个 `osd_overlay` 属于 host/presentation 层，不属于 Widget z-order。每个命名
layer 可以有独立的 root、RenderOwner、Canvas、presenter、dirty 状态、可见性和
输入策略；`overlay.z` 只决定视觉顺序，较高 z 在视觉上位于较低 z 之上。同 z 使用
稳定注册顺序，不能作为 Define scope 或 Bind priority。

## 运行时管线

```text
config/API snapshot, State/set_state or host input
    → dirty Element / RenderObject
    → Scheduler frame
    → transient animation callbacks
    → Widget rebuild flush
    → layout
    → paint(Canvas)
    → backend output / one or more host overlay presenters
```

6.3 的 PlayerStore 位于 Widget 层但不依赖 mpv：宿主只负责将 property/API 数据
校验后替换 Snapshot。`PlayerScope` 将 Store 更新转换为 State dirty，Provider
依赖者再通过既有 BuildOwner 管线 rebuild。

当前没有 RepaintBoundary 或 relayout boundary；dirty 会向根传播，ASS presenter 会
跳过未变化的最终事件。性能优化不能改变公共布局和绘制契约。

## 扩展原则

- 新的几何值类型放在 `foundation`，不要把宿主格式写入值类型。
- 新的布局语义放在 `render`，再提供对应 Widget 包装；不要让 Widget 直接修改
  兄弟 RenderObject。
- 新的绘制后端实现 `painting`/`text` 契约，并通过测试验证输出，不要让 render
  读取 ASS 字符串反推布局。
- 新的宿主服务通过 `host` 或 Define module 注入，不能把 `mp` 下沉到核心层。
- 配置/API 热更新先形成不可变 snapshot，再通过 Provider/State 或明确的
  RenderObject setter 进入现有 dirty 管线；不得重新执行扩展源代码。
- Pages 只负责应用组合和扩展区域契约；overlay 管理只负责 presentation 和 z/input
  policy，不能把两者混成一个 Widget priority 系统。
