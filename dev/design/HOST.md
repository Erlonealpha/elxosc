# mpv 宿主与 Define 协议

本文负责 mpv 边界、帧循环、ASS presenter、输入接线以及初始化期 Define。

## 宿主边界

只有 `host/`、`main.lua` 和 `elxlib_load.lua` 可以加载 `mp`。核心通过以下契约
保持可测试和可复用：

- `Canvas`：输出绘制原语；当前由 `AssCanvas` 和 `RecordCanvas` 实现。
- `TextLayout`：提供后端文本测量；当前由 `AssTextLayout` 估算。
- `FrameClock`：请求并触发帧；mpv 实现按显示刷新率限流。
- 输入值对象：宿主把鼠标/按键转换为 `PointerEvent` 和局部坐标。

## App 帧循环

`host.mpv_app.App` 获取共享的 `WidgetsBinding` composition，再为自己的 tree 创建
独立 PipelineOwner/BuildOwner、Scheduler、AssCanvas 和 AssPresenter：

```text
mp property / input / dirty callback
    → schedule_frame (coalesced + refresh-rate limited)
    → transient ticker/controller callbacks
    → flush Widget rebuilds
    → PipelineOwner layout and paint
    → AssPresenter.push only when data or resolution changed
```

App 将内容根包在 `WidgetsApp` 中，注入 `DisplaySnapshot`、`ThemeData`、默认文字样式和
host-independent `HostActions`。显示尺寸变化只替换 immutable snapshot 并沿正常 Widget/
Inherited dirty 管线更新，不把 `mp` 传入 framework。默认 mpv actions 由
`host/mpv_actions.lua` 实现为受控 `cycle`/`seek`/`quit` 命令。

根 viewport 使用 mpv OSD 的紧尺寸。presenter 设置 `res_x/res_y`，使逻辑像素和
ASS 坐标一致；不要让 render 层读取 overlay 字符串来做布局。

## 输入

`MpInput` 监听鼠标位置和按键，把事件交给 RenderOwner。当前输入阶段已经接入
`mp.set_mouse_area()` 区域同步和按区域拆分的 input sections：passive 的 Root/排版
节点不创建输入区域，interactive 控件只在自己的 root-space 区域消费相关事件，
modal/exclusive layer 可以显式阻止穿透。默认情况下，Button 区域会消费
`mbtn_left_dbl`，避免触发用户 `input.conf` 的 `cycle fullscreen`；没有 interactive
区域的播放器背景仍保留用户默认绑定。

PipelineOwner/RenderOwner 继续负责命中路径、hover enter/leave、按下 capture 和冒泡停止规则；
host 负责把 mpv section、mouse area、double-click、modifier 和键盘事件翻译成
结构化输入值。内容画到布局盒外并不自动扩大可点击区域，除非所属 RenderObject
明确实现新的命中边界语义。详细输入规划见 [INPUT.md](INPUT.md)。

输入区域只在 layout、viewport、visibility、DefaultApp/overlay 或 policy 变化时更新，
不应随普通 mouse move 每帧重建。输入行为变化必须同时覆盖 `test/mp_stub.lua` 和
真实宿主 fixture。

## Define 与扩展内容

Define 是用户扩展内容进入播放器的唯一入口，也是初始化期 Widget 构造协议：

```text
define_start
  define(scope_id, lua_source)   -- 一个 scope 只接受首次 payload
  define(scope_id, lua_source)   -- 后续同 scope payload 警告并忽略
define_end
```

每个 scope 使用受限 env。`import`/`require`、`mod` 和 `bind` 由 DefineSession 提供；
Widget constructors、`new_widget`、`new_state`、DefaultApp/Slot 接口和宿主 facade 由外部
注入。Define 负责传入扩展内容，不规定扩展内部的运行时行为；扩展可以自行实现
State、消息和页面逻辑，也可以使用播放器预先提供的配置/API 更新接口。

代码在 `define_end` 前登记声明；每个 payload 先在 transaction 中执行，成功后才提交
Contribution 和 module publish。seal 后由一个 `CompositionAssembler` 按 `SlotSpec` 生成
fresh Widget root，`WidgetTree` 只负责 mount/update/dispose，不重复 apply，也不修改
caller-owned Widget。BindRegistry/DefaultApp assembly 不再作为运行时路径。失败 payload
整体丢弃且不消耗 scope。协议明确不提供运行时 unbind、已挂载树回滚、
priority 冲突系统或 Navigator。配置/API 热更新不是第二条内容入口，不重新执行扩展
源代码；扩展需要响应更新时，通过自己的 State/Provider 或公开 setter 处理。

## 宿主变更规则

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

当前 6.3 实现提供 host-independent `PlayerStore` 和 host-side
`MpPlayerContext`。后者可以把指定 mpv property 转换为新的 `PlayerSnapshot`，并在
dispose 时调用 `mp.unobserve_property`。Define 的 `player` 模块只提供：

- `get_snapshot()`：读取当前只读快照；
- `on_update(callback)`：订阅 Store 更新并返回可 dispose 句柄。

它不提供替换快照、编辑已挂载 Widget、重新执行 Define 源码或改变 Widget class
identity 的能力。`mp.on_prop`、`mp.on_event` 和 scope `on_message` 都返回幂等
disposable；`MpDefine:shutdown()` 会清理 host-owned handles，State/扩展也应在
自己的 dispose 生命周期中释放仍由自己持有的句柄。

## 多层 overlay

当前 App 只有一个 `AssPresenter`。N2 `Overlay`/`Theatre` 是 framework 内单一逻辑 root
中的 Entry runtime，不是 host-level 多 `osd_overlay`，也不创建独立 root、Canvas 或
PipelineOwner。Entry 的 `visible`、`opaque`、`maintain_state` 和 plan 只控制同一
RenderOwner 的 paint/input eligibility；WindowLayer 空根也只产生空内容，不释放 presenter。

host-level 多 overlay、独立 presenter、z 排序和跨 surface 输入策略仍属于后续 N4，不得把
`OverlayEntry` 的逻辑顺序当成 `overlay.z` 或 Define priority。
