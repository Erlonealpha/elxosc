# 架构与模块边界

本文说明各层负责什么、允许依赖什么，以及三棵树如何连接。更高层不能绕过契约
直接操作低层实现；需要新能力时应在拥有该语义的层增加接口。

## 分区

| 分区 | 所有权 | 主要入口 |
| --- | --- | --- |
| `foundation/` | 无宿主值类型和数学 | `geometry`, `color`, `anchor`, `transform`, `pointer_event` |
| `painting/` | 绘制契约和值对象 | `Canvas`, `Paint`, `Path`, `TextPaint` |
| `text/` | 文本意图和布局结果 | `TextStyle`, `Paragraph`, `TextLayout` |
| `layout/` | 约束代数 | `Constraints` |
| `render/` | 持久化渲染树 | `RenderObject`, `RenderOwner` 及 RenderBox |
| `animation/` | 值插值和控制器 | `Curve`, `Tween`, `AnimationController` |
| `scheduler/` | 帧阶段和时钟契约 | `FrameClock`, `Scheduler`, `Ticker` |
| `widget/` | 声明式 UI 和生命周期 | `Widget`, `Element`, `State`, `WidgetBinding` |
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

## 运行时管线

```text
State/set_state or host input
    → dirty Element / RenderObject
    → Scheduler frame
    → transient animation callbacks
    → Widget rebuild flush
    → layout
    → paint(Canvas)
    → backend output / host presenter
```

当前没有 RepaintBoundary 或 relayout boundary；dirty 会向根传播，ASS presenter 会
跳过未变化的最终事件。性能优化不能改变公共布局和绘制契约。

## 扩展原则

- 新的几何值类型放在 `foundation`，不要把宿主格式写入值类型。
- 新的布局语义放在 `render`，再提供对应 Widget 包装；不要让 Widget 直接修改
  兄弟 RenderObject。
- 新的绘制后端实现 `painting`/`text` 契约，并通过测试验证输出，不要让 render
  读取 ASS 字符串反推布局。
- 新的宿主服务通过 `host` 或 Define module 注入，不能把 `mp` 下沉到核心层。
