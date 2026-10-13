# 路线与未实现能力

本文只记录当前实现之后的方向。历史阶段清单保存在 `old/`，不能把其中的草案当
成现有 API。

## 已完成基础

- foundation 几何、颜色、锚点、矩阵和 pointer value types；
- Canvas/Paint/Path/TextPaint 契约，ASS 和 Record 后端；
- Constraints、RenderObject/RenderOwner、布局控件、绘制和命中测试；
- FrameClock/Scheduler/Ticker、Curve/Tween/AnimationController；
- Widget/Element/State/Inherited/Key、WidgetBinding、控件和 Define 期 bind；
- ASS 文本 `left/center/right` 锚点、正轴向有限缩放、TransformBox、
  LayoutScaleBox、paint/layout dirty 分类；
- mpv frame loop、ASS presenter、鼠标输入、Define transport 和真实宿主 fixture。

## 近期方向

1. **宿主输入与控件**：keyboard/focus、Checkbox、Switch、Slider、更多状态样式，
   并保持真实 mpv 输入回归。
2. **渲染性能**：RepaintBoundary、relayout boundary、Picture/Record 缓存以及
   更精细的 dirty 截断；先定义缓存失效和 transform 语义再实现。
3. **文本质量**：真实字体度量、baseline/ascent/descent、逐行 anchor 和 fallback
   字体；不能把 ASS 估算宽度升级为伪精确契约。
4. **交互模型**：Gesture arena、Theme/MediaQuery 和更完整的手势/动画组合。
5. **页面声明**：先完成静态 page/root 声明和 Define 冲突诊断，再评估声明式导航。

以上五项原有规划保持不变。下一阶段把它们依赖的 mpv 输入和播放器应用组合落地，
不把尚未实现的应用层能力倒写成当前核心 API。

## 新增下一阶段：MPV 输入与播放器应用层

### 6.0 输入契约 spike

- 验证 `mp.set_mouse_area()` 的坐标、多矩形、section priority 和 mpv/mpv.net 差异；
- 验证 `mbtn_left_dbl`、用户 `input.conf`、`force`/exclusive 的实际优先级；
- 以最小 mp stub/real-host fixture 固化结论。

### 6.1 输入区域与默认行为隔离

- 增加 root-space interactive area 快照和 logical-to-window 坐标转换；
- Root、Column、Row、Padding、Align 等排版节点默认为 passive，不吞播放器输入；
- Button 等 interactive 区域默认消费双击，避免按钮触发用户 fullscreen；
- 没有 interactive 区域的播放器背景保留用户默认绑定；
- 按 visibility、Pages、overlay、layout、resize 更新和清理 mouse area/section。

### 6.2 输入系统重构

- 结构化 PointerEvent/KeyEvent、modifier、button、click count、wheel 和 timestamp；
- 引入结构化 dispatch result，区分 handled、capture 和传播停止；默认行为由 host
  的区域/事件族 claim policy 在 section 选择前决定；
- 保留当前 RenderOwner capture 语义，并为 keyboard/focus、Gesture arena 留出接口。

### 6.3 配置/API 热更新与 PlayerContext

- 完善 BuildContext 的 `of`/`maybe_of` 使用模式；
- 配置默认支持运行时热更新，解析为不可变 snapshot，再驱动 Provider/State/setter；
- 对外接口数据支持订阅和清理；扩展可使用预先提供的接口，也可在 Define 内容中
  设计自己的更新协议；
- 不支持 Lua 源码热重载，不重新执行扩展代码，不改变 Widget class identity。

### 6.4 Pages/Main 与扩展内容

- 建立 `Root → Pages → Main / 3x3 grid / more` 的应用组合层；
- Main 拥有标题栏、时间线、底部按钮、两侧按钮及其稳定 id/快捷绑定元数据；
- Define 作为扩展唯一入口，提供将扩展页面加入 Pages 和区域内容的公开接口；
- 明确 region single/multi-child、ordered append、冲突诊断和 mounted 生命周期；
- 不在本阶段引入 Navigator 或把 Define 改成 runtime tree manager。

### 6.5 多层 overlay

- 建立 host-level OverlayHost/Registry，支持多个独立 `osd_overlay` layer；
- 每个 layer 保有 root、RenderOwner、Canvas、presenter、visible、z、dirty/cache 和
  input policy；
- `overlay.z` 只决定视觉顺序，较高 z 在前，同 z 使用稳定注册顺序；
- overlay 可用于 Pages 的 main/extension/popup/system 层，但不成为 Widget 或 bind
  priority；
- 隐藏/移除 layer 时清理 ASS、mouse area、hover、capture 和订阅。

### 6.6 播放器 Shell

- 顶层控件支持 visible/hidden 和 auto/always/never 策略；
- hidden layer 不绘制、不创建 input area；modal 打开时可以切换 exclusive policy；
- 将当前 scaffold 逐步收敛为 Pages/Main/grid/more，而不是一次性重写全部控件；
- 使用已有 Scheduler、State、dirty 和 ASS presenter 管线，先做可观察行为再优化性能。

阶段 6 的完整输入和播放器应用规划见 [INPUT.md](INPUT.md) 与 [PLAYER.md](PLAYER.md)。

## 明确不做的静默兼容

- 不用 ASS `\move`/`\t` 替代 FrameClock 动画；
- 不把旋转、倾斜、零/负 scale 或任意仿射约束近似成轴向缩放；
- 不把 Define 变成运行时树管理器；
- 不把配置/API 热更新扩展成 Lua 源码或模块代码热重载；
- 不新增第二条扩展内容注入通道；
- 不把 `overlay.z` 当成 Widget、Pages 或 Define priority；
- 不在核心层引入 `mp`；
- 不以动态聚合表、`any` 或宽泛 `string` 逃避类型和 identity 契约。

任何新方向先新增或更新对应方向文档、公共行为测试和模块 README，再进入实现。
