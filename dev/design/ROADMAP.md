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

## 明确不做的静默兼容

- 不用 ASS `\move`/`\t` 替代 FrameClock 动画；
- 不把旋转、倾斜、零/负 scale 或任意仿射约束近似成轴向缩放；
- 不把 Define 变成运行时树管理器；
- 不在核心层引入 `mp`；
- 不以动态聚合表、`any` 或宽泛 `string` 逃避类型和 identity 契约。

任何新方向先新增或更新对应方向文档、公共行为测试和模块 README，再进入实现。
