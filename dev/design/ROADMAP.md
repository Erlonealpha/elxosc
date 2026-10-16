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

- 已完成结构化 PointerEvent/KeyEvent、modifier 字段契约、button、click count、wheel
  和 timestamp/source；当前 mpv Lua binding 没有可靠 modifier 来源，host 明确暂留 nil；
- 已引入结构化 dispatch result，区分 handled、capture 和传播停止；默认行为由 host
  的区域/事件族 claim policy 在 section 选择前决定；
- 已保留当前 RenderOwner capture 语义；keyboard target/focus、key translation 和
  Gesture arena 仍留作后续接口。

### 6.3 配置/API 热更新与 PlayerContext

- 核心 `Provider.of`/`maybe_of`、PlayerStore、PlayerScope 和热更新链路已完成；
- 已完成 Provider exact lookup、非监听 `read`/`maybe_read`、
  `did_change_dependencies` 和 init/dispose lookup 边界回归；
- 已提供 host-independent `PlayerSnapshot`、`PlayerStore`、`PlayerScope` 和
  `PlayerProvider`，更新经过 Provider/State/BuildOwner 管线；
- 已提供 mpv property bridge、可 dispose 的 property observer，以及 Define 的只读
  `player` module；
- 配置/API 更新不支持 Lua 源码热重载，不重新执行扩展代码，不改变 Widget class
  identity。完整播放器字段 schema 由后续应用层按实际消费点增加。

### 6.4 Pages/Main 与扩展内容

- 启动门槛：6.3 的 exact lookup、read API、依赖生命周期和 lookup 边界测试必须先
  完成；Pages 注册阶段只能使用不可变输入和非监听读取，consumer Widget 才能在
  build/did_change_dependencies 中建立依赖；
- 建立 `Root → Pages → Main / 3x3 grid / more` 的应用组合层；
- Main 拥有标题栏、时间线、底部按钮、两侧按钮及其稳定 id/快捷绑定元数据；
- Define 作为扩展唯一入口，提供将扩展页面加入 Pages 和区域内容的公开接口；
- 明确 region single/multi-child、ordered append、冲突诊断和 mounted 生命周期；
- 不在本阶段引入 Navigator 或把 Define 改成 runtime tree manager。

### 6.5 多层 overlay

- 建立 host-level OverlayHost/Registry，支持多个独立 `osd_overlay` layer；
- 每个 layer 保有 root、RenderOwner、Canvas、presenter、visible、z、dirty/cache 和
  input policy；
- overlay policy、input callback 和 remove/shutdown 流程使用非监听 Provider read，
  不在 host callback 中建立 Widget 依赖；
- `overlay.z` 只决定视觉顺序，较高 z 在前，同 z 使用稳定注册顺序；
- overlay 可用于 Pages 的 main/extension/popup/system 层，但不成为 Widget 或 bind
  priority；
- 隐藏/移除 layer 时清理 ASS、mouse area、hover、capture 和订阅。

### 6.6 播放器 Shell

- 顶层控件支持 visible/hidden 和 auto/always/never 策略；
- hidden layer 不绘制、不创建 input area；modal 打开时可以切换 exclusive policy；
- 将当前 scaffold 逐步收敛为 Pages/Main/grid/more，而不是一次性重写全部控件；
- Shell build 使用监听式 Provider，init/event/resource callback 使用非监听 read，
  依赖资源变化通过 `did_change_dependencies` 处理；
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
