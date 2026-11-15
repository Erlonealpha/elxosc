# 架构与模块边界

本文说明各层负责什么、允许依赖什么，以及三棵运行时树、应用组合层和 host overlay
如何连接。更高层不能绕过契约
直接操作低层实现；需要新能力时应在拥有该语义的层增加接口。

## 当前组织

player/Define 内容已迁出 lib；通用 WidgetsApp 与 host App 不默认加载或订阅 player。
路径和资源边界见 [DESIGN.md](DESIGN.md#目录与模块入口)，实际检查见
[TESTING.md](TESTING.md)。widgets 已扁平并与 Material 分层；来源级 export、完整静态
catalog 与生产 namespace 已统一。扩展类型提示见 [meta](../../meta/README.md)，专项验收暂缓。

## 分区

| 分区 | 所有权 | 主要入口 |
| --- | --- | --- |
| `lib/src/foundation/` | 无宿主值类型和数学 | `geometry`, `color`, `anchor`, `transform`, `pointer_event`, `key_event` |
| `lib/src/painting/` | 绘制契约和值对象 | `Canvas`, `Paint`, `Path`, `TextPaint` |
| `lib/src/text/` | 文本意图和布局结果 | `TextStyle`, `Paragraph`, `TextLayout` |
| `lib/src/layout/` | 约束代数 | `Constraints` |
| `lib/src/render/` | 持久化渲染树 | `RenderObject`, `PipelineOwner`/`RenderOwner` 及 RenderBox |
| `lib/src/animation/` | 值插值和控制器 | `Curve`, `Tween`, `AnimationController` |
| `lib/src/scheduler/` | 帧阶段和时钟契约 | `FrameClock`, `Scheduler`, `Ticker` |
| `lib/src/widgets/` | 声明式 UI、生命周期和无设计默认的基础组件 | `Widget`, `Element`, `State`, `WidgetsBinding`, `Provider` |
| `lib/src/material/` | Theme 和有样式控件 | `Theme`, `ButtonBase`, `Slider`, `LinearProgressIndicator` |
| `lib/src/backends/` | 契约的具体输出 | `AssCanvas`, `AssTextLayout`, `RecordCanvas` |
| `define/` | 初始化协议、DSL 和 Slot | `DefineSession`, `ModuleRegistry`, `CompositionAssembler` |
| `player/` | 媒体状态、动作、默认 shell、Timeline、AutoHide | `PlayerStore`, `PlayerApp`, `DefaultApp`, `Main` |
| `host/` | mpv 接线 | `App`, `MpFrameClock`, `MpInput`, `MpDefine` |

## 依赖规则

```text
foundation → painting/text → layout → render → widget → host → main.lua
                         scheduler ────────────────┘
backends → painting/text contracts
define → framework widget primitives
player → framework + define Slot for initialization composition
host → framework + explicit player/Define adapters
```

`render` 不认识 Widget，`widget` 不认识 mpv，`backends` 不读取 mpv 状态。宿主只
通过 `Canvas`、`TextLayout`、`FrameClock` 和输入值对象进入核心。所有模块使用裸
模块名并避免 require cycle；聚合入口必须返回直接模块导出的同一对象。

框架源码统一位于 `lib/src/`。`lib/foundation.lua`、`lib/render.lua` 等每层入口
收集来源中的成员，不把子模块表挂到整合表；这项职责独立于扩展系统。`lib/material.lua`
收集框架控件和值类型；host/builtins.lua 手动选择默认 Define surface。

例如 `require('render').RenderStack` 与 `require('src.render.stack').RenderStack`
保持身份；`render.stack` 本身通过独立 require/import_as 入口获取，整合表没有 stack 字段。
Anchor、Curves 等来源定义的具名值表保持原对象。点分包名表达注册名称，不表示整合表
中的嵌套模块；show/hide 仍只组织来源成员，不影响独立子包可导入性。

`elxlib_load.lua` 与离线入口共享 `lib/module_loader.lua`：`require 'foundation'`
加载公开 collector，`require 'src.foundation.geometry'` 加载源码。
`require 'src/foundation/geometry.lua'` 和显式 `src/widgets/init.lua` 也支持，并映射到
同一 canonical 模块，避免 class 和 Binding singleton 重复。项目代码优先使用点路径。
所有生产模块表使用 `elxosc.mod.<canonical require>`，例如
`elxosc.mod.src.foundation.geometry` 和 collector `elxosc.mod.foundation`；
实例/Options/alias 使用对应 owning namespace，FPK-4 已同步全部引用。
文件使用 `@namespace elxosc` 限定声明、`@using elxosc` 与必要 owner using 简写引用，
类型身份保持上述完整名称；运行时名称和 class name 字符串不受影响。
`init.lua` 单向转出 collector，不重复类型或 classes；类型名前缀不进入运行时路径。

`define/` 是原 extension 的 sandbox、Define、ModuleRegistry、DSL 和 Slot 所有者。
`lib/package_catalog.lua`、`player/package_catalog.lua` 和 `define/package_catalog.lua`
分别枚举所属全部 runtime source、collector 和工具，使用 framework export 输出
`{ name, exports }`。清单是显式声明，不扫描文件，也不依赖偶然 require 顺序。
`host.package_catalog.collect()` 合并三个清单，host 加入 facade 和 `loader?`，
host 增加 runtime facade 后统一注册。`import('render.stack')`、
`import_as('material.slider')` 解析明确登记的多级包，不遍历任意对象字段。
受保护父包同时保护未登记的子名称；新增包不扩大 host 默认 builtins。

## 框架与应用的所有权

下列分区、入口和导出合同已实施。

| 目标分区 | 所有权和入口 |
| --- | --- |
| `lib/src/widgets/`、`lib/widgets.lua` | 扁平的 Widget/Element/State/Binding、基础布局/文字/输入/Provider/Overlay/导航；Widget 基类 source 名为 `src.widgets.framework` |
| `lib/src/material/`、`lib/material.lua` | 现有设计 Theme、按钮 family、有样式 Slider/LinearProgressIndicator；重导出基础 widgets |
| `player/` | 播放器 state/actions、DefaultApp/Main、Timeline、AutoHide、主题和布局；公共根 `player/init.lua` |
| `define/` | 原 extension 的协议、sandbox/registry、bind/DSL/Slot/SlotBuilder；公共根 `define/init.lua` |
| `host/` | 通用 mpv App、player/Define adapters、默认包/builtins 和 scoped facade 接线 |
| `meta/` | 扩展开发统一类型提示入口和包类型声明管理；不属于 runtime catalog |

`lib/` source/collector 不加载 player、define 或 mp；基础 widgets 不反向加载 Material。
player/Define 的领域与协议代码仍不加载 mp。player 的初始化 composition 可以依赖 Define
的 Slot 协议，具体播放器 Slot ID/规则由 player 拥有。clock/property/message/presenter
继续由 host 适配。基础值、render、animation/scheduler/backends 的现有分区保持。

实际 class/function source 与层 collector 分开；每个 `lib/*.lua` 无条件收集所属导出。
`src.<layer>.init` 是明确的单向 collector alias，collector 不加载该 alias；现有 animation
init 的重复清单合并到 animation collector。source/collector/alias 共享同一 class 和表
身份。原 `src.widget.*`、`widget.*`、`extension.*`、`main_layout` 迁移后删除；现有
WidgetBinding/RenderOwner 的 class identity alias 保留，不与旧 module path 混为一项删除。

目标 canonical require 为 `src.widgets.*`、`src.material.*`、`player.src.*`、`define.src.*`；
不为 player/define 增加另一个裸 `src` 搜索根。包名为 widgets/material/player/define 及
精确子包。模块表类型统一 `elxosc.mod.<canonical require>`，例如
`elxosc.mod.src.widgets.framework`；生产实例/Options/alias 使用 elxosc namespace，
Material/player/Define/host 类型放在相应子 namespace。运行时路径不添加 elxosc 前缀。

框架整体向扩展开放，catalog 覆盖全部 framework runtime source、导出包和整合包。
show/hide 是来源组合手段：先筛选各自来源再合并，不缩减框架注册范围。静态 descriptor
为 `{ name, exports }`，普通 require 返回 exports；Define 接线才加入 `loader?`。

export 声明浅复制 source 自身字段，支持 string/有限 integer key，保留 false/数组原 key。
show/hide 只对当前来源执行一次；不存在或重复筛选 key 报错。同键同对象/标量可去重，
不同值冲突报错；需要别名时显式构造来源表，整包替换显式声明。get 首次发布目标，
collect 验证全部待发布包后按首次声明顺序发布；失败不发布半成品。重复读取共享 exports
身份，已发布包不可追加或重新筛选。source/metatable 不修改，pairs 次序不保证，包枚举
次序稳定。export 不管理 scope、事务或运行时树。

FPK-3 的 `require('export')` 提供默认声明上下文；`export.new()` 返回独立上下文，
供每个 collector 和扩展显式使用。上下文的 export/get/collect 是点调用函数；每条
export 返回一次性 show/hide handle，声明其他包不使 handle 失效，替换自身来源后旧
handle 报 RuntimeError。成功发布后释放来源快照，保留普通 exports；collect 每次返回
新 descriptor 容器。render 的同名 normalize helpers 通过显式来源表重命名；Material
只选 Slider/LinearProgressIndicator，完整 helpers 仍可从独立子包导入。
animation init 已改成单向 collector alias。Define collector 输出 sandbox 自身成员
load_chunk/new_env，不再附加 sandbox 子模块；player.PlayerIcons 保留原具名 API。

PaintingBinding/SchedulerBinding/RendererBinding 当前在函数内引用具体 WidgetsBinding，
这是既有 role 接线；迁移只更新其路径/type，不同时重构 Binding topology。
阶段 0 固定上述合同与完整映射，随后按所有权分离、Widgets/Material、导出、类型顺序实施；
布局、dirty、Binding singleton、Define 初始化协议和资源清理行为保持。

## 迁移入口对照

旧框架中的播放器和 Define 内容按所有权迁出；以下旧路径已删除，没有运行时 fallback。
公开 collector 和精确子包分别加载，不通过整合表中的嵌套字段访问子模块。

| 原 require / 包名 | 当前 require | Define import_as |
| --- | --- | --- |
| `widget`、`widget.widgets` 及其 `basic`/`layout` 整合 | `widgets`；有样式控件用 `material` | `widgets` / `material` |
| `src.widget.widget`、`widget.widget` | `src.widgets.framework` | `widgets.framework` |
| `src.widget.widgets.text` | `src.widgets.text` | `widgets.text` |
| `src.widget.widgets.slider`、`src.widget.widgets.button` | `src.material.slider`、`src.material.button` | `material.slider`、`material.button` |
| `src.widget.ambient` 的 Display/默认文字 | `src.widgets.ambient` | `widgets.ambient` |
| `src.widget.ambient` 的 Theme | `src.material.theme` | `material.theme` |
| `src.widget.player_context`、`player_context` | `player.src.context` | `player.context` |
| `src.widget.actions` | `player.src.actions` | `player.actions` |
| `src.widget.player.timeline`、`src.render.timeline` | `player.src.timeline`、`player.src.render.timeline` | `player.timeline`、`player.render.timeline` |
| `src.widget.visibility` 的 AutoHide | `player.src.auto_hide` | `player.auto_hide` |
| `src.widget.player.theme` | `player.src.theme` | `player.theme` |
| `extension.define`、`extension.modules`、`extension.sandbox` | `define.src.session`、`define.src.modules`、`define.src.sandbox` | `define.session`、`define.modules`、`define.sandbox` |
| `src.widget.dsl`、`src.widget.bind`、`src.widget.slot` | `define.src.dsl`、`define.src.bind`、`define.src.slot` | `define.dsl`、`define.bind`、`define.slot` |
| `src.widget.builder` 的 ContextBuilder | `src.widgets.builder` | `widgets.builder` |
| `src.widget.builder` 的 SlotBuilder/call_slot | `define.src.builder` | `define.builder` |
| `main_layout` | `player.src.composition` | `player.composition` |

Opacity/Offstage/Visibility 留在 `src.widgets.visibility`。当前 canonical source 的
slash/`.lua`/`init` 拼写仍是受支持的同对象 alias；WidgetBinding/WidgetsBinding、
PipelineOwner/RenderOwner 和 Main/PlayerMain 也保留 class identity alias。
它们与已移除的旧目录入口不同。

模块表类型现为 `elxosc.mod.<canonical require>`；例如 Slider 源模块为
`elxosc.mod.src.material.slider`，实例/Options 为 `elxosc.material.Slider` / `SliderOptions`。
类型中的 owner 与运行时 require/import 包名分别表达。

## 扩展类型提示

生产模块表为 elxosc.mod.<canonical require>，框架实例/Options/alias 为 elxosc.*；
Material/player/Define/host 分别使用 owning namespace。runtime require/类名字字符串
保持原值，std.class.new 的类型模板通过 `@namespace`/`@using` 解析声明。PipelineOwner 的
类型别名由 render owning source 声明，init 仅返回 collector，不重复声明模块类型。

meta/elxosc.lua 不在 runtime catalog 中；扩展编辑器一次加载 owning sources、elxlib
与该 meta 文件。tools/generate_meta.py 从三个显式 catalog 校验 source module types，
生成全部 143 包名 literal import_as 重载，require 复用同一 callable；默认类工厂仅
new_widget/new_state。协议和类工厂声明收集为 elxosc.meta.Builtins 局部表类型，
不定义编辑器全局、不覆盖标准 Lua require/print。
mp/player 的 runtime additions 使用 host.MpPackage/PlayerPackage；筛选后的 collector
仅提示实际成员。new_widget/new_state 复用 owning factory 的名称模板/父类约束。

扩展 JSON 以 {name,type} 声明包类型，支持 named type/array 交集，按输入顺序组合。
相同 name/type 去重，不同类型同名失败且保留原输出；与内建包冲突同样失败。该登记
只生成提示，实际包仍经 Define mod transaction 发布。动态包名返回普通 table 提示；
missing type 在实际消费时报诊断。import 不返回包；Define require 是 import_as 的同函数
别名，返回 scope 包且不注入环境。编辑器不追踪任意环境字段注入；组件/值类型通过
局部包取得。只加载一份完整生成文件，避免重复类型声明。
配置和局部 builtins 表示例见 [meta/README.md](../../meta/README.md)。

## Flutter runtime 对齐

运行时采用 Flutter-style concrete Binding singleton 加 owner scope 拓扑：

```text
Lua runtime / host isolate
└── WidgetsBinding composition（一个 concrete instance）
    ├── SchedulerBinding role
    ├── RendererBinding role
    ├── PaintingBinding role
    └── attached owner scopes
        ├── BuildOwner → BuildScope → Element tree
        │              └── PipelineOwner → RenderObject tree → Canvas
        └── BuildOwner → BuildScope → Element tree
                       └── PipelineOwner → RenderObject tree → Canvas
```

`BuildOwner` 管 dirty Element、BuildScope、inactive/finalize 和 GlobalKey registry；
`PipelineOwner` 是现有 `RenderOwner` 的规范名称，迁移期两个入口返回同一 class object；
`PaintingContext` 是 RenderObject 到 Canvas 的最小绘制上下文，不是 Layer tree。Binding
composition 只初始化一次；多树通过 `WidgetsBinding:attach()` 复制 BuildOwner、
PipelineOwner 和 root Element，不复制第二套 Binding。

F runtime 的生产边界仍是单 logical root、单 `AssCanvas`、单 `AssPresenter` 和单
`osd-overlay`。Layer/compositing、Semantics、multi-view 和 GlobalKey 跨父节点 reparent
不因名称对齐而进入当前 API。

初始化组合位于 WidgetTree 之前：Define payload → Contribution snapshot →
`CompositionAssembler` → fresh Widget description → `WidgetsBinding:attach()`。
`DefaultApp` 是播放器应用层的 Widget 组合契约，不是第四棵底层运行时树。它把稳定的
Main、Extension 和 WindowLayer 作为同一个 `Theatre` 的逻辑 entries 组装；最终仍由
Widget/Element/RenderObject 三棵树完成挂载和绘制。Define/Slot 是初始化期扩展内容进入
应用的唯一入口，配置/API 热更新只是数据或事件输入，不是新的内容注入通道。

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

### Application composition

应用组合位于 host service 和 Widget tree 之间：

```text
WidgetsApp
└── DefaultApp
    └── Theatre
        ├── ExtensionEntry
        ├── MainEntry → AutoHide → Main
        └── WindowLayer
```

Main 的标题栏、时间线、底部信息和受控 host actions 由播放器拥有；扩展通过初始化
Define/Slot 提供内容。Main 隐藏只改变自己的 AutoHide/Offstage entry，不卸载 Extension
State。`Theatre`/`OverlayEntry` 负责同一逻辑 root 内的 entry 生命周期和 eligibility plan，
不创建第二个 owner、presenter 或 surface。旧九宫格和 `more` 不属于当前生产入口。

### Host owner and overlay layers

当前 `host.mpv_app.App` 是单一 host owner，负责 clock、scheduler、display observers、
input、AssCanvas、AssPresenter 和 shutdown。`MpInput` 通过最小的 RenderOwner/viewport/
callback 接口接入；它不持有整个 App。`MpFrameClock` 和 `AssPresenter` 位于 host primitive
模块，但不创建第二个 runtime owner。

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

PlayerStore 位于 player 应用层且不依赖 mpv：宿主只负责将 property/API 数据
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
- DefaultApp 只负责应用组合和扩展边界；Theatre/OverlayEntry 只负责同一逻辑 root 的
  entry 生命周期与 paint/input eligibility，不能把 entry 状态混成 Define priority 系统。
