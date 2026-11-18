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
- `Stack` 的 `Positioned` parent data 由父节点根据有限 root constraints 计算 child size 和
  offset；同一 offset 同时进入 paint、hit test 和 RegionSnapshot，不把 ASS absolute
  coordinates 暴露给 Widget。

`FittedBox` 使用源/目标盒映射；`TransformBox` 保留子节点原布局尺寸；
`LayoutScaleBox` 把正轴向缩放纳入约束逆映射和最终报告尺寸。三者的区别是公共
语义，不能通过一个通用 scale 属性模糊掉。

## RenderObject 和 dirty

RenderObject 实例跨帧存活。setter 必须在属性边界验证值并选择最小失效范围：

| 属性 | 失效 |
| --- | --- |
| 平移、视觉偏移、颜色、纯绘制 scale、clip、subtree opacity | paint |
| 宽高、padding、约束、字号、行距、布局 scale | layout + paint |
| Widget 子树结构 | build，再按结果 layout/paint |

动画控制器不决定 dirty 类别；目标 RenderObject 的 setter 决定。动画监听在节点
脱离 owner 时必须解除，替换 controller/tween 时必须移除旧监听。

## PipelineOwner 和 PaintingContext

`PipelineOwner` 是 RenderObject pipeline 的规范名称；当前单根实现由
`lib/src/render/pipeline_owner.lua` 重导出既有 `RenderOwner` class，两个入口保持相同 identity。
它负责 viewport、layout/paint dirty、`flush_layout()`、`flush_paint()` 和 visual update
通知；每个 attached WidgetTree 拥有自己的 PipelineOwner。通用命中路径、hover/capture
仍归此 owner，mpv input section 和失焦/隐藏/resize 等取消策略及 presenter 归 host。

RenderObject 的 paint 边界使用 `PaintingContext`：context 持有当前 Canvas，统一 child
paint、offset、clip 和 save/restore；现有 Canvas 入口仍可直接调用。它不是
Flutter Layer tree，不暴露 ASS `Layer`/`ReadOrder`，不改变布局或 hit testing。

内置变换节点也通过 `paint_child` 遍历；`with_save`/`clip_rect_and_paint` 在子绘制或
clip 抛错时仍 restore；`with_opacity` 使用同一 save/restore 边界应用 backend-neutral
子树 alpha，不改变布局、命中或 pointer regions。Record/ASS 等价、命中不变和异常后的
画布状态都有离线回归。

当前 frame 顺序为：transient/ticker → Widget build scopes → inactive finalize → layout
→ 局部prepare → input region snapshot → PaintingContext paint → presenter → post-frame callbacks。
RenderOwner.schedule_prepare按稳定callback合并、有序执行，cancel_prepare用于卸载清理。
layout即使无布局dirty也flush_prepare；准备不改父约束/尺寸，不触发整树layout。
flush_prepare处理入队时的队列快照，准备中再次入队留到下一次flush，失败保留首错并执行其余项。
当前每个 production owner scope 仍只支持一个 root 和一个 Canvas；Binding
composition 不因 attached owner scope 增加而复制。

## Canvas 和文本

`Canvas` 使用逻辑像素，负责 save/restore、平移、正轴向 scale、裁剪和图元绘制。
`TextStyle` 只表达样式意图（包括受控 blur/outline/shadow），`TextPaint` 负责九宫格 anchor 和视觉偏移；
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

### 有限多行文本

TextStyle.max_lines为nil或正整数，overflow为visible/clip/ellipsis（默认visible）。
TextLayout保留原文及每行UTF-8字节半开范围（1-based）、自然width、source/reason；
行范围不含硬换行。CR/LF/CRLF分行，tab展开4空格，连续/前后空白保留。
空source没有行，尾部硬换行保留空行；max_lines最多准备额外一行判断截断，完整source仍校验UTF-8。
Latin词边界优先、CJK有限断行、长词按支持的grapheme拆，单簇过宽保留overflow。
支持常见组合标记、variation selector、emoji modifier/ZWJ/RI及Hangul组合，非完整UAX规则。
NBSP不作为普通词边界，超长单元仍可逐簇拆；不承诺Indic/full bidi编辑等未覆盖组合。
max_lines限制结果行；ellipsis测全部支持的prefix+省略号整串，取最长实测可容纳prefix，
不能假定负字距/shaping宽度单调；窄于省略号显示空行。省略号不消耗原文字节。
TextStyle.copy_with的nil沿用现有字段，清除max_lines需fresh style。Paragraph复制行数组及metrics，
with_style只用于保留排版的paint样式替换；手动构造的旧Paragraph可省略metrics。
ASS多行按逻辑line_height输出逐行静态events，空行也保留推进；单行九anchor行为保持。
Paragraph顶部由paragraph高度及纵向anchor确定，各行middle anchor在(index-0.5)*line_height；
同一横向anchor对齐每行而非强制短行占满自然宽度。视觉offset与正scale照常作用。
clip/ellipsis只在受约束RenderText盒溢出时裁剪。paint消费最终行，不能重新测量/断行。

### 文本测量服务

`TextLayoutScope`提供树作用域的TextLayout及环境generation；Text的显式text_layout
优先于最近scope，模块default只用于无宿主资源的离线回退。环境替换沿Inherited依赖
重新布局，RenderObject继续复用；Tooltip同时失效旧paragraph。

ASS布局器通过注入measure_ass函数取得整行左右anchor的同侧坐标差分，返回与ASS
定位一致的自然跨度，不把image bbox宽高当成font advance/baseline。两差分的差不得
超过2逻辑px，测量模板无clip/effect且bounds位于实际OSD内部；越界、未知空白或不可靠
结果退估算。空串/字号0无需native，纯space/NBSP使用具体数量的marker差分。
测绘共用shape与escape编码，保留边界space，显式禁用ASS自动软换行；逻辑行高仍独立。

`AssTextLayout:measure_line`返回width/source/reason，source为native/estimate/empty；
line_width保留number接口。LRU按等价shape值缓存，默认512项、256KiB原文与key字节，
不含color/glow/align/line_height/约束。故障停止该环境的native请求，环境替换可恢复。
不同App拥有独立服务与cache；cache_stats提供统计副本，不改变布局结果。

ASS Canvas 将矩阵变换降低为静态事件：路径坐标经过平移/缩放，文本使用
`\fscx`/`\fscy`，裁剪在最终逻辑坐标中求交。只接受有限正缩放；旋转、倾斜、
零/负缩放和任意仿射布局不能静默近似。

ASS `osd-overlay` 的 `ass-events` 不提供本框架需要的 PTS 动画推进，因此禁止
生成 `\move`、`\t` 等标签。`AnimationController` 每帧更新框架值，下一帧重新输出
静态 `\pos`、缩放或颜色参数。这样 UI 动画不依赖媒体播放状态。

### 单 Canvas presentation

OverlayState 的 plan 通过同一个 RenderObject tree 的 Offstage/Stack 生效；host 不复制
Entry list 或再挂载内容。每个 dirty frame 只 reset/paint/submit 一次同一个 AssCanvas。
`ass-events` 的每个非空行是一条 Text event；mpv 的 `sub/osd_libass.c` 中
`update_external()` / `add_osd_ass_event()` 使用默认 Layer=0、递增 ReadOrder。后端保持
绘制调用顺序并拒绝一个 event 中的原始换行/NUL，不把 Dialogue header 或物理排序字段
暴露给 Widget。重叠颜色的真实宿主像素验证负责证明后写覆盖先写。

AssPresenter 缓存已成功提交的数据与分辨率；失败提交可以重试。隐藏/清空输出提交空 ASS，
保留同一 presenter；shutdown 幂等移除它，之后不可重新提交。空根完成 lib/src/layout/paint 后也
清除 dirty 状态，不能变成持续刷新的空帧。

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
不创建第二个 owner，也不进入 Slot contribution priority。`overlay.z` 只属于未来 host
presentation，不进入 Widget、Element、RenderObject 或 SlotSpec。未来 OverlayHost
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

播放器按钮的 hover glow 是同一位置的额外模糊字形绘制，使用 `RenderText` 的 paint-only
glow override；它不改变文字度量，也不映射为 ASS shadow 的 `\\be`。不可用按钮保留
正常视觉树以同步前景样式，但不声明 pointer handlers。播放器唤醒区在应用组合层按
Main 的实际 uniform scale 换算到 display space，通用 AutoHide 不读取播放器 scale。

当前没有逐字精确的 libass ink bounds、baseline/ascent 模型、Layer/cache boundary、
RepaintBoundary 或大列表虚拟化。新增能力必须先定义逻辑尺寸、绘制溢出和输入区域
的区别，再添加后端和真实宿主回归。

当前单 Canvas/静态 ASS presenter 没有可公开承诺
的 Flutter 同义 `RepaintBoundary` 或 `RelayoutBoundary`。paint isolation 和 relayout
pruning 必须先经过同环境 benchmark、逐事件输出等价和输入/布局回归，再进入独立的
render/backend 优化。动画控制器仍只提供时间和值，目标 RenderObject setter 决定
paint-only 或 layout + paint；`RenderLayoutScaleBox` 的 alignment 若改变 pointer mapping
必须同步 invalidates input snapshot。ModernX fade 使用 `RenderOpacity.hidden`：fade-out 完成
前保持 paint/input，完成时才移除 pointer regions；fade-in 先恢复 hidden=false，再由
AnimationController 逐帧更新 alpha。不得使用 `\move` 或 `\t` 替代 frame-clock 静态输出。

工具侧的静态子树 Record 重放不提供生产 boundary/cache API；真实输入坐标偏移
仍会使 region snapshot 失效。一般子树缓存需要独立定义样式、布局、文本、变换失效
和输入合同；输出等价与性能比较方法见 [tools/README.md](../../tools/README.md)。
