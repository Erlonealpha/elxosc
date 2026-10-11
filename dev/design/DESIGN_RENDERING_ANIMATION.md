# 渲染变换、动画与文本契约

本文记录 ASS 后端约束下的重构决策。第零阶段、阶段 1、阶段 2 和阶段 3 已完成并通过
验证；阶段 4–5 的类名和接口仍是规划，不代表已有能力。阶段编号只属于本文，不沿用历史文档的
Phase 编号。

## 1. 分层与宿主限制

- 布局遵循约束向下、尺寸向上、父节点决定子位置。布局使用逻辑尺寸，不读取或
  反向解析最终 ASS event 的像素边界。
- 渲染层表达绘制位置、逻辑变换和输入坐标；后端负责将它们转换成绘制命令。
- Layout Align 对齐子节点的逻辑盒，paint anchor 对齐绘制内容的参考点。
  ASS 的 `\an` 数字只出现在后端，不进入通用 `TextStyle`。
- **mpv `osd-overlay` 的 `ass-events` 不提供可用于这些动画的 PTS 时间推进。
  `\move`、`\t` 等依赖 PTS 的标签不能用于本框架动画，也不作为未来优化路径。**
  动画由框架 `FrameClock` 驱动，每帧输出静态 `\pos`、缩放和颜色等参数；暂停
  播放或没有媒体时，UI 动画仍由该时钟推进。
- ASS 不提供任意子树的离屏 surface。逐 event alpha 不等价于离屏合成后的
  group opacity；将来引入透明度 API 时必须说明重叠内容的合成差异。

## 2. 阶段 0：文本契约收敛

### 2.1 TextStyle

统一使用单 options 表：

```lua
local style = TextStyle({
    font_size = 16.5,
    color = Color.rgba(0xFFFFFFFF),
    bold = false,
    wrap = false,
})
local larger = style:copy_with({ font_size = 20 })
```

`TextStyle()` 使用默认值；旧的 `TextStyle(size, options)` 调用迁移到新接口。
构造和 `copy_with()` 均不修改调用方的 options。只有 `nil` 表示使用默认值或
继承原值，`false` 和 `0` 必须保留。

| 字段 | 契约 |
| --- | --- |
| `font_size` | 非负有限逻辑像素，可为小数；默认 16 |
| `color` | `Color` 值；默认不透明白，透明度由 `Color.a` 表达 |
| `font_family` | 可选字体族名，具体字体解析由宿主/后端完成 |
| `bold` / `italic` | 布尔值；默认 false |
| `letter_spacing` | 有限逻辑像素，允许负值；默认 0 |
| `line_height` | 非负有限行距倍数；默认 1.2，和字号的乘积须有限 |
| `align` | `left` / `center` / `right`；默认 left；不等于外部定位锚点 |
| `wrap` | 布尔值；默认 true |
| `extra` | 可选带非空字符串 `type` 的后端扩展表 |

上述字段参与复制与相等比较。`extra` 是供显式支持它的自定义后端使用的不透明
数据，按不可变对象约定共享、按表身份比较；修改扩展配置应提供新表。
内置 ASS 后端尚不消费 `extra`，不会把其中的 scale/rotate 当作布局尺寸因子。
`align` 当前携带对齐意图；ASS 多行的逐行对齐尚待锚点阶段配套实现。

未完成的样式实验移入后续设计，不作为当前公共选项静默接收：

| 实验字段 | 后续语义 |
| --- | --- |
| `anchor_point` | 改为独立、后端无关的绘制锚点与目标位置 |
| `border` / `border_color` | 明确描边宽度/颜色；ASS 描边用 `\bord`，`\b` 表示粗体/字重 |
| `shadow` / `shadow_color` | 明确偏移、颜色和视觉溢出范围 |
| `alpha` | 通用透明度优先使用 `Color.a`，避免第二个相互冲突的 alpha 来源 |
| `deleteline` / `underline` | 定义文本装饰及度量影响后实现 |
| `AssTextStyleExtra` 草案 | `shadow_x/y`、`border_x/y`、`scale_x/y`、`rotate`、`rotate_anchor`；须分别确定绘制与度量语义 |

### 2.2 TextLayout 与 Paragraph

```text
line_width(line, style)  后端必须实现
line_height(style)      默认 font_size * line_height，后端可覆盖
layout(text, style, max_width)  通用硬换行、按词折行与段落尺寸计算
```

`line_height(style)` 表示整个段落统一的逻辑行距，不接收整段文本冒充单行。
后端返回非有限或负行距时应明确报错。将来若需要逐行基线、fallback 字体行高，
需扩展为实际的行度量模型，而非通过 paint scale 修改此返回值。

- `Paragraph.size` 是换行后的自然逻辑尺寸；空文本为零尺寸。
- `Paragraph.lines` 是框架确定的行列表。
- `Paragraph.line_height` 是统一逻辑行距。
- `RenderText.size` 是遵守父约束的布局盒，可以不同于 `Paragraph.size`。
- baseline、ascent/descent、ink bounds 和 paint origin 是后续可选指标；缺失时
  不以估算值冒充精确像素边界。

ASS 当前按字符类别估算宽度。图标连字、字形 bearing、字体替换、hinting 等
都可能产生误差。一个多行 ASS event 使用 `\N`，实际行距由 libass 字体度量
决定；逻辑 `line_height` 暂不代表已精确控制这些实际基线。未来可考虑逐行
event 和相应基线/锚点协议。

### 2.3 绘制定位

`Canvas:draw_text(paragraph, position, text_paint?)` 的 `position` 是绘制 anchor 的
逻辑目标点，省略 `text_paint` 时保持左上角/零偏移兼容行为。`TextPaint` 独立携带
后端无关的九宫格 anchor 和有限 `Offset` 视觉偏移；它们不进入 `TextStyle`、逻辑
度量、布局约束或命中测试。`RenderText` 用受约束的 `self.size` 计算目标点，不能
使用 `Paragraph.size` 反向改变布局盒。ASS 后端再将 `position + TextPaint.offset`
一次性变换并映射为 `\an7/8/9`、`\an4/5/6`、`\an1/2/3`。

`\an5` 是 libass 的排版锚点，不保证 glyph 墨迹或视觉重心绝对居中；Icon 的
`optical_offset` 是明确的绘制层修正，仍不影响 nominal box。

## 3. 阶段 1：平移与动画基础（已实现）

### 3.1 二维变换基础

`foundation/transform.lua` 已增加二维仿射矩阵值类型 `Matrix2D`，约定：

```text
x' = a*x + c*y + tx
y' = b*x + d*y + ty
```

提供 identity、translation、scale、矩阵乘法、点/矩形变换和 inverse；奇异矩阵的
`inverse()` 返回 nil。
采用列向量及 `CTM = CTM * local_transform` 的组合顺序，并用顺序测试固化；
奇异矩阵显式返回不可逆结果。数学类型能表达某矩阵，不代表 ASS 已支持它。

`render/offset_box.lua` 和 `widget/widgets/offset_box.lua` 提供纯绘制平移：子节点布局和
对父节点报告的尺寸不因平移改变；更新偏移只标记 paint dirty。输入需要反向
映射，覆盖 `hit_test`、`pointer_path`、capture 和嵌套偏移。必须明确祖先命中
边界/裁剪对移出布局盒内容的影响，不承诺“画得到就一定能点到”。

`RenderOffsetBox` 的 `bind_offset_animation(controller, tween)` 已把 controller
监听接到 paint-only 属性；脱离 owner 时自动解除监听。输入路径反向减去 offset，
但仍受 OffsetBox 自身布局盒约束，绘制到盒外的部分不会自动成为可点击区域。

### 3.2 动画核心

`animation/` 已提供 AnimationController、Tween、Curve 和监听契约，复用现有
Ticker/Scheduler。顺序是：

```text
FrameClock -> transient 动画采样 -> build -> layout -> paint -> present
```

- Controller 管理 forward/reverse/repeat_animation/stop、当前值和状态；采样基于自己的
  起始时间，避免把调度器长时间空闲后的 dt 计入刚启动的动画。
- Tween 映射进度到 number、Offset 等值，Curve 处理插值进度。
- RenderObject 的动画监听更新运行时属性；纯绘制属性只触发 paint dirty。
- State 可通过 `create_ticker()` / `create_animation_controller()` 创建由 State
  所有的资源；Element 卸载时在用户 `dispose()` 后统一释放。渲染节点脱离树时解绑
  OffsetBox 的监听。
- 动画结束后停止持续请求帧；同帧多个更新合并为一次提交。
- 必要的 Widget rebuild 仍可用 `set_state`，不要求简单平移逐帧重建子树。

阶段验收已覆盖假时钟、重启/取消/销毁、监听替换、paint-only 不重排、平移后的
输入坐标、RecordCanvas 与 ASS 静态输出、State 生命周期、模块加载和聚合 identity。

实现约束：动画只更新框架值并让下一帧重新绘制，绝不生成 `\move`、`\t` 或其他
依赖 PTS 的 ASS 标签。`Ticker` 在每次 start 时重置自己的时间基准，避免调度器
长期空闲后的时间差跳过新动画的首帧。

## 4. 阶段 2：锚点与图标（已实现）

`foundation/anchor.lua` 提供九个后端无关的 anchor 名称及盒内 fraction；
`painting/text_paint.lua` 提供默认左上角/零偏移的 `TextPaint` 值对象、复制和
边界校验。Layout Align 仍负责逻辑盒位置，文本绘制 API 另外接收通用九宫格 anchor
和锚点目标坐标；ASS 后端映射为 `\an7/8/9`、`\an4/5/6`、`\an1/2/3`。不得简单
向整棵子树下发同一个 ASS 锚点：几何图形与复合节点有自己的布局盒。

`Text` 的 anchor/视觉偏移更新只触发 paint dirty；文本内容、样式或测量器变化仍
触发布局。Icon 使用明确的 nominal box（默认 24×24），在盒中心用中心锚点绘制，
避免用连字名称的字符数决定布局宽度；父约束仍可压缩该逻辑盒。Icon 的
`optical_offset` 只修正绘制目标，不改变布局尺寸。

内置字体可离线生成 glyph advance/ink bounds。可变字体必须固定轴值，且
glyph 名称、Unicode 映射和合法连字需分别验证；不能将 glyph 列表直接当作
全部可输入的连字。OSD/字体视觉行为需要真实宿主验证，字符串快照不足以证明。

## 5. 阶段 3：ASS 有限缩放（已实现）

ASS 后端现在使用 `Matrix2D` 组合 Canvas 的平移/正轴向缩放，统一处理路径控制点、
文本目标点、`\fscx/\fscy`、裁剪和保存/恢复。缩放值必须为有限正数；非有限、零值和
负值在 ASS backend 边界拒绝。当前经过验证的支持范围是：

| 变换 | 实施方向 |
| --- | --- |
| 平移 | 矩阵组合作用于各绘制原语和文本目标 |
| 正的等比/轴向缩放 | 路径坐标变换 + 文本 `\fscx/\fscy`，支持非等比正轴向缩放 |
| 旋转/倾斜 | 几何路径可预变换；混合文本、描边和裁剪需另外证明兼容性 |
| 任意仿射/透视 | 不以单个 ASS 标签近似成完整 Canvas 契约 |

矩阵作用于所有路径控制点；文本使用轴向缩放标签。嵌套 `clip_rect` 在最终逻辑
坐标中求交并随 `save/restore` 恢复。旋转、倾斜、负/零缩放没有被伪装成 ASS 支持，
仍由未实现的 Canvas 能力或 backend 边界拒绝。

FittedBox 是验证入口：父布局盒与子绘制缩放分开，使用源/目标矩形的显式映射；
`hit_test`/`pointer_path` 通过逆矩阵映射输入，`clip=true` 时裁剪到自身逻辑盒。
默认不裁剪以保持原有 overflow 行为；缩放精度保留在逻辑浮点值，ASS 数值标签和
路径坐标在最终输出时量化。

## 6. 阶段 4：影响布局的动画（规划）

统一 controller，不按后端再创建一套动画时间轴。目标属性决定失效类型：

| 变化 | 失效 |
| --- | --- |
| 平移、颜色、纯绘制 scale | paint |
| width/height、padding、约束、font size、逻辑行距 | layout + paint |
| Widget 子树结构 | build，再由变化决定 layout/paint |

`RenderTransform` 表达纯绘制变换；需要父节点预留变换后尺寸时，使用单独的
layout-transform 盒子。优先定义正轴向缩放约束映射，处理零值、负值和无界
约束；一般旋转的布局约束求解不直接套用轴向缩放算法。

以子逻辑矩形计算变换后 AABB：

```text
w' = abs(a)*w + abs(c)*h
h' = abs(b)*w + abs(d)*h
```

位置仍需变换四角取 min/max；公式给出的是逻辑盒包围尺寸，不包含未知文字
ink、阴影/描边溢出，也不提供通用父约束逆解。动画测量基于这些已声明的逻辑
尺寸，避免逐帧测量 libass 或产生 layout -> paint -> layout 的反馈循环。

## 7. 阶段 5：性能与后端扩展（规划）

按实测热点推进事件/文本度量缓存、RepaintBoundary、布局边界、合批以及原生
绘制后端。精确字体度量需要声明来源和准确性；替换后端仍遵循相同逻辑坐标与
生命周期。PTS 标签不属于优化选项。

## 8. 第零阶段验收

- options-only API 和明确非法边界；构造/复制不写入调用者 options。
- 字号可覆盖，false/0 不丢失；扩展表身份参与相等比较。
- 默认行高与后端覆盖；空文本/硬换行/软换行的逻辑尺寸。
- Paragraph 自然尺寸与 RenderText 受约束尺寸分离。
- 左上角到 ASS 位置的映射、Button/Icon/Demo 的实际使用。
- 完整 Lua 套件（含 29 个约束示例）、EmmyLua 静态检查和真实宿主测试。

实施前已有记录：Lua 499 checks passed / 52 failures，主要由构造 API 和
新增的抽象行高方法触发。

### 第零阶段完成记录

已统一 TextStyle 构造/复制/值比较及仓库调用，提供可覆盖的默认逻辑行高，
恢复左上角绘制定位，并补齐输入边界、扩展数据、DSL identity 和尺寸分离回归。
原有 29 个约束示例的预期 ASS 输出全部通过。

真实宿主验证发现夹具将 `main.lua` 作为单文件加载，导致目录包搜索路径缺失和
`mp.get_script_directory()` 返回 nil。夹具已改用目录包加载，并设置
`--load-scripts=no`，每次只启动指定的测试入口；进程清理仍使用原有所有权机制。

2026-10-11 实际执行（WSL 调用 Windows 工具）：

| 命令 | 最终结果 |
| --- | --- |
| `/mnt/e/lua/local/LuaJIT/bin/luajit.exe test/run.lua` | **836 checks passed** |
| `emmylua_check.exe .` | **No issues found** |
| `/mnt/c/Windows/system32/cmd.exe /d /c "uv run --group test python -m pytest -q test/real_host"` | **5 passed**，真实 mpv.net |

本轮三个检查均已运行，没有跳过项。真实宿主测试覆盖入口、IPC 和合成指针事件，
不代表已验证精确字体像素边界或图标视觉居中。

### 阶段 1 完成记录

已实现 Matrix2D、OffsetBox、输入反向映射、Ticker 独立时间基准、Curve/Tween、
AnimationController，以及 State 所有资源的卸载释放。OffsetBox 的绘制平移不
改变布局尺寸，只触发 paint dirty；ASS 仍使用静态逐帧输出。

2026-10-11 阶段 1 验证：

| 命令 | 最终结果 |
| --- | --- |
| `/mnt/e/lua/local/LuaJIT/bin/luajit.exe test/run.lua` | **904 checks passed** |
| `emmylua_check.exe .` | **No issues found** |
| `/mnt/c/Windows/system32/cmd.exe /d /c "uv run --group test python -m pytest -q test/real_host"` | **5 passed**，真实 mpv.net |

真实宿主夹具已将 `animation/` 纳入隔离 staging；入口 smoke test 等待 Demo
State 注册后再发送消息，避免异步脚本启动竞态。

### 阶段 2 完成记录

已实现后端无关九宫格 anchor、`TextPaint` 的视觉偏移、ASS `\an` 映射和
`RecordCanvas` 的第三绘制参数。`RenderText` 以受约束的 RenderObject 盒计算 anchor
目标；Icon 使用固定 nominal square box、中心绘制和可选 `optical_offset`。补充了
TextPaint 非法边界、复制/相等、默认兼容、paint-only 更新、长连字图标尺寸、ASS
九点映射以及真实 libass bounds 回归。宿主回归只证明事件被真实 libass 接收并产生
非空 bounds，不把它当作精确字体 ink bounds 或光学居中证明。

Demo 现在可直接展示这些成果：九宫格文本 anchor、固定 Icon box/optical offset、
TextStyle 文本以及由 FrameClock 驱动、逐帧输出静态 ASS 的 OffsetBox 平移动画。

2026-10-12 实际执行：

| 命令 | 最终结果 |
| --- | --- |
| `/mnt/e/lua/local/LuaJIT/bin/luajit.exe test/run.lua` | **956 checks passed** |
| `emmylua_check.exe .` | **No issues found** |
| `/mnt/c/Windows/system32/cmd.exe /d /c "uv run --group test python -m pytest -q test/real_host"` | **6 passed**，真实 mpv.net |

### 阶段 3 完成记录

已将 ASS Canvas 的局部 `_sx/_sy/_tx/_ty` 替换为 `Matrix2D` 组合，统一平移、正轴向
缩放、文本 `\fscx/\fscy`、路径坐标和嵌套裁剪的变换顺序。FittedBox 现在保留显式
源/目标映射，支持可选自身盒裁剪，并用逆矩阵处理命中测试和 pointer path；不支持的
旋转、倾斜和非正缩放不会被静默近似。补充了变换顺序、轴向文字缩放、clip 求交、
FittedBox crop/input 和真实 libass scale bounds 回归。

2026-10-12 实际执行：

| 命令 | 最终结果 |
| --- | --- |
| `/mnt/e/lua/local/LuaJIT/bin/luajit.exe test/run.lua` | **978 checks passed** |
| `emmylua_check.exe .` | **No issues found** |
| `/mnt/c/Windows/system32/cmd.exe /d /c "uv run --group test python -m pytest -q test/real_host"` | **7 passed**，真实 mpv.net |
