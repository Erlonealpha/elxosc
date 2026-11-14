# mpv 宿主与 Define 协议

本文负责 mpv 边界、帧循环、ASS presenter、输入接线以及初始化期 Define。

## FPK-1 实施状态（2026-11-14）

player/Define 内容已迁出 lib；通用 WidgetsApp 与 host App 不默认加载或订阅 player。
新路径和资源边界见 [DESIGN.md](DESIGN.md#fpk-1-实施状态2026-11-14)，实际检查见
[TESTING.md](TESTING.md)。FPK-2 已迁到 widgets/material 包名，FPK-3 已实现 export 与
完整静态 catalog 与 FPK-4 namespace/meta。

## 已确认的接线重组（2026-11-14，FPK-1 已实施，后续分层待实施）

框架/player/Define 的目标所有权见 [架构](ARCHITECTURE.md)。原 extension 已更名 define，
host.mpv_app 保留通用 frame/tree/input/presenter/display lifecycle；播放器默认观察、
Theme/PlayerScope/HostActions 和 activity 路由已归 host.mpv_player_app。
通用 App 不默认订阅媒体属性或识别播放器 State methods。每个 context/adapter/timer
只有一个 disposer owner，正常/异常 shutdown 都清理；Main 的 hover/捕获和 resize 行为保持。

框架 export 产生静态 `{ name, exports }` descriptor，host 注册完整 framework catalog，
再加入 player/Define 包和 scoped mp/player facade。所有框架实际 runtime source/导出/
整合包可导入；show/hide 只整理单条来源，不充当权限或隐藏框架的手段。多级名字精确
登记，不按任意对象字段/文件路径查找。source alias 的 slash/init 解析仍归 module_loader。

默认 builtins 从所属 collector 手动选择，保持迁移前 material 表的 115 个公开字段。
Material 只拥有框架样式控件和基础 widgets 的重导出；player/Slot/DSL 字段由其 owning
包提供。新包不会自动扩张默认 surface，MpDefineOptions.builtins 的替换语义保持。
DefineSession 仍生成和恢复 scope-aware import/import_as/require/mod/bind；print 由 host 提供。
导出 API 的数组原 key/false/同名冲突与发布规则见 ARCHITECTURE，仍保持 class identity。

meta/ 是扩展项目统一加载提示的开发入口，汇集 framework/player/Define 导出类型、
scope builtins/facade、import_as 字面包名重载和类工厂提示；允许追加扩展自己的包类型
声明并检测同名冲突。基础源码类型不反向依赖上层，提示文件不 require、不重复 class。
“跨层安装”指编辑器 workspace library 的加载方式，不建立新的 runtime publication。
import 不返回包、import_as 返回浅包且不注入环境的区别必须在提示中准确表达。
扩展自有类型可以自己的 namespace；meta 不管理 mounted tree、源码热重载或 scope shutdown。

上述接线边界、export 与 meta 已实施。下文描述当前代码。首次 payload/transaction、
protected names、loader scope、fresh description before mount 和资源清理语义不改变。

## 宿主边界

只有 `host/`、`main.lua` 和 `elxlib_load.lua` 可以加载 `mp`。核心通过以下契约
保持可测试和可复用：

- `Canvas`：输出绘制原语；当前由 `AssCanvas` 和 `RecordCanvas` 实现。
- `TextLayout`：提供后端文本测量；当前由 `AssTextLayout` 估算。
- `FrameClock`：请求并触发帧；mpv 实现按显示刷新率限流。
- 输入值对象：宿主把鼠标/按键转换为 `PointerEvent` 和局部坐标。

## App 帧循环

`host.mpv_app.App` 是唯一的 host lifecycle owner。它获取共享的 `WidgetsBinding`
composition，再为自己的 tree 创建独立 PipelineOwner/BuildOwner、Scheduler、AssCanvas
和 AssPresenter；`host.mpv_primitives` 只提供 App 拥有的 mpv-backed `FrameClock` 与
presenter 适配器：

```text
mp property / input / dirty callback
    → schedule_frame (coalesced + refresh-rate limited)
    → transient ticker/controller callbacks
    → flush Widget rebuilds
    → PipelineOwner layout and paint
    → AssPresenter.push only when data or resolution changed
```

通用 App 将内容根包在 `WidgetsApp` 中，注入 `DisplaySnapshot` 和默认文字样式。
PlayerHostApp 明确注入 Theme/PlayerTheme、PlayerScope 和 HostActionsScope。显示尺寸变化只替换 immutable snapshot 并沿正常 Widget/
Inherited dirty 管线更新，不把 `mp` 传入 framework。默认 mpv actions 由
`host/mpv_actions.lua` 实现为受控 `cycle`/`seek`/`quit` 命令。

根 viewport 使用 mpv OSD 的紧尺寸。presenter 设置 `res_x/res_y`，使逻辑像素和
ASS 坐标一致；不要让 render 层读取 overlay 字符串来做布局。

## 输入

`MpInput` 只依赖 RenderOwner、viewport getter、activity/frame callbacks 和可选的
Navigator key callbacks，不依赖整个 `App`。它监听鼠标位置和按键，把事件交给 RenderOwner。当前输入阶段已经接入
`mp.set_mouse_area()` 区域同步和按区域拆分的 input sections：passive 的 Root/排版
节点不创建输入区域，interactive 控件只在自己的 root-space 区域消费相关事件，
modal/exclusive layer 可以显式阻止穿透。默认情况下，Button 区域会消费
`mbtn_left_dbl`，避免触发用户 `input.conf` 的 `cycle fullscreen`；没有 interactive
区域的播放器背景仍保留用户默认绑定。

PipelineOwner/RenderOwner 继续负责命中路径、hover enter/leave、按下 capture 和冒泡停止规则；
host 负责把 mpv section、mouse area、double-click、modifier 和键盘事件翻译成
结构化输入值。内容画到布局盒外并不自动扩大可点击区域，除非所属 RenderObject
明确实现新的命中边界语义。详细输入规划见 [INPUT.md](INPUT.md)。

Navigator 的 ESC 处理使用独立的 `elxosc-navigation` section；只有当前 Navigator 有可
pop route 时才 enable。没有可 pop 内容时不抢占用户默认 ESC 绑定，KeyEvent 只在 section
已选中后交给 NavigatorState。

输入区域只在 layout、viewport、visibility、DefaultApp/overlay 或 policy 变化时更新，
不应随普通 mouse move 每帧重建。输入行为变化必须同时覆盖 `test/mp_stub.lua` 和
真实宿主 fixture。

## Define 与扩展内容

Define 是用户扩展内容进入播放器的唯一入口，也是初始化期 Widget 构造协议：

开发入口使用同一协议注入 Demo WindowLayer 内容和右侧按钮。`demo_enabled` 默认开启；
该本地 scope 保留 starter 至 0.5 秒初始化窗口关闭，避免其 define_end 抢先 seal 其他脚本。
默认 app 构建器无 extension/pages 参数，受控 slot 清单见 [PLAYER.md](PLAYER.md)。

```text
define_start
  define(scope_id, lua_source)   -- 一个 scope 只接受首次 payload
  define(scope_id, lua_source)   -- 后续同 scope payload 警告并忽略
define_end
```

每个 scope 使用受限 env。`import`/`require`、`import_as`、`mod` 和 `bind` 由 DefineSession 提供；
Widget constructors、`new_widget`、`new_state`、DefaultApp/Slot 接口和宿主 facade 由外部
注入。Define 负责传入扩展内容，不规定扩展内部的运行时行为；扩展可以自行实现
State、消息和页面逻辑，也可以使用播放器预先提供的配置/API 更新接口。

模块使用统一描述 `DefinePackage<T> = { name, exports, loader? }`；`exports` 是类型化的
导出表，合并表通过 `&` 复用来源模块类型。框架 `lib/*.lua` 无条件收集每层的普通
成员导出表，独立于 Define，不附加子模块表。`lib/package_catalog.lua`、player/Define 的
package_catalog 用 export 显式登记所属全部 runtime source、collector、工具和字体资源；
init 别名使用所属 collector，annotation-only metadata 不注册。
`host.package_catalog.collect()` 合并三份清单，不扫描文件；`mpv_define` 为 player
增加快照接口并加入 `mp` facade，统一注册为受保护模块。运行时包名保留短名称；
`elxosc.*` 为生产类型 namespace，不加入 runtime 包名；模块表使用 elxosc.mod.*。

`host/builtins.lua` 显式选择框架构造器、值类型、player/Slot 接口和类工厂，
`mpv_define.builtins()` 返回该表；`lib/material.lua` 仅收集框架。`MpDefineOptions.builtins` 替换默认 surface，host
仍提供 `print`。`define.src.dsl` 只提供类工厂；scope 的 `bind` 由 DefineSession 提供。

`import('player')`/`require('player')` 将名称写入 scope env；
`local player = import_as('player')` 返回包而不注入名称。两者只允许在 payload 中调用，
均使用当前 transaction 可见的模块。`import_as` 浅复制顶层导出并在返回表中执行
`loader(package, scope_id)`；数组成员保留，嵌套值和 class 对象仍共享 identity。
`import_as('mp')` 的 `on_message`/`emit` 因此仍绑定当前 scope。

多级 `import('render.stack')` 和 `import_as('material.slider')` 使用相同解析
规则：只读取 registry 明确登记的模块，不把任意类字段当成模块或加载文件。
整合包与子包分别登记；`import_as('render').RenderStack` 是成员，
`import_as('render.stack')` 返回独立子包，前者没有 stack 子模块字段。
受保护父包阻止 `mod('render.*', ...)`；未知子包仍为 ImportError。扁平导入后恢复
Define 自有的 `import`/`import_as`/`require`/`mod`/`bind`，避免框架 helper 覆盖协议。
mp facade 保留 `commandv(...)` 和 `logger`（`mp.msg`）的当前接口。

`player.context` 精确登记 player.src.context，旧 player_context 包名删除；export、
module_loader 和 painting.canvas 等低层包可独立导入，不进入默认 builtins。扩展使用
`import_as('export').new()` 创建自己的静态组织上下文，声明不自动向 ModuleRegistry
发布，仍通过现有 mod 协议提交。Define 根包输出 sandbox 的 load_chunk/new_env 成员，
独立 define.sandbox 包继续可用；import('define') 后仍恢复 scope-aware 协议函数。

代码在 `define_end` 前登记声明；每个 payload 先在 transaction 中执行，成功后才提交
Contribution 和 module publish。seal 后由一个 `CompositionAssembler` 按 `SlotSpec` 生成
fresh Widget root，`WidgetTree` 只负责 mount/update/dispose，不重复 apply，也不修改
caller-owned Widget。BindRegistry/DefaultApp assembly 不再作为运行时路径。失败 payload
整体丢弃且不消耗 scope。协议明确不提供运行时 unbind、已挂载树回滚、
priority 冲突系统或 Navigator。配置/API 热更新不是第二条内容入口，不重新执行扩展
源代码；扩展需要响应更新时，通过自己的 State/Provider 或公开 setter 处理。

## 扩展编辑器入口

加载 [meta](../../meta/README.md) 与 owning sources 可提示全部框架/player/Define 包和
mp/player scoped facade；运行时不 require meta。tools/generate_meta.py 使用相同静态
catalog 校验 module type，再按明确包名生成 import_as 重载；默认全局仅来自 115 个
host-selected builtins 与五个协议函数/print。扩展声明只用于提示生成，同名不同类型
拒绝，不替代 mod 的 transaction/保护规则。import/require 返回无值，其他环境注入
不作静态推断；需要可靠字段提示使用 import_as。动态包名仅 table fallback。

## 宿主变更规则

### 通用 ASS 测量

`host.ass_measure.AssMeasure({res_x, res_y})` 是显式调用的通用宿主工具，不由 App、Widget
或帧循环加载。分辨率在初始化验证并向下取整一次，必须为有限正数且取整后至少为 1；
实例持有一个 mpv allocator-owned 隐藏 compute_bounds overlay，分辨率固定。它不使用
生产 presenter 的 overlay ID，也不把结果写回 TextLayout/RenderObject。

`measure(data)` 接受已编码的静态 ASS 字符串，直接返回原生 `{x0,y0,x1,y1}` 表；空表
表示空画面。失败返回 `nil, message, kind`，kind 为 `unavailable` 或 `error`。宿主命令
异常被保留；核心只检查输入/返回类型，不扫描可信 payload 或审计每个坐标。生成器和
外部输入边界负责 NUL/ASS 合法性，诊断适配负责数值/矩形审计及报告四态转换。

调用方负责在结束/异常路径 `dispose()`：成功清理返回 true，已清理/无资源返回 false；
清理失败返回 false,error 并保留 ID 供再次 dispose，实例始终关闭，不再接受测量。销毁
释放 payload 引用，移除命令带 data=''，只清理自有 ID。实例不注册 observer、timer 或
shutdown callback。核心没有结果缓存；实际 OSD、默认字体/样式仍影响固定 ASS 坐标的
测量，resize 后需要新结果。同步 Lua 调用没有可抢占的超时。

离线 CLI 复用每种 resolution 的实例，在整个批次结束后统一清理；报告层保留 schema v1、
严格外部输入校验、ok/empty/unavailable/error 和 bounds 转换。清理失败必须报告，不能
将其写成成功批次。CLI 通过 IPC deadline 和自有进程清理处理超时/宿主退出。

工具记录 payload SHA-256、场景版本、OS、mpv/Lua/libass 可得版本和实际 OSD 尺寸；
libass 版本从初始化日志提取，未暴露时明确为空。RecordCanvas 逻辑布局及绘制记录与宿主 bounds 并列，
不将二者强行等同；bounds 不能证明 glyph ink、baseline 或光学中心。字体回退必须在
报告中保留宿主 fontselect 日志。工具 schema、命令和实际限制见 [TESTING.md](TESTING.md)。

宿主服务必须以受控 facade 或明确模块注入，不能把原始 `mp` 暴露给框架层。新增
script-message 或 property API 时，先记录生命周期、错误处理和卸载行为，再添加
mp stub 与真实进程测试。

## 配置/API 热更新

本阶段默认支持配置和对外接口数据的热更新，不支持 Lua 源码热重载。流程为：

```text
mp option/property or public API event
    → validate and create immutable snapshot
    → provider/state or explicit render setter
    → scheduler frame
    → one or more overlay presenters
```

扩展可以订阅播放器公开接口，也可以在 Define 内容中设计自己的消息协议；这些
更新不绕过 Define 注入新的 Widget。订阅、timer、script-message 和 property observer
必须有明确的 dispose/清理生命周期。

当前 6.3 实现提供 host-independent `PlayerStore`、`PlayerSnapshot`/capability values 和 host-side
`MpPlayerContext`。后者可以把指定 mpv property 转换为新的 `PlayerSnapshot`，支持 coalesced
batch observers、异步 capability adapters，并在 dispose 时调用 `mp.unobserve_property` 和
释放 adapter/timer handles。Define 的受保护 `player` 模块提供：

- `get_snapshot()`：读取当前只读快照；
- `on_update(callback)`：订阅 Store 更新并返回可 dispose 句柄。

`import('player')` 还向 scope 注入 `player/src/components.lua` 显式列出的同一类对象；
`player/init.lua` 返回该表，`host/package_catalog.lua` 包装成标准 `player` 包描述：
`PlayerMain`（`Main` 的同类别名）、`WindowLayer`、`DefaultApp`、`PlayerLayout`、`PlayerDescriptionLayer`、
`PlayerTheme`/`PlayerThemeData`、`PlayerControlBar`/`PlayerControlButton`、
`PlayerTimeDisplay`/`PlayerHoverText`、`PlayerTooltip`、`Timeline`、
`PlayerProvider`、`PlayerCapability` 和 `HostActions`。`PlayerIcons` 提供
`spec`/`glyph_name`/`icon` 语义图标入口，不扁平注入短名称。
内部 State、geometry 和 controller assembly helper 不属于此导出清单。
标准 `Tooltip`、`Slider`、`LinearProgressIndicator`、`HoverText` 通过显式选择的 builtins
或 owning 包可用：Tooltip/HoverText 从 `import_as('widgets')`，Slider/LinearProgressIndicator
从 `import_as('material')` 或 material 子包获取；播放器适配复用标准实现。
`widgets` collector 保留基础 framework helper；扁平 import 后由 DefineSession 恢复
scope-aware `bind`。局部包可注解为 `elxosc.mod.widgets`、`elxosc.mod.material`、`elxosc.host.mpv_define.player` 或
`elxosc.host.mpv_define.mp`。该模块仍无内容热注入或 mounted tree 管理能力。

框架内消费者可以使用 `PlayerStore:subscribe_selector(selector, callback)` 只监听相关
字段；列表/窗口/metadata 更新不必让所有 selector consumer 重建。缺失 capability 始终以
`{ status = 'unavailable' }` 表达；外部 adapter 的 loading、available 和 error 状态通过
同一个 immutable snapshot 发布。`PlayerCapability` 提供 mpv-free builder 边界，允许 UI
明确渲染这些状态而不读取 host adapter 或 `mp`。

它不提供替换快照、编辑已挂载 Widget、重新执行 Define 源码或改变 Widget class
identity 的能力。`mp.on_prop`、`mp.on_event` 和 scope `on_message` 都返回幂等
disposable；`MpDefine:shutdown()` 会清理 host-owned handles，State/扩展也应在
自己的 dispose 生命周期中释放仍由自己持有的句柄。

## 多层 overlay

当前 App 只有一个 `AssPresenter`。N2 `Overlay`/`Theatre` 是 framework 内单一逻辑 root
中的 Entry runtime，不是 host-level 多 `osd_overlay`，也不创建独立 root、Canvas 或
PipelineOwner。Entry 的 `visible`、`opaque`、`maintain_state` 和 plan 只控制同一
RenderOwner 的 paint/input eligibility；WindowLayer 空根也只产生空内容，不释放 presenter。

N4 保持单 Canvas/presenter；host-level 多 overlay、独立 presenter、z 排序和跨 surface 输入延期，不得把
`OverlayEntry` 的逻辑顺序当成 `overlay.z` 或 Define priority。
