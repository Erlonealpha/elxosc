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

`host.mpv_app.App` 将 WidgetBinding、RenderOwner、Scheduler、AssCanvas 和
AssPresenter 组装起来：

```text
mp property / input / dirty callback
    → schedule_frame (coalesced + refresh-rate limited)
    → transient ticker/controller callbacks
    → flush Widget rebuilds
    → RenderOwner layout and paint
    → AssPresenter.push only when data or resolution changed
```

根 viewport 使用 mpv OSD 的紧尺寸。presenter 设置 `res_x/res_y`，使逻辑像素和
ASS 坐标一致；不要让 render 层读取 overlay 字符串来做布局。

## 输入

`MpInput` 监听鼠标位置和按键，把事件交给 RenderOwner。RenderOwner 负责命中路径、
hover enter/leave、按下 capture 和冒泡停止规则；宿主不直接调用 Button 回调。

内容画到布局盒外并不自动扩大可点击区域，除非所属 RenderObject 明确实现新的
命中边界语义。输入行为变化必须同时覆盖 `test/mp_stub.lua` 测试和真实宿主 fixture
（当行为依赖 libass/mpv 时）。

## Define 生命周期

Define 是初始化期 Widget 构造协议：

```text
define_start
  define(scope_id, lua_source)   -- 一个 scope 只接受首次 payload
  define(scope_id, lua_source)   -- 后续同 scope payload 警告并忽略
define_end
```

每个 scope 使用受限 env。`import`/`require`、`mod` 和 `bind` 由 DefineSession 提供；
Widget constructors、`new_widget`、`new_state` 和宿主 facade 由外部注入。代码在
`define_end` 前只登记声明，BindRegistry 在挂载前一次性写入目标 Widget 树。

协议明确不提供：运行时 unbind、scope 关闭、已挂载树回滚、root rebuild、priority
冲突系统或 Navigator。脚本若需要运行时行为，应创建 StatefulWidget，并通过已注入
的消息/property 服务调用 `set_state`。

## 宿主变更规则

宿主服务必须以受控 facade 或明确模块注入，不能把原始 `mp` 暴露给框架层。新增
script-message 或 property API 时，先记录生命周期、错误处理和卸载行为，再添加
mp stub 与真实进程测试。
