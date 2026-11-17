# elxosc 当前设计

本文是 elxosc 的当前设计主文档和决策索引。它描述已经实现的架构、不可破坏的
契约以及下一步方向；代码和测试是最终事实来源，旧设计记录只用于追溯历史。

## 目录与模块入口

可复用框架统一位于 `lib/src/`，各 `lib/*.lua` collector 收集所属成员。基础 widgets
在 `src.widgets.*` 扁平组织，Theme、按钮和有样式数值控件归 `src.material.*`。
Material 重导出基础 widgets；整合表不附加子模块，direct/collector 保持对象身份。

播放器状态、动作、Timeline、AutoHide、主题与默认组合归 `player/`；sandbox、模块
注册、Define session、DSL、bind 和 Slot 归 `define/`。`lib/` 不加载 player/Define/mp，
基础 widgets 不反向加载 Material。mpv clock/input/property/message/presenter 和应用
适配归 `host/`；`main.lua` 负责入口组合与 Define 窗口 timer。

`lib/export.lua` 提供独立静态声明上下文、来源级 show/hide、get/collect。各 owner
catalog 显式枚举全部 runtime source、collector、工具和字体资源，host 合并注册并加入
scoped mp/player facade；默认 builtins 包含 new_widget/new_state 与选定 Lua 工具。框架整体向扩展开放，
show/hide 只组织来源成员。多级 import 精确解析登记包，不遍历整合表字段。

当前 canonical require 为 `src.widgets.*`、`src.material.*`、`player.src.*` 和
`define.src.*`。旧 widget/extension/player_context/main_layout 入口已删除；当前 source
的 slash/`.lua`/`init` 拼写与公开 class identity alias 保留。详细映射见
[迁移入口对照](ARCHITECTURE.md#迁移入口对照)。

所有生产 module/instance/Options/alias 已统一 `elxosc` namespace。声明使用
`@namespace elxosc`，引用通过 `@using elxosc` 和 owning namespace 简写；模块表为
`elxosc.mod.<canonical require>`，运行时包名和 class name 字符串保持短名。
[meta](../../meta/README.md) 将协议函数与类工厂提示收集为 `elxosc.meta.Builtins` 表类型，
汇集登记包的 import_as/require 提示、scoped facade 和扩展自有包类型组合说明，
不声明编辑器全局变量，也不进入 runtime catalog。

默认 builtins 提供两个类工厂和 host 选定的 Lua 工具；组件和值类型通过显式包导入获得。
Define 的 `require` 现为 `import_as` 的同函数别名：返回包且不注入环境；`import` 保持
成员注入。meta 将这些作用域名称描述为局部表类型，不覆盖编辑器的 Lua 全局。

选定 Lua 工具包括 math/table；rawlen/utf8 仅在运行时
提供时存在。库表按现有注入规则共享，scope 名称赋值仍局部。外部 elxlib std 由
host/mpv_define 注册为独立包，不在框架 catalog 或 builtins 中；require/import_as
返回顶层浅副本，class/function 保持 identity；组件不默认注入。

## 阅读路径

按变更范围继续阅读对应方向文档：

| 文档 | 负责的问题 |
| --- | --- |
| [ARCHITECTURE.md](ARCHITECTURE.md) | 分层、依赖、三棵树和模块边界 |
| [RENDERING.md](RENDERING.md) | 约束布局、绘制、文本、ASS、变换和动画 |
| [INPUT.md](INPUT.md) | 输入区域、section、默认行为、事件和 capture |
| [WIDGETS.md](WIDGETS.md) | Widget/Element/State、控件和绑定 |
| [HOST.md](HOST.md) | mpv 帧循环、输入、Define 传输和宿主边界 |
| [PLAYER.md](PLAYER.md) | WidgetsApp/DefaultApp/Main、扩展边界、配置热更新和 OverlayEntry |
| [TESTING.md](TESTING.md) | 测试分层、命令、fixture 和回归要求 |
| [ROADMAP.md](ROADMAP.md) | 能力缺口、依赖和后续方向 |

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
define provides sandbox/Define services and is consumed by host/entry assembly
```

框架核心按 `lib/src/foundation/`、`lib/src/painting/`、`lib/src/text/`、`lib/src/layout/`、`lib/src/render/`、
`lib/src/animation/`、`lib/src/scheduler/`、`lib/src/widgets/`、`lib/src/material/`、`lib/src/backends/` 分区；
应用层 `define/` 与 `player/` 使用框架，`host/`、
`main.lua` 和 `elxlib_load.lua` 是唯一的 mpv 边界。聚合模块必须转出独立模块的
同一个类对象，不能重新定义兼容副本。
`lib/*.lua` 为每个框架层统一收集导出，不依赖扩展系统；`lib/material.lua` 提供框架
构造 surface，host/builtins.lua 手动收集默认 Define 环境。加载路径和多级 import 见
[ARCHITECTURE.md](ARCHITECTURE.md) 与 [HOST.md](HOST.md)。

资源所有权与构造边界见对应方向文档。

## 三棵运行时树

1. **Widget tree**：不可变配置和声明式子树，由 `State` rebuild 产生新描述。
2. **Element tree**：保存生命周期、Widget 复用、Inherited 依赖和 State。
3. **RenderObject tree**：保存尺寸、父子位置、绘制状态、命中测试和 dirty 标记，
   在 Widget 更新时尽量复用。

一个 concrete `WidgetsBinding` composition 把三棵树的 frame lifecycle 连接起来；每个
attached `WidgetTree` 复制自己的 `BuildOwner` 和 `PipelineOwner`/`RenderOwner`。布局和
绘制不会修改 Widget；结构性变化只能通过 rebuild，运行时属性变化则由 RenderObject
setter 选择 `paint` 或 `layout + paint` 失效类型。

## 不可破坏的契约

### 模块边界

除 `host/`、`main.lua`、`elxlib_load.lua` 外不得加载 `mp`。模块使用裸 require
名称，例如 `require 'src.render.text'`，不得引入 `elxosc.` 前缀或循环依赖。
所有生产模块表类型使用 `elxosc.mod.<canonical require>`，实例/Options/alias 归
`elxosc` 及其 owning namespace；类型前缀不属于运行时路径。
扩展包描述、统一收集、host builtins 选择和 `import_as` 合同见 [HOST.md](HOST.md)。

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

### Define、应用组合和更新边界

Define 是用户扩展内容进入播放器的唯一入口。它负责 transport、sandbox、scope、
模块和内容交付；扩展内容的页面行为、状态机、事件处理和更新策略由扩展自己决定。
当前应用组合使用 `DefaultApp` 的 Main、Extension 和 WindowLayer 边界；Define/Slot
只在初始化期把扩展 Widget 放入允许的内容位置。`Overlay`/`Theatre` 只管理同一
logical root 内的 Entry lifecycle，不是第二条 Define 内容入口。

当前 Define 仍是初始化期协议：每个 `scope_id` 只接受第一个成功 payload。payload
在 transaction 中执行，成功后才提交 Contribution 和 module publish；失败 payload
整体拒绝且不消耗 scope。seal 后由一个 `CompositionAssembler` 按 `SlotSpec` 生成
fresh Widget description，`WidgetsBinding` 只负责 mount/update/dispose，不重复 apply。
不存在运行时 unbind、已挂载树回滚或通用 root rebuild。
后续配置/API 热更新是数据和事件更新，不是第二条扩展内容入口，也不重新加载扩展
Lua 源码。改变这些语义必须先更新本目录的设计和测试。

### 播放器应用层

播放器应用层当前采用 `WidgetsApp → DefaultApp → Theatre → Extension / Main / WindowLayer`
的组合。Main 负责标题栏、时间线、底部信息和受控 host actions；扩展通过初始化
Define/Slot 提供内容。Theatre 的 entry paint/input eligibility 与 host-level 多层
`osd_overlay` 分开；`overlay.z` 仍只属于未来 presentation 层，不改变 Widget
reconciliation、bind priority 或 Define scope 优先级。详细契约见 [PLAYER.md](PLAYER.md)。

## 验证职责

公共行为、非法边界、生命周期、dirty 分类和模块 identity 由自动回归覆盖；真实宿主
检查负责输入接线、ASS 消费和资源清理，人工审阅负责视觉和交互手感。测试策略见
[TESTING.md](TESTING.md)，运行方式见 [test/README.md](../../test/README.md)。
设计正文不维护逐轮结果或测试计数，实际执行记录由本地规划和交付说明承担。

## 变更决策规则

修改公共契约时，先在负责方向的文档中明确所有权和不变量，再改实现和回归测试。
仅影响内部实现的改动应保持最小范围，不把历史设计中的未实现方案写成当前 API。
新的大模块必须同时拥有模块 README、加载/聚合测试和相应方向文档中的入口。
