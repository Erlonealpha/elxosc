# elxosc 当前设计

本文是 elxosc 的当前设计主文档和决策索引。它描述已经实现的架构、不可破坏的
契约以及下一步方向；代码和测试是最终事实来源，旧设计记录只用于追溯历史。

## FPK-1 实施状态（2026-11-14）

### FPK-2 组织完成（2026-11-15）

公共 widgets collector 和 src.widgets.* 已扁平化；Widget 基类位于 framework.lua，
Element/State/Binding 等保持独立功能文件。src.material.* 拥有 Theme、按钮系列、
Slider/LinearProgressIndicator 和图标字体集合入口；material 重导出全部基础 widgets
成员，整合表不附加子模块。旧 widget/widget.widgets/basic/layout 入口已删除。
通用 Display/DefaultTextStyle、Tooltip/Icon/HoverText/导航仍归 widgets；HoverText
通过 RenderText setter 更新颜色/glow，不依赖 ButtonBase。数值 render 接收明确视觉
config，Material 保留原 palette/尺寸，Player RenderTimeline 明确提供其自绘初始字段。
字体资源在 lib/fonts/material_symbols.lua，Material 与基础 Icon 共享具名资源；
Icon 保留 bundled 默认，自定义字体不携带 Material variation intent。
完整 Lua 3144、严格 EmmyLua、7 项定向 Python 检查通过，范围见 TESTING。
本切片未实现 FPK-3 export 或 FPK-4 全量 namespace/meta；人工外观确认仍待用户审阅。

框架与 player/Define 的边界已迁移。`lib/` source/collector 不加载 player/define/mp；
`WidgetsApp` 仅提供 display/default_text_style/child/key。`player.src.ambients.PlayerApp`
明确组装 Theme/PlayerTheme/HostActionsScope 和 WidgetsApp；`host.mpv_player_app.PlayerHostApp`
接媒体 observer、PlayerScope、默认动作和 activity，并向通用 App 传入唯一 context disposer。
App 正常/异常 teardown 及部分初始化失败清理自身资源；main 仍拥有 Define 窗口 timer。

player 根收集公开组件和迁出的状态/actions/AutoHide；Main/PlayerMain 同一类。
Define 的 DSL/bind/Slot/SlotBuilder 已迁出，ContextBuilder/通用校验留框架。
Tooltip 通过通用 hover_enabled(context)/refresh_hover_visibility 边界接受上层策略；
PlayerTooltip 判断所有 AutoHide 祖先，fade-start 清理与淡出期间预览抑制保持。
host/package_catalog.lua 收集包，host/builtins.lua 手选原 115 字段；material 只含框架。
旧 extension、lib/player、widget/player 和 main_layout 入口已删除；调用者使用 player.src.*、
define.src.*。迁出模块表与类型已同步 owning namespace，不改变运行时类名和对象身份。

FPK-2 已完成；FPK-3 的 export 组合/完整 catalog 与 FPK-4 的全量 namespace/meta
仍待实施。下列目标章节中这些后续项目不能视为现有 API。
验证与实际范围见 [TESTING.md](TESTING.md)。

用户随后明确整合模块不直接导出子模块。lib collectors 已统一为来源成员导出，
独立 source/子包继续 require/import_as；具名值表保留 identity。完整 Lua 2993、
严格 EmmyLua 通过；定向验证与阶段 1 原记录分别见 TESTING。

## 阅读路径

按变更范围继续阅读对应方向文档：

| 文档 | 负责的问题 |
| --- | --- |
| [ARCHITECTURE.md](ARCHITECTURE.md) | 分层、依赖、三棵树和模块边界 |
| [RENDERING.md](RENDERING.md) | 约束布局、绘制、文本、ASS、变换和动画 |
| [INPUT.md](INPUT.md) | `set_mouse_area`、输入 section、默认行为和事件重构 |
| [WIDGETS.md](WIDGETS.md) | Widget/Element/State、控件和绑定 |
| [HOST.md](HOST.md) | mpv 帧循环、输入、Define 传输和宿主边界 |
| [PLAYER.md](PLAYER.md) | WidgetsApp/DefaultApp/Main、扩展边界、配置热更新和 OverlayEntry |
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
define provides sandbox/Define services and is consumed by host/entry assembly
```

框架核心按 `lib/src/foundation/`、`lib/src/painting/`、`lib/src/text/`、`lib/src/layout/`、`lib/src/render/`、
`lib/src/animation/`、`lib/src/scheduler/`、`lib/src/widgets/`、`lib/src/material/`、`lib/src/backends/` 分区；
应用层 `define/` 与 `player/` 使用框架，`host/`、
`main.lua` 和 `elxlib_load.lua` 是唯一的 mpv 边界。聚合模块必须转出独立模块的
同一个类对象，不能重新定义兼容副本。
`lib/*.lua` 为每个框架层统一收集导出，不依赖扩展系统；`lib/material.lua` 提供框架
构造 surface，host/builtins.lua 手动收集默认 Define 环境。原 extension 更名 define，
原框架内的播放器内容迁入 player。加载路径和多级 import 见
[ARCHITECTURE.md](ARCHITECTURE.md) 与 [HOST.md](HOST.md)。

2026-11-14 的阶段 0 固定完整迁移映射和导出合同，FPK-1 已完成框架与应用边界；
widgets/Material 已完成，export/meta 按后续阶段实施，见各方向文档的目标章节。

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
FPK-1 迁出的模块表类型使用 `elxosc.mod.<canonical require>`，实例类型为 elxosc.player/define；
未迁框架仍使用现有类型，FPK-4 统一。类型前缀不属于运行时路径。
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
只在初始化期把扩展 Widget 放入允许的内容位置。N2 `Overlay`/`Theatre` 只管理同一
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
reconciliation、bind priority 或 Define scope 优先级。详细规划见 [PLAYER.md](PLAYER.md)。

## 当前验证基线

2026-11-15 FPK-2 后完整 **3144 Lua checks**、严格 EmmyLua **No issues found**、
定向 Python **7 passed**，无 skip。基础 widgets 的独立加载、Material 默认视觉、
HoverText persistent paint/input、显式 render config 和相关 host 接线通过。
人工外观/手感仍待用户审阅；当前及历史命令与范围见 [TESTING.md](TESTING.md)。

2026-11-14 FPK-1 后完整 **2976 Lua checks**、EmmyLua（warnings-as-errors）
**No issues found**；定向 Python 曾 **9 passed**，最终复验 **8 passed, 1 Demo 点击失败**，
用户要求忽略错误并保留记录。框架隔离/其他 host 检查通过，无 skip。
框架独立 mount/paint/input、应用模块身份、115 builtins、Define transaction、PlayerScope
和 App 正常/异常清理通过；命令和范围见 [TESTING.md](TESTING.md)。

2026-11-10 框架库目录迁移与多级模块后 **2820 Lua checks**、EmmyLua
**No issues found**、完整 Python **47 passed**，无 skip。`lib/src/` 提供实现，
`lib/*.lua` 统一收集导出，`material` 接替 builtins；`extension/` 负责 Define，
支持明确登记的多级 import。验证详情见 [TESTING.md](TESTING.md)。

2026-11-10 标准控件拆分和扩展包标准化后完整 **2540 Lua checks**、EmmyLua
**No issues found**、完整 Python **47 passed**，无 skip。模块返回表使用 `elxosc.*`
类型，标准包统一收集、由 host 注册，builtins 显式选择；`import_as` 返回局部包。
检查范围和宿主间歇点击失败记录见 [TESTING.md](TESTING.md)。

2026-11-08 测试类迁移后完整 **2330 Lua checks**，项目入口与独立
`mpv-luatest` CLI 均通过，EmmyLua **No issues found**。离线测试运行器、断言和
mp 桩改为根目录 `mpv-luatest/` Git submodule 开发依赖；项目路径、elxlib 加载与
桩配置仍由 `test/` 管理。独立仓库不含 elxosc 适配文件，生产运行时不加载它。
完整 Python **46 passed**，无 skip；依赖安装、版本更新和验证详情见
[TESTING.md](TESTING.md)。

2026-11-06 通用 ASS 测量与 benchmark 完成后为 **2318 Lua checks**、EmmyLua
**No issues found**、real-host **15 passed**、runner **14 passed**、测量 CLI **11 passed**、
benchmark CLI **3 passed**。AssMeasure 固定初始化分辨率、复用隐藏 overlay/native command、
返回原生 bounds；诊断报告单独适配。benchmark 覆盖四类框架场景、paint-only动画/
Record重放和旧/持久update/native三种测量对照，同环境报告与限制见
[TESTING.md](TESTING.md)。它不改变生产帧循环或 TextLayout，不提供新的渲染缓存API。

历史基线：

2026-11-06 离线 ASS 测量工具完成后为 **2290 Lua checks**、EmmyLua **No issues found**、
real-host **14 passed**、runner **14 passed**、测量 CLI **11 passed**；
新增显式调用的 `host.ass_measure.AssMeasure` 与 JSON/Markdown CLI，六类 framework 样例
各五次宿主测量稳定。它不进入播放器帧循环，不将宿主 bounds 写回框架布局。输入、错误/
清理边界和测量限制见 [HOST.md](HOST.md) 与 [TESTING.md](TESTING.md)。

2026-11-05 默认播放器收口后为 **2241 Lua checks**、runner CLI **14 passed**；
`emmylua_check .` **No issues found**；默认启用 Demo 的生产入口 real-host **12 passed**。
AutoHide 开始隐藏时清理 thumbfast，预览使用共享像素坐标的白色边框和黑色外描边。
用户整体外观审阅认可支持当前默认播放器范围收口；完整 ModernX 兼容和 240 Hz 性能
仍为后续方向。应用边界见 [PLAYER.md](PLAYER.md)，实际验证和性能限制见
[TESTING.md](TESTING.md)。

2026-10-28 P2 ModernX 默认播放器后为 **1753 Lua checks**（ModernX **31**，Builder **26**，
runtime **252**）、CLI **14 passed**；
生产静态检查排除本地 ignored tmp 草稿后 **No issues found**，启用入口的隔离副本
real-host **10 passed**。工作区入口被用户关闭时为 **8 passed, 2 failed**；默认静态扫描
本地重复类型草稿会产生 warning。详情和实际命令见 [TESTING.md](TESTING.md)。

2026-10-26 的历史 P0/R1/R2 + N1/N2 + R3/R4 + N3 Demo + N4/N5 工作区为 **1491 Lua checks**、EmmyLua
**No issues found**、real-host **10 passed**。R3 已将
默认入口收敛为唯一 `app.extension` 内容边界；R4 已将 mpv clock/presenter primitive
从 `App` 实现中拆出，并让 `MpInput` 使用最小 owner/callback 接口；N3 已将 Page/Route
和 Popup/ESC 接入同一 Theatre；Demo 展示页面/弹窗、返回结果及首页 State 保留；N4/N5
已接入单 Canvas cache 和 RegionSnapshot/section cache。命令和测试职责以
[TESTING.md](TESTING.md) 为准。

6.3 的核心链路和语义修复已实现：Provider 使用 exact lookup，提供非监听 read API，
State 支持 `did_change_dependencies`，并对 init/dispose 的 listening lookup 做边界
诊断。N1/N2 的 DefaultApp、ambient、AutoHide、OverlayEntry lifecycle 实现继续遵守
这些 Provider 和生命周期契约；N3 已提供同一 Theatre 内的 Navigator/Route/Popup/ESC
最小切片，完整 focus/restoration 和 host-level 多 overlay 仍延期。

## 变更决策规则

修改公共契约时，先在负责方向的文档中明确所有权和不变量，再改实现和回归测试。
仅影响内部实现的改动应保持最小范围，不把历史设计中的未实现方案写成当前 API。
新的大模块必须同时拥有模块 README、加载/聚合测试和相应方向文档中的入口。
