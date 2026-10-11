# 设计文档索引

本文档中的代码路径均相对于仓库根目录；同目录 Markdown 链接使用相对路径。

- [DESIGN_PATH.md](DESIGN_PATH.md)：架构地图与阶段性交接记录。
- [DESIGN.md](DESIGN.md)：Flutter 对照和扩展协议的历史设计推演。
- [DESIGN_CONSTRAINTS.md](DESIGN_CONSTRAINTS.md)：约束模型修复及示例测试记录。
- [DESIGN_RENDERING_ANIMATION.md](DESIGN_RENDERING_ANIMATION.md)：ASS 能力边界、
  文本契约与变换/动画分阶段规划；第零阶段、阶段 1 和阶段 2 已完成。

## 当前状态摘要

当前仓库已经具备可运行的 Flutter 风格框架核心：约束布局、RenderObject/Element/
Widget 三棵树、State rebuild、key reconciliation、layout/paint dirty 分离、
pointer event 与 capture、ASS/Record 后端，以及 Button 系列控件。控件实现按基础
类型平铺，旧的 `basic.lua`/`layout.lua` 仅作为兼容聚合入口。

宿主侧已具备 mpv.net 帧循环、ASS overlay、鼠标输入、隔离的真实宿主测试和
Button 事件注入测试。阶段 2 当前验证基线为 **960 checks**、EmmyLua
`No issues found`、真实 mpv.net 测试 **6 passed**；命令与范围见
[渲染与动画完成记录](DESIGN_RENDERING_ANIMATION.md)。

文本接口统一为 `TextStyle({ font_size = ..., ... })`，`copy_with()` 可覆盖字号并
保留 false/0。`TextLayout:line_height(style)` 有默认逻辑行距；`TextPaint` 现在以
独立的九宫格 anchor 和视觉偏移描述文本绘制，Icon 使用固定 nominal box。

## Define 当前语义

Define 只在启动阶段用于构建一次初始 Widget 树，不是运行时 UI 管理器：

- 每个 `scope_id` 只接受第一次 `define` payload；重复 payload 告警并忽略。
- 同一 scope 对同一 target 多次 bind 允许，但不推荐；按现有 bind 顺序执行。
- 不同 scope 的冲突由 target 类型和 bind 操作决定，不引入额外优先级。
- 不存在 scope 关闭、运行时解绑、Widget 树回滚或 root 重建。
- 用户脚本需要运行时行为时，使用消息系统驱动自定义 StatefulWidget。

旧记录中的测试数量、实现清单和未来阶段不是实时状态；以当前代码和实际测试
输出为准。代码规范以根目录 `codestyle.md` 为准，贡献流程见 `AGENTS.md`。

## 下一阶段：扩展声明系统（第一切片已实现）

其他脚本应能向预设区域贡献普通 Widget，也能声明完整页面。宿主使用常规布局
控件规定区域及约束，底层不得硬编码“工具栏按钮”或特殊页面 RenderObject。
区域挂载、页面注册与 mpv 消息传输分层处理，避免让 MpDefine 承担布局职责。

当前第一切片已为 `BindRegistry` 增加可选的 `scope_id` 所有权，并支持在挂载前
撤销某个 scope 的待处理绑定；旧的三参数 `bind(id, widget, opts)` 调用保持兼容。
它只管理声明记录，不回滚已经写入 Widget 树的结果，也没有修改 mpv 消息协议。

Define 仍然只用于启动阶段构建一次初始 Widget 树：同一个 `scope_id` 的重复
`define` 会报告警告并忽略后续 payload；同一 scope 对同一 target 的多次 bind
仍允许，但不额外引入优先级。不同 scope 的冲突继续由 target 类型和 bind 操作
决定。没有运行时 scope 关闭、Widget 树重建或导航 API。

下一切片聚焦声明冲突诊断、target 约束文档和页面声明的静态模型。页面定义与
导航状态分开；未来 Navigator 2.0 风格方案由声明式页面列表驱动，默认主页面也
走相同页面模型。当前不新增未经实现验证的导航 API。

## 未来路线

当前渲染工作按 [渲染与动画规划](DESIGN_RENDERING_ANIMATION.md) 推进：文本契约、
平移/动画基础、锚点与图标已完成，下一步是有限缩放和布局动画。mpv `osd-overlay`
中的 `\move`、`\t` 等 PTS 相关标签不可用于动画，统一由框架时钟逐帧驱动。

1. **宿主与控件**：keyboard/focus、Checkbox/Switch/Slider、更多样式控件和真实
   mpv.net OSD/事件集成测试。
2. **框架性能**：RepaintBoundary、relayout boundary、Picture 缓存、Viewport/
   Sliver 和大列表虚拟化。
3. **交互能力**：Gesture arena、动画控制器、Tween/Curve、Theme/MediaQuery。
4. **页面模型**：先定义静态 page/root 声明和冲突诊断，再实现 Navigator 2.0 风格
   的声明式页面列表；不改变一次初始化 Widget 树的 Define 语义。
5. **宿主质量**：下沉 debug 工具、升级文本度量、处理 input.conf 回退和
   `osd-margins`。
