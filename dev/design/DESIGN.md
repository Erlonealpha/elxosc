# elxosc 当前设计

本文是 elxosc 的当前设计主文档和决策索引。它描述已经实现的架构、不可破坏的
契约以及下一步方向；代码和测试是最终事实来源，旧设计记录只用于追溯历史。

## 阅读路径

按变更范围继续阅读对应方向文档：

| 文档 | 负责的问题 |
| --- | --- |
| [ARCHITECTURE.md](ARCHITECTURE.md) | 分层、依赖、三棵树和模块边界 |
| [RENDERING.md](RENDERING.md) | 约束布局、绘制、文本、ASS、变换和动画 |
| [INPUT.md](INPUT.md) | `set_mouse_area`、输入 section、默认行为和事件重构 |
| [WIDGETS.md](WIDGETS.md) | Widget/Element/State、控件和绑定 |
| [HOST.md](HOST.md) | mpv 帧循环、输入、Define 传输和宿主边界 |
| [PLAYER.md](PLAYER.md) | Root/Pages/Main、扩展区域、配置热更新和多层 overlay |
| [TESTING.md](TESTING.md) | 测试分层、命令、fixture 和回归要求 |
| [ROADMAP.md](ROADMAP.md) | 已完成能力、已知限制和后续路线 |

模块所有权和入口见各目录的 `README.md`；历史文档位于
[`old/`](old/)，不应作为新 API 的依据。

## 项目目标

elxosc 是面向 mpv/mpv.net 的 LuaJIT UI 框架。上层用声明式 Widget 描述 UI，
中间经过 Element 和持久化 RenderObject 树，底层通过 Canvas、TextLayout、
FrameClock 和输入契约连接到宿主。当前生产绘制后端是 ASS `osd-overlay`，同时
提供 RecordCanvas 用于离线测试。

目标是保持以下性质：

- 框架核心不依赖 mpv，可以在裸 LuaJIT 和测试后端中运行。
- 布局遵循“约束向下、尺寸向上、父节点定位子节点”。
- Widget 是不可变描述，RenderObject 是跨帧持久的可变运行时节点。
- ASS 能力只在后端边界表达，不把 ASS 标签泄漏到通用布局 API。
- 动画由框架帧时钟驱动，每帧产生静态绘制输出。

## 当前架构

```text
foundation ──┬──> painting ──┬──> render ──> widget ──> host ──> main.lua
              └──> text ──────┘       ▲          ▲
layout ───────────────────────────────┘          │
animation ──> scheduler ─────────────────────────┘
backends implements painting/text and is consumed by host
libs provides sandbox/Define services and is consumed by host/entry assembly
```

框架核心按 `foundation/`、`painting/`、`text/`、`layout/`、`render/`、
`animation/`、`scheduler/`、`widget/`、`backends/`、`libs/` 分区；`host/`、
`main.lua` 和 `elxlib_load.lua` 是唯一的 mpv 边界。聚合模块必须转出独立模块的
同一个类对象，不能重新定义兼容副本。

## 三棵运行时树

1. **Widget tree**：不可变配置和声明式子树，由 `State` rebuild 产生新描述。
2. **Element tree**：保存生命周期、Widget 复用、Inherited 依赖和 State。
3. **RenderObject tree**：保存尺寸、父子位置、绘制状态、命中测试和 dirty 标记，
   在 Widget 更新时尽量复用。

`WidgetBinding` 把三棵树连接到 `RenderOwner`。布局和绘制不会修改 Widget；结构性
变化只能通过 rebuild，运行时属性变化则由 RenderObject setter 选择 `paint` 或
`layout + paint` 失效类型。

## 不可破坏的契约

### 模块边界

除 `host/`、`main.lua`、`elxlib_load.lua` 外不得加载 `mp`。模块使用裸 require
名称，例如 `require 'render.text'`，不得引入 `elxosc.` 前缀或循环依赖。

### 布局和变换

- 所有 RenderObject 在收到的 Constraints 内返回有限尺寸。
- `OffsetBox`、`TransformBox` 的平移/缩放只影响绘制和输入逆映射。
- `LayoutScaleBox` 的缩放参与子约束、报告尺寸并触发重新布局。
- 只支持有限正轴向缩放和位移；旋转、倾斜、零/负缩放和任意仿射布局不得被
  静默近似。

### 文本和 ASS

- `TextStyle.align` 只有 `left`、`center`、`right`，ASS 分别映射为 `\an4`、
  `\an5`、`\an6`。
- 显式 `TextPaint.anchor` 优先于样式对齐；Icon 等特殊内容可以使用九宫格锚点。
- `TextPaint.offset` 是绘制层视觉偏移，不改变布局尺寸或命中区域。
- 不使用 PTS 相关的 `\move`、`\t` 生成动画。

### Define、Pages 和更新边界

Define 是用户扩展内容进入播放器的唯一入口。它负责 transport、sandbox、scope、
模块和内容交付；扩展内容的页面行为、状态机、事件处理和更新策略由扩展自己决定。
Pages 会提供受控接口，让 Define 内容把页面或 Widget 加入 `Main` 允许的区域、
3×3 grid、`more` 或公开 overlay layer。

当前 Define 仍是初始化期协议：每个 `scope_id` 只接受第一个 payload，绑定在 mount
前按注册顺序应用；不存在运行时 unbind、scope 关闭、树回滚或通用 root rebuild。
后续配置/API 热更新是数据和事件更新，不是第二条扩展内容入口，也不重新加载扩展
Lua 源码。改变这些语义必须先更新本目录的设计和测试。

### 播放器应用层

播放器应用层计划采用 `Root → Pages → Main / 3x3 grid / more` 的组合。Main 负责
标题栏、时间线、底部和两侧按钮等固定区域；扩展通过 Define 暴露的 Pages 接口
提供内容。Pages 的组合布局与 host-level 多层 `osd_overlay` 分开；overlay 使用
`overlay.z` 控制视觉层级，不改变 Widget reconciliation、bind priority 或 Define
scope 优先级。详细规划见 [PLAYER.md](PLAYER.md)。

## 当前验证基线

2026-10-12 的完整基线为 **1036 Lua checks**、EmmyLua **No issues found**、
真实 mpv.net 测试 **8 passed**。命令和测试职责以 [TESTING.md](TESTING.md) 为准。

## 变更决策规则

修改公共契约时，先在负责方向的文档中明确所有权和不变量，再改实现和回归测试。
仅影响内部实现的改动应保持最小范围，不把历史设计中的未实现方案写成当前 API。
新的大模块必须同时拥有模块 README、加载/聚合测试和相应方向文档中的入口。
