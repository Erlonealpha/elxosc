# 路线与未实现能力

本文按能力记录当前缺口、依赖和长期方向。现有架构及行为由
[DESIGN.md](DESIGN.md) 和 owning 方向文档说明；实施阶段、分支状态和验收进度由
本地规划承担。以下方向不是已提供的 API，也不表示具体实施顺序。

## 文本布局与质量

当前ASS单行布局已有注入式宿主定位跨度、环境替换和有界缓存，离线/不可靠结果退估算。
Tooltip已在局部prepare阶段测量，播放器内容盒与hitbox在预分配区域内收缩；
整行跨度不等于逻辑advance或ink bounds，复杂script的独立字体参考仍未提供。

后续文本能力包括baseline/ascent/descent、逐行定位、多行布局、
fallback 与复杂 script 边界。Tooltip 和播放器标题/时间/metadata 的布局应复用文本
合同；不能用 ASS 图像矩形包装出未经验证的精确文字度量。相关边界见
[RENDERING.md](RENDERING.md) 和 [HOST.md](HOST.md#通用-ass-测量)。

## 标准控件和扩展开发

现有 Slider、LinearProgressIndicator、Tooltip 及按钮 family 需要继续收敛数值、交互、
样式和配置合同，并补充设置、菜单、列表需要的 Checkbox、Switch、选择及菜单控件。
基础机制归 widgets/render，视觉默认和主题归 Material，媒体语义归 player。

扩展应直接复用公开组件和按用途读取的主题，避免复制 Main 的布局与私有 State。
新增控件依赖明确的文本布局、输入状态、焦点或滚动能力时，先建立底层合同；不把
示例 UI 当作通用运行时能力。公共 API 说明、示例和编辑器类型提示应从 owning source
及明确 catalog 组织，meta 验证与运行时验证分别进行。

## 输入与交互

结构化 pointer path 和独立 KeyEvent 值对象已存在；通用 keyboard target/focus、Tab
遍历、宿主 key translation、可靠 modifier、IME、Gesture arena 和完整 modal key policy
仍需设计。现有 Navigator ESC 返回不是通用焦点系统。

输入能力扩展必须保持区域空隙和背景透传、section 事前 claim、多按钮 capture、
卸载 cancel 与旧 up 清理，以及真实 move 才重新命中的规则。多 surface 输入还依赖
独立 host layer 所有权；目标宿主的优先级和坐标行为需要真实进程回归。见
[INPUT.md](INPUT.md)。

## 渲染性能

生产没有 Flutter 同义的 RepaintBoundary、RelayoutBoundary 或通用 Picture/Record
缓存。优化先定义布局、文本、样式、transform、clip 和输入失效，再用同环境 benchmark
及逐事件输出等价验证。动画控制器只提供时间和值，目标 setter 决定 dirty 类别。

播放器高刷新率更新的 build/layout/input regions 成本需要按真实播放场景评估，优先
收窄 Provider 依赖和复用稳定控件、callback、style，使连续进度只失效必要节点。
不能仅从静态子树重放或暂停场景推断播放性能，也不能由目录重组承诺 240 Hz 改善。
大列表虚拟化依赖独立滚动、布局和生命周期合同。

## 播放器和配置

默认 Main、AutoHide、thumbfast、扩展按钮和最小 Page/Popup 已提供；后续播放器方向
包括完整 ModernX 配置及全局快捷键兼容、字幕 `sub-pos` 避让、更多 shell 页面产品及
idle 装饰。新产品与第三方 UI 集成应明确 capability、资源所有权和人工审阅范围。

当前数据更新已有 snapshot/Store/Provider/State 链路；统一配置解析、schema 和更多
运行时设置应复用该链路。配置或 API 数据更新不重新执行扩展源码、不重复注册资源，
也不是新的 Widget 内容入口。见 [PLAYER.md](PLAYER.md)。

## 逻辑页面与 host layers

现有 Navigator/Route 运行在同一 Theatre；完整 focus、restoration、Hero、复杂 transition、
nested Navigator 状态恢复和 browser parser 尚未支持。新增声明式页面入口必须与
初始化 Define 贡献、运行时 State 行为和冲突诊断区分。

host-level 多 overlay、独立 Canvas/Presenter/root、z 排序和跨 surface 输入尚未提供。
新增 layer 必须定义 create/update/remove、缓存、可见性、输入 policy 和 owned cleanup；
逻辑 OverlayEntry 的插入顺序不能当作 host `overlay.z`。支持边界见
[HOST.md](HOST.md#多层-overlay) 和 [PLAYER.md](PLAYER.md#逻辑-overlay-与未来-host-layers)。

## 明确非目标

- 不用 ASS `\move`/`\t` 替代 FrameClock 静态输出。
- 不把旋转、倾斜、零/负 scale 或任意仿射约束静默近似为轴向缩放。
- 不把 Define 变成运行时树管理器，不新增第二条扩展内容入口。
- 配置/API 热更新不默认扩展为 Lua 源码或模块重载。
- 不把 `overlay.z` 当作 Widget、页面或 Define priority。
- 不在框架、player 或 define 中引入 `mp`。
- 不以动态整合表、`any` 或宽泛 `string` 绕过类型和 identity 契约。

进入实现前，更新对应 owning 方向的公共合同、模块 README 和必要行为回归；技术
探索和实施清单留在规划材料，不倒写成当前支持能力。
