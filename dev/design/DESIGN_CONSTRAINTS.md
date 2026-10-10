# 约束模型对齐 Flutter（修复记录）

对标文档：<https://docs.flutter.dev/ui/layout/constraints>

目标：把 elxosc 的布局设计对齐 Flutter 的约束模型，使文档中的每条规则
（"Constraints go down. Sizes go up. Parent sets position."、三类盒子、tight /
loose / unbounded、Flex 六步算法）在框架里都可复现，并用测试固化。

所有改动都附了测试，见 `test/test_constraints_examples.lua`（逐字比较原始
`ass-events` 输出）和 `test/test_layout.lua`（约束代数）。

---

## 1. 修复清单（按依赖从少到多）

### 1.1 `layout/constraints.lua` —— 约束代数

之前的 `Constraints` 只有 `constrain_* / has_bounded_* / is_tight /
deflate / loosen`，缺少"只施加附加约束"的运算，是后面多个问题的根因。

| 新增/修正 | 与 Flutter 对应 |
| --- | --- |
| `enforce(other)` | `BoxConstraints.enforce`：把四个值分别夹进对方的 `[min,max]`，即**取交集** |
| `tighten{width,height}` | `BoxConstraints.tighten` |
| `normalize()` | `BoxConstraints.normalize` |
| `has_infinite_width/height`、`has_tight_width/height` | 同名 getter（infinite = `min == ∞`） |
| `biggest()` / `smallest()` / `is_satisfied_by(size)` | 同名 getter / 方法 |
| `constrain_size_and_attempt_to_preserve_aspect_ratio(size)` | 同名方法（`FittedBox` 的尺寸规则） |
| `tight_for{width,height}` | `BoxConstraints.tightFor`（未给的轴为 `0..∞`） |
| **`expand(width,height)` 改为紧无穷** | `BoxConstraints.expand` 是 "tightly infinite"（`min == max == ∞`），只在被 `enforce` 后才落地 |
| 新增 `unbounded()` | Flutter 默认构造 `BoxConstraints()`（`0..∞`），即旧 `expand()` 的语义 |

> 命名坑：旧代码把 `expand()` 当作"无界"用（测试里到处是
> `Constraints.expand()`）。这是与 Flutter **同名不同义**，最易误用；现在
> "无界"一律写 `unbounded()`。

### 1.2 `render/render_object.lua` —— 无限尺寸守卫

`layout()` 在 `__perform_layout` 之后统一 `constrain`，现在还会校验尺寸有限：
非有限即抛 `BoxConstraints forces an infinite width/height`。
对应文档 Example 16（`Container(width: infinity)`）与 Example 22（`FittedBox`
里放无界子节点）——Flutter 会报错而不是画出垃圾坐标。

### 1.3 `render/sized_box.lua` —— `SizedBox` / `RenderConstrainedBox`

- 用 `additional:enforce(constraints)` **取交集**，不再直接覆盖 `min/max`。
  这是 `SizedBox` 文档 "Why is my SizedBox ignored?" 的规则：父约束更紧时
  子节点被父约束压住。
- 无子节点时缺失的轴按 **0** 处理（`enforce` 之后 `constrain(Size.zero)`），
  不再取父的 `max`。

### 1.4 `render/padding.lua`、`render/align.lua` —— 无子节点

- `RenderPadding` 无子：`size = constrain(Size(padding.h, padding.v))`（以前是 0）。
- `RenderPositionedBox` 无子：按 `shrinkWrap` 规则 `constrain(Size(∞ 或 0, ∞ 或 0))`，
  在 bounded 轴上填满（以前直接 `return`，尺寸恒为 0）。

### 1.5 `render/custom_paint.lua`

- 无 `preferred_size` 默认 `Size.zero`（Flutter 的 `CustomPaint.size` 默认值），
  不再"撑满父约束"。
- 有子时把**原约束**透传给子（`RenderProxyBox`），不再 `loosen()`。

### 1.6 `render/flex.lua` —— `RenderFlex` 重写

按 `RenderFlex.performLayout` 逐步移植：

| 修正 | 说明 |
| --- | --- |
| 非 flex 子节点主轴 **无界** | 只保留 cross 约束（`stretch` 时 cross 取 tight），对应文档 Example 23/24 |
| `main_axis_size`（`'max'`/`'min'`） | `max` + 有界主轴 → 主轴取父 max；否则 shrink-wrap（以前只有"有 flex 才填满"） |
| `parent_data.fit`（`'tight'`/`'loose'`） | `Expanded` = tight、`Flexible` = loose，对应文档 Example 25/26/27 |
| 主轴无界 + 非零 flex → 抛错 | 对应文档 "you can't use Expanded when the flex box is inside another flex box or a scrollable" |
| `cross_alignment` 默认 `'center'` | `Flex.crossAxisAlignment` 默认值是 center（以前是 start） |
| `distribute_space` 补齐 | `spaceBetween / spaceAround / spaceEvenly`，`cross` 支持 `stretch` |
| spacing 计入累计主轴 | 与 Flutter 把 `spacing * (n-1)` 计入 `accumulatedSize` 一致 |

### 1.7 `render/stack.lua`

默认 `alignment` 改为 **top-left**（`AlignmentDirectional.topStart`），
不再默认居中。

### 1.8 新增渲染盒子与组件（文档示例直接用到）

| 新增 | 渲染对象 | 对应文档示例 |
| --- | --- | --- |
| `ConstrainedBox` | `RenderConstrainedBox` | 9–12 |
| `LimitedBox` | `RenderLimitedBox` | 17 |
| `UnconstrainedBox` | `RenderUnconstrainedBox` | 13–17 |
| `OverflowBox` | `RenderOverflowBox` | 15 |
| `FittedBox` | `RenderFittedBox` | 18–20、22 |
| `SizedBox.expand / shrink / from_size` | 复用 `RenderSizedBox` | 29 |

### 1.9 `widget/widgets/layout.lua` —— Widget 层

- `Flexible` 增加 `fit`（默认 `loose`），`Expanded` 传 `tight`，`Spacer` =
  `Expanded(SizedBox.shrink())`。
- `Flexible:apply_parent_data` 在 `flex`/`fit` 变化时对父渲染对象
  `mark_needs_layout()`——否则运行时改 `flex:` 不会重排。
- `Flex` 增加 `main_axis_size`，`cross_alignment` 默认 `center`。
- `Stack` 默认 `alignment` 改为左上。
- `Container` 增加 `constraints` 参数，`width/height` 折叠成
  `constraints.tighten(...) ?? tightFor(...)`；`build()` 按 Flutter 顺序重写：
  无子走 `LimitedBox(0,0) + ConstrainedBox(expand())`，有子时 `Align` 在
  `Padding` **之前**。

### 1.10 `host/mpv_app.lua` —— 根约束

`set_viewport(Constraints.tight(w, h))`：Flutter 的 `RenderView` 给根**紧约束**
（"the screen forces the Container to be exactly the same size"），之前是
`loose`，导致文档 Example 2 不成立。

### 1.11 `backends/ass_canvas.lua` —— 文本缩放

画布带缩放时（`FittedBox`），文本额外输出 `\fscx`/`\fcy`；几何坐标本就被
`_apply` 缩放，无需额外处理。未缩放时输出保持不变。

---

## 2. 对标测试

`test/test_constraints_examples.lua` 在固定 **400×670** 屏幕上重建文档的 29 个
示例（输入见 `test/constraints_examples.lua`），把整段原始 `ass-events` 与预期
字符串逐字比较。ASS 绘制用 8× 子像素，所以断言里的坐标是 `px * 8`。

| # | 文档片段 | 固化下来的行为 |
| --- | --- | --- |
| 1 | `Container(color: red)` | 根紧约束 → 填满 400×670 |
| 2 | `Container(width/height: 100)` | 被屏幕撑满（不是 100×100） |
| 3 | `Center(Container(100×100))` | 居中：x 150..250, y 285..385 |
| 4 | `Align(bottomRight, Container(100×100))` | 右下：x 300..400, y 570..670 |
| 5 | `Container(width/height: ∞)` | 撑满 |
| 6 | `Center(Container(color: red))` | 无子 Container 撑满 bounded 父 |
| 7/8 | 无子/带 padding 的嵌套 Container | 红在外、绿在内；padding 计入尺寸 |
| 9 | 根下 `ConstrainedBox(70..150, child 10×10)` | 父紧约束压制附加约束 → 撑满 |
| 10 | `Center(ConstrainedBox(70..150, child 10×10))` | 取 MIN → 70×70，居中 |
| 11 | 同上，child 1000×1000 | 取 MAX → 150×150 |
| 12 | 同上，child 100×100 | 落在区间内 → 100×100 |
| 13 | `UnconstrainedBox(Container(20×50))` | 盒填父，子保持 20×50 居中 |
| 14 | `UnconstrainedBox(Container(4000×50))` | 子 4000 溢出（x 从 −1800 起） |
| 15 | `OverflowBox(0..∞, child 4000×50)` | 盒 400×670，子居中溢出，无告警 |
| 16 | `UnconstrainedBox(Container(width: ∞))` | **抛错**：infinite width |
| 17 | `UnconstrainedBox(LimitedBox(100, child ∞×100))` | 仅在无界时生效 → 100×100 |
| 18 | `FittedBox(Text(30))` | 撑满宽度，`\fscx148` |
| 19 | `Center(FittedBox(Text(30)))` | 收缩到文本本身，不缩放 |
| 20 | `Center(FittedBox(长文本))` | 受限缩小，`\fscx28` |
| 21 | `Center(Text(长文本))` | 按父宽软换行成 4 行 |
| 22 | `FittedBox(Container(width: ∞, h 20))` | **抛错**：infinite width |
| 23 | `Row(两个 Container(Text))` | 子节点主轴无界，不换行；剩余空间留白 |
| 24 | `Row(长文本 + Goodbye!)` | 子节点按自然宽度排列并溢出 |
| 25 | `Row(Expanded(Center(Container)), Container)` | Expanded 得 280，内部 210 居中 |
| 26 | `Row(Expanded, Expanded)` | 各 200（tight，忽略子偏好宽度） |
| 27 | `Row(Flexible, Flexible)` | 各分配 200 但 loose，红收缩到 195 |
| 28 | `Scaffold(Container(blue, Column))` | Scaffold 松约束 → 蓝仅 64 宽 |
| 29 | `Scaffold(SizedBox.expand(...))` | 强制撑满 → 蓝 400 宽 |

额外结构性断言：28/29 的差异、26/27 的 tight/loose 差异。

---

## 3. 与 Flutter 仍存的已知差异（有意保留）

- **baseline 对齐**：`cross_alignment = 'baseline'` 目前退化为 `start`，没有
  真实基线计算（文本层未暴露 baseline）。
- **BoxFit**：`FittedBox` 实现 `contain / cover / fill / fit_width /
  fit_height / none / scale_down`，但 `RenderFittedBox` 未做裁剪层，溢出时
  只做缩放不裁剪。
- **intrinsic 尺寸**：没有 `IntrinsicWidth/Height`、`AspectRatio`、
  `FractionallySizedBox`；Flutter 的 `RenderFlex` 在 intrinsic 阶段的行为未移植。
- **布局性能**：`mark_needs_layout` 仍一路上传到根，没有 relayout/repaint
  boundary；`parentUsesSize` 也没有断言（DESIGN_PATH 已记录）。
- **方向**：只实现 LTR + top-to-bottom，未做 RTL / `VerticalDirection.up`
  的轴向翻转（`flipMainAxis` / `flipCrossAxis` 恒为 false）。
- **debug 溢出指示**：Flex / UnconstrainedBox 不画黄黑条纹，也不打印告警；
  Example 14/15 通过坐标断言溢出。
