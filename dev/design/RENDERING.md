# 渲染、布局与动画

本文负责约束布局、绘制契约、文本定位、ASS 限制、变换和 dirty 分类。

## 约束布局

布局遵循三个方向：**Constraints go down. Sizes go up. Parent sets position.**
`Constraints` 的四个边界必须归一、有限（允许代表无界的 `math.huge`），RenderObject
最终报告的尺寸必须有限并满足父约束。

- `unbounded()` 表示 `0..∞`。
- `expand()` 表示 Flutter 语义的紧无穷，只有与父约束合并后才会落地。
- `enforce()` 取附加约束的交集；`tighten()` 只收紧已存在的边界。
- 子节点的局部尺寸不因绘制偏移自动变大；父节点决定是否裁剪和是否扩大命中区域。

`FittedBox` 使用源/目标盒映射；`TransformBox` 保留子节点原布局尺寸；
`LayoutScaleBox` 把正轴向缩放纳入约束逆映射和最终报告尺寸。三者的区别是公共
语义，不能通过一个通用 scale 属性模糊掉。

## RenderObject 和 dirty

RenderObject 实例跨帧存活。setter 必须在属性边界验证值并选择最小失效范围：

| 属性 | 失效 |
| --- | --- |
| 平移、视觉偏移、颜色、纯绘制 scale、clip | paint |
| 宽高、padding、约束、字号、行距、布局 scale | layout + paint |
| Widget 子树结构 | build，再按结果 layout/paint |

动画控制器不决定 dirty 类别；目标 RenderObject 的 setter 决定。动画监听在节点
脱离 owner 时必须解除，替换 controller/tween 时必须移除旧监听。

## PipelineOwner 和 PaintingContext

`PipelineOwner` 是 RenderObject pipeline 的规范名称；当前单根实现由
`render/pipeline_owner.lua` 重导出既有 `RenderOwner` class，两个入口保持相同 identity。
它负责 viewport、layout/paint dirty、`flush_layout()`、`flush_paint()` 和 visual update
通知；每个 attached WidgetTree 拥有自己的 PipelineOwner，不负责 mpv input section、
hover/capture 或 presenter 产品策略。

RenderObject 的 paint 边界使用 `PaintingContext`：context 持有当前 Canvas，统一 child
paint、offset、clip 和 save/restore；现有 Canvas 入口在迁移期间仍可直接调用。它不是
Flutter Layer tree，不暴露 ASS `Layer`/`ReadOrder`，不改变布局或 hit testing。

当前 frame 顺序为：transient/ticker → Widget build scopes → inactive finalize → layout
→ input region snapshot → PaintingContext paint → presenter → post-frame callbacks。
F runtime 首版每个 production owner scope 仍只支持一个 root 和一个 Canvas；Binding
composition 不因 attached owner scope 增加而复制。

## Canvas 和文本

`Canvas` 使用逻辑像素，负责 save/restore、平移、正轴向 scale、裁剪和图元绘制。
`TextStyle` 只表达样式意图，`TextPaint` 负责九宫格 anchor 和视觉偏移；
`Paragraph.size` 是自然文本尺寸，`RenderText.size` 是受约束的布局盒。

普通文本定位规则：

| `TextStyle.align` | RenderText 目标 | ASS |
| --- | --- | --- |
| `left` | 中左 | `\an4` |
| `center` | 中心 | `\an5` |
| `right` | 中右 | `\an6` |

如果传入显式 `TextPaint({ anchor = ... })`，它覆盖样式对齐并允许 `\an1` 到
`\an9` 的完整映射。`TextPaint.offset` 只进入绘制变换，不改变布局或 hit test。

## ASS 后端边界

ASS Canvas 将矩阵变换降低为静态事件：路径坐标经过平移/缩放，文本使用
`\fscx`/`\fscy`，裁剪在最终逻辑坐标中求交。只接受有限正缩放；旋转、倾斜、
零/负缩放和任意仿射布局不能静默近似。

ASS `osd-overlay` 的 `ass-events` 不提供本框架需要的 PTS 动画推进，因此禁止
生成 `\move`、`\t` 等标签。`AnimationController` 每帧更新框架值，下一帧重新输出
静态 `\pos`、缩放或颜色参数。这样 UI 动画不依赖媒体播放状态。

## 输入和绘制的变换

绘制变换必须有对应的输入逆映射：`OffsetBox`、`TransformBox`、`FittedBox` 和
缩放盒都要覆盖 `hit_test`/`pointer_path` 的局部坐标转换。内容画到布局盒外不自动
意味着它可点击；clip 和父节点命中边界仍然有效。

## 应用组合、Widget z-order 与 overlay z-order

三种顺序必须分开：

1. **DefaultApp/布局顺序**决定 Main、Extension 和 WindowLayer entries，以及 entry
   内 Widget 的父子关系；
2. **Overlay/Widget Stack paint order**决定同一个 RenderObject tree 内的绘制先后；
3. **未来 host overlay.z** 才决定不同 `osd_overlay` layer 的最终视觉层级。

`OverlayEntry` 的 visible/opaque/occluded/paint/input plan 属于同一 Widget runtime，
不创建第二个 owner，也不进入 BindRegistry priority。`overlay.z` 只属于未来 host
presentation，不进入 Widget、Element、RenderObject 或 BindRegistry。未来 OverlayHost
为每个命名 layer 保存独立的 root、RenderOwner、Canvas、presenter、dirty/cache、visible
和 input policy。较高 z 视觉上位于较低 z 之上；相同 z 使用稳定注册顺序，不能依赖表遍历
顺序。

同一 Theatre 的 hidden/occluded entry 通过 Offstage 同时移除绘制、hit test 和 pointer
regions；maintain_state 只保留 Element/State 生命周期。未来 host layer 的输入按可见、
interactive layer 的 z 倒序查询，选中 layer 后再使用其 RenderOwner 的 pointer path 和
capture 规则。passive layer 不因为 z 较高就吞掉背景输入；modal/exclusive layer 必须
显式请求拦截。host layer 隐藏或移除时必须清掉自己的 ASS 输出、mouse area、hover 和
capture。

每个 overlay 的输出仍是独立的静态 ASS 帧。overlay 的 z 不替代 `Canvas:save()`、
`Stack` 或页面布局，也不允许使用 `\move`/`\t` 实现跨层动画。

## 配置/API 更新与绘制

播放器配置和公开 API 的热更新先转换成不可变 snapshot，再进入 Provider/State 或
明确的 RenderObject setter。它可以触发正常 rebuild/layout/paint，但不得重新执行
扩展源代码、改变 Widget class identity 或直接修改 mounted Widget。扩展内容仍只能
通过 Define/Slot 进入 DefaultApp 的初始化边界；更新接口只是数据和事件流。

## 当前限制

当前没有逐字精确的 libass ink bounds、baseline/ascent 模型、离屏 group opacity、
RepaintBoundary 或大列表虚拟化。新增能力必须先定义逻辑尺寸、绘制溢出和输入区域
的区别，再添加后端和真实宿主回归。
