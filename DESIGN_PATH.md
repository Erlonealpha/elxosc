# elxosc 设计路径(AGENT 交接文档)

本文档的目的:**让任何 AGENT 在不读完全部代码的情况下,完全对齐当前实现与未来方向**。
它描述的是"事实状态",不是愿望;凡与本文件冲突的代码,以代码为准,并回头修正本文件。

配套文档:`DESIGN.md`(与 Flutter 的对照、扩展形态与坑的讨论)、
`test/README.md`(测试与静态检查怎么跑)。

---

## 0. 项目是什么

elxosc 是给 **mpv / mpv.net** 用的 UI 框架(同类参考 uosc)。核心目标:

1. 用 **Flutter 式的分层**组织 UI:几何/绘制 → 布局 → 渲染树 → Widget 层 → 调度。
2. **渲染层完全抽象**:上层只依赖契约,后端可以是 ASS(`ass-events`)、
   以后的 mpv.net 原生 surface,或离线录制(测试)。
3. 允许**其他脚本**在初始化阶段声明界面(见 §7 `bind` / define 协议)。

当前状态:**框架层已完成到 Widget/State/Element + 插槽/继承 + bind**,
并已落地**定义期协议核心**(沙箱 env、`define` 生命周期、`mod`/`import` 模块,
见 §7.3)。**mpv 平台层已初步搭建**:宿主切到 Widget 层(§9.1),定义期接线到
`script-message`(§9.3),`main.lua` 装配 scaffold + 定义窗口。

---

## 1. 不变量(改代码前必须遵守)

| # | 规则 | 为什么 / 怎么保证 |
| --- | --- | --- |
| I1 | **框架层不得 `require 'mp'`**。只有 `main.lua`、`elxlib_load.lua`、`host/*` 可以。 | mpv.net 后端要复用框架层。由 `test/test_layering.lua` 自动守护;被检查的目录是 `foundation/ painting/ text/ scheduler/ layout/ render/ widget/ backends/ libs/`。 |
| I2 | **框架层不得出现 `undefined-global` 之外的新诊断**。框架目录要求 0 条诊断。 | `emmylua_check.exe .` 必须输出 `No issues found`。 |
| I3 | 模块间 `require` 用**裸名**(`require 'foundation.geometry'`),不加 `elxosc.` 前缀。 | mpv 运行时脚本目录在搜索路径里;测试由 `test/support.lua` 设置;EmmyLua 以工作区根为解析根。 |
| I4 | **`require` 不能成环**。Lua 的 `require` 遇环直接报错。 | 约定:`widget/widget.lua` 只声明 Widget,Element 与 `create_element` 的绑定放在 `widget/element.lua` 底部(见 §6.5)。 |
| I5 | Widget 是**不可变描述**;**mount 之后不得再改 widget 树**。结构性变化只能通过重建(`set_state`)。 | `bind` 只在挂载前写入(§7)。 |
| I6 | 渲染层用**约束协议**单遍布局:约束向下、尺寸向上、父节点决定位置。 | `layout/constraints.lua` + `render/render_object.lua`。 |
| I7 | 每个改动必须**两道关卡都过**:`emmylua_check .` 0 诊断 + `luajit test/run.lua` 全绿。 | 见 §11。 |

---

## 2. 目录与模块地图

```
elxosc/
  main.lua                  mpv 入口(scaffold + Slot + 定义窗口 + demo widget)
  elxlib_load.lua           补 package.path(scripts + 脚本目录)并 require 'elxlib'
  DESIGN.md                 与 Flutter 的对照、扩展形态讨论
  DESIGN_PATH.md            本文件
  DESIGN_CONSTRAINTS.md     约束模型对齐 Flutter 的修复记录(+ 对标测试说明)
  dev/feat_example.lua      设计草图(不可运行,见 §7.4)
  dev/feat_example_meta/    LuaLS 用的 DSL meta 桩(on_event/on_prop/Container…)

  foundation/geometry.lua   Offset · Size · Rect · EdgeInsets(值语义)
  foundation/color.lua      Color(RGBA,0..1,后端无关)

  painting/canvas.lua       Canvas 抽象契约(渲染层的唯一边界)
  painting/paint.lua        Paint + Style/StrokeCap/StrokeJoin
  painting/path.lua         Path(5 种图元)+ Verb;形状在此降级

  text/text_style.lua       TextStyle + Align
  text/paragraph.lua        Paragraph(布局结果)
  text/text_layout.lua      TextLayout 契约 + 通用换行 + 环境默认测量器

  layout/constraints.lua    Constraints(min/max 四值)

  render/render_object.lua  RenderObject:布局/绘制/命中/指针/脏标记
  render/render_owner.lua   RenderOwner:viewport + 脏标记 + 指针路由
  render/padding.lua        RenderPadding
  render/align.lua          RenderAlign(PositionedBox)
  render/flex.lua           RenderFlex(Row/Column,支持 flex 权重)
  render/stack.lua          RenderStack
  render/sized_box.lua      RenderSizedBox(BoxConstraints.tightFor + enforce)
  render/constrained_box.lua RenderConstrainedBox / RenderLimitedBox
  render/overflow_box.lua   RenderUnconstrainedBox / RenderOverflowBox
  render/fitted_box.lua     RenderFittedBox(缩放适配)
  render/decorated_box.lua  Decoration + RenderDecoratedBox
  render/text.lua           RenderText(Paragraph 叶子)
  render/custom_paint.lua   RenderCustomPaint(回调绘制)
   render/gesture.lua        RenderGesture(click/tap/wheel/hover)

  scheduler/frame_clock.lua FrameClock 契约(now / request_frame)
  scheduler/scheduler.lua   Scheduler(transient → persistent → post-frame)
  scheduler/ticker.lua      Ticker(动画时间源)

  widget/widget.lua         Widget 层级 + can_update
  widget/element.lua        Element 层级 + widget↔element 绑定
  widget/state.lua          State(init_state/build/set_state/dispose)
  widget/key.lua            Key(值语义)
  widget/bind.lua           BindRegistry + bind + Slot
  widget/build_owner.lua    脏 element 队列
  widget/binding.lua        WidgetBinding(Widget 树 ⇄ RenderOwner)
  widget/init.lua           `require 'widget'` 聚合入口
   widget/widgets/layout.lua 兼容聚合入口
   widget/widgets/{padding,align,sized_box,decorated_box,flex,stack,
                   constraints,overflow,container}.lua
                             基础布局控件的独立实现
   widget/widgets/basic.lua 兼容聚合入口
   widget/widgets/{text,custom_paint,gesture_detector,button,
                   button_base,button_style,elevated_button,outlined_button,
                   text_button,icon_button}.lua
                             基础展示、事件和按钮控件

  libs/sandbox.lua          无状态原语:load_chunk 兼容 shim + new_env(受限 env)
  libs/modules.lua          ModuleRegistry:mods(数据)+ loaders(安装器)+ protect
  libs/define.lua           DefineSession:define 生命周期 + import/mod/bind 内建
  libs/dsl.lua              new_widget / new_state / builtins(DSL 面)

  backends/ass_canvas.lua   AssCanvas(Canvas → ass-events 文本)
  backends/ass_text_layout.lua AssTextLayout(估算式测量)
  backends/record.lua       RecordCanvas(记录绘制调用,测试用)

  host/mpv_app.lua          MpFrameClock + AssPresenter + App(WidgetBinding 帧循环)
  host/mpv_define.lua       MpDefine:define 消息 + mp 模块 + 定义窗口
  host/mpv_input.lua        MpInput(mouse-pos + 按键组)

  test/                     离线测试(裸 LuaJIT,不需要 mpv);host 层用 test/mp_stub.lua
```

---

## 3. 分层与依赖方向

```
foundation ──> painting ──> render ──> widget ──> host ──> main
     │              │          │           │
     └──> text ─────┘          └──> layout ┘
scheduler 被 render_owner / widget.binding / host 依赖
backends 依赖 painting/text 契约,被 host 使用
libs(sandbox/define)依赖 widget,被 host 使用
```

依赖只能自上而下;**`render` 不认识 `widget`,`widget` 不认识 `mp`**。
唯一的宿主边界是四个契约:`Canvas`、`TextLayout`、`FrameClock`、输入源(§8)。

---

## 4. 渲染层

### 4.1 约束协议(`layout/constraints.lua`)

- `Constraints(min_width, max_width, min_height, max_height)`,构造器默认 `0..inf`。
- 静态:`tight(w,h)`、`tight_size(size)`、`tight_for{width,height}`、`loose(w,h)`、
  `unbounded()`(即 Flutter 的默认 `BoxConstraints()`,0..inf)、`expand(w,h)`
  (**紧无穷**,Flutter 的 `BoxConstraints.expand`)。
- 实例:`constrain_width/height/size`、`has_bounded_width/height`、
  `has_infinite_width/height`、`has_tight_width/height`、`is_tight`、
  `is_normalized`、`is_satisfied_by(size)`、`biggest()`/`smallest()`、
  `enforce(other)`(取交集)、`tighten{width,height}`、`normalize()`、
  `deflate(insets)`、`loosen()`、
  `constrain_size_and_attempt_to_preserve_aspect_ratio(size)`;`__eq` 按四值比较。
- 术语与 Flutter 一致:bounded = `max < inf`;loose = `min == 0`;tight =
  `min == max`;expanding = 紧无穷;infinite = `min == inf`。
  完整对齐记录见 `DESIGN_CONSTRAINTS.md`。

### 4.2 RenderObject(`render/render_object.lua`)

布局:
- `layout(constraints)`:若 `not needs_layout and self.constraints == constraints` 直接返回;
  否则调 `__perform_layout(constraints)`,再把 `self.size` 夹进约束。
- `__perform_layout(constraints)`:子类在这里 `child:layout(...)` 并写 `self.size`;
  子位置写在 `child.parent_data.offset`。

绘制:
- `paint(canvas, offset)` → `__paint(canvas, offset)`(基类实现只是 `paint_children`)。
- `paint_children(canvas, offset)`:每个子节点用 `offset + child.parent_data.offset` 递归。
- 目前**没有 RepaintBoundary**,每个脏帧整树重绘;ASS 后端靠"输出未变则跳过"兜底。

命中与指针:
- `__hit_test_bounds(point)`:默认按 `size` 判断;`RenderGesture` 会加 `expand`。
- `hit_test(position)` → 最深命中节点(命中失败返回 `nil`)。
- `pointer_path(point)` → `{node, point}[]`,**最深优先**,每项 point 已换算到该节点局部坐标。
- `on_pointer(event, point, data)` 钩子;返回真值表示已处理(停止向上传播)。
- `wants_pointer(event)`:宿主据此决定要不要抢占鼠标按键(§9.2)。

子节点:
- `adopt_child` / `remove_child` / `children()` 常规操作。
- `set_children(list)`:整体替换并保序;**列表逐项相同则什么都不做**(重复 build 的关键优化)。
- `_set_owner(owner)` 递归传播 owner(即 `RenderOwner`)。

脏标记:
- `mark_needs_layout()` / `mark_needs_paint()` 会**一路上传到根**,根再通知 `owner`。
  Flutter 用 relayout/repaint boundary 截断,这里没有(已知性能差距)。

### 4.3 RenderOwner(`render/render_owner.lua`)

- `set_root(ro)` / `set_viewport(constraints)` / `layout()` / `paint(canvas)`。
- `layout()`:`_needs_layout` 或 `root.constraints ~= viewport` 时才真的布局。
- `on_dirty` 是宿主接帧时钟的钩子(宿主把它接到 `scheduler:schedule_frame()`)。
- 指针:`pointer_path` / `wants_pointer` / `dispatch_pointer(event, point, data)` /
  `clear_hover`。
- `move` **冒泡**:驱动 `enter`/`leave`(owner 记 `_hovered`)后依次下发 `move`。
- 其它事件(down/up/wheel)**在第一个返回真的节点处停止**。

第一阶段事件 API 约定：`RenderObject` 只提供命中路径和事件钩子，
`RenderOwner` 负责路径分发、hover 与按下状态，宿主只把 mpv 输入转换为
`down/up/wheel/move`。`RenderGesture` 暴露 `on_down`、`on_up`、`on_click`、
`on_move`、`on_enter`、`on_leave`、`on_wheel`；`on_click` 仅在同一命中目标
按下并释放时触发，移出后释放会取消。`Button` 是基于 `GestureDetector` 的
基础 Widget，使用 `on_click` 回调；禁用或无回调时不声明可交互区域。

### 4.4 Canvas 契约(`painting/canvas.lua`)

坐标是逻辑像素(OSD 像素);`save/restore/translate/scale/clip_rect` + 绘制方法:
`draw_rect` / `draw_rrect(rect, radius, paint)` / `draw_path` / `draw_line` /
`draw_text(paragraph, offset)` / `draw_image(image, rect)`。
基类实现一律 `raise(NotImplementedError)`,**避免后端漏实现时静默不画**。

### 4.5 帧管线(`scheduler/`)

- `FrameClock`(契约):`now()`、`request_frame()`;host 调 `_emit(time)` 触发
  `set_handler` 注册的处理器。
- `Scheduler`:`add_transient`(动画/ticker)→ `add_persistent`(build/layout/paint)
  → `add_post_frame`;`schedule_frame()` 会合并重复请求;只要还有 transient 存活就
  自动续帧。
- `Ticker`:注册为 transient,`start()`/`stop()`,`on_tick(dt)` 收到帧间隔。

---

## 5. Widget 层

### 5.1 三棵树的职责

| 层 | 可变性 | 职责 |
| --- | --- | --- |
| `Widget` | 不可变 | 描述(参数、key、id);`create_element()`、`build()`、`create_render_object()` 等钩子 |
| `Element` | 可变、跨帧存活 | 复用判定、持有 `State`、拥有 `RenderObject`、协调子节点 |
| `RenderObject` | 可变、跨帧存活 | 布局/绘制/命中 |

### 5.2 Widget 层级(`widget/widget.lua`)

```
Widget                      key, id, create_element, child_widgets, bind_target
├─ StatelessWidget          build(context)
├─ StatefulWidget           create_state()
├─ ProxyWidget              child
│  ├─ ParentDataWidget      apply_parent_data(render_object)   (Flexible/Expanded)
│  └─ InheritedWidget       update_should_notify(old_widget)   (Theme/MediaQuery 的底座)
└─ RenderObjectWidget
   ├─ LeafRenderObjectWidget           create_render_object / update_render_object
   ├─ SingleChildRenderObjectWidget    child
   └─ MultiChildRenderObjectWidget     children
```

- `can_update(old, new)` = `old.__class == new.__class and old.key == new.key`。
  **key 决定复用**;`id` 只用于 bind 定位,不参与复用。
- `child_widgets()` 供 `bind` 静态遍历;`bind_target()` 返回 `'child'` / `'children'` / `nil`。
  内置容器类都实现了;自定义 `StatelessWidget` 想当绑定目标需自行覆写。

### 5.3 Element 层级(`widget/element.lua`)

```
Element                       mount/unmount/update/rebuild/mark_dirty/update_child
├─ StatelessElement           child = build(context)
├─ StatefulElement            持有 State;mount 时 init_state;unmount 时 dispose
├─ ProxyElement               child = widget.child
│  ├─ ParentDataElement       额外 apply_parent_data
│  └─ InheritedElement        dependents 集合 + notify_dependents
└─ RenderObjectElement        render_object
   ├─ Leaf / SingleChild / MultiChildRenderObjectElement
```

关键语义(容易踩坑,务必按此实现新元素):

1. **子渲染对象从 element 树收集**:`RenderObjectElement:render_children()`
   映射各自子 element 的 `first_render_object()`,再 `set_children(...)`。
   因此复合 widget(Stateless/Stateful)夹在两个渲染节点之间不需要额外记录。
2. **`Element:update` 会立即重建子树**(等价 Flutter 的
   `ComponentElement.update` → `rebuild(force: true)`),所以父节点重建时子节点不会
   被重复重建(`BuildOwner` 里按 `dirty` 判定跳过)。
3. **`RenderObjectElement:update`** 只 `update_render_object()`;Single/Multi 子类
   在此基础上再 `rebuild()`。
4. **`Element:_sync_render_children_upwards()`**:复合元素 rebuild 结束后,向上找到
   最近的渲染节点并 `sync_render_children()`。**这是必需的** —— 否则深层复合 widget
   改变子树形状时,祖先的渲染子列表不会更新(历史上出过这个 bug)。
   放在 `rebuild` 末尾而**不是** `update_child` 里,因为后者执行时 `self.child` 还没赋值。
5. **widget ↔ element 绑定**写在 `element.lua` 底部(`StatelessWidget:create_element`
   等)。因为 Lua 的 `require` 不能成环,`widget/widget.lua` 不能引用 Element 类。
   副作用:任何入口都必须 `require 'widget.element'`(由 `widget/binding.lua` 完成)。

### 5.4 State(`widget/state.lua`)

- 生命周期:`init_state()`(mount 后)→ `build(context)` → `did_update_widget(old)`
  → `dispose()`(unmount 时)。
- `set_state(apply)`:`apply()` 同步执行,然后 `context:mark_dirty()`;
  下一次 `BuildOwner:rebuild_dirty()` 重建该子树。
- `is_mounted()` 判断是否仍在树上。

### 5.5 构建与重建(`widget/build_owner.lua`、`widget/binding.lua`)

- `BuildOwner:schedule_build_for(element)`:入脏队列(去重)+ 触发 `on_dirty`。
- `BuildOwner:rebuild_dirty()`:按 `depth` 升序重建;`dirty` 已被祖先清掉的跳过。
- `WidgetBinding(root_widget, render_owner, binds?)`:
  可选先 `binds:apply(root_widget)`,然后建树、挂载、把根渲染对象交给 `RenderOwner`。
- `WidgetBinding:flush_build()`:接入宿主时,在 persistent 帧回调里、`owner:layout()`
  之前调用(宿主已在 §9.1 接线)。
- `set_root_widget(widget)`:换根;`can_update` 成立时复用根 element。

### 5.6 组件库

- `widget/widgets/layout.lua`:Padding / Align / Center / SizedBox(含
  `expand/shrink/from_size`)/ DecoratedBox / ConstrainedBox / LimitedBox /
  UnconstrainedBox / OverflowBox / FittedBox / Flex / Row / Column / Stack /
  Flexible / Expanded / Spacer / **Container**。
  `Row`/`Column`/`Center`/`Expanded`/`Spacer` 是**普通函数**(返回 `Flex`/`Flexible`),
  复用判定只看返回 widget 的类。
  `Flexible` 带 `fit`(`loose`;`Expanded` 传 `tight`),`Flex` 带 `main_axis_size`。
  `Container` 是 `StatelessWidget`,`build` 按 Flutter 顺序组合:无子时
  `LimitedBox(0,0)+ConstrainedBox(expand())`,有子时 align→padding→decoration→
  constraints→margin;`width/height` 折叠进 `constraints`。它自己暴露
  `child_widgets()`/`bind_target()='child'`。
- `widget/widgets/basic.lua`:Text / CustomPaint / GestureDetector。
- 所有内置 widget 的 `__init` 都从 `options` 取 `key` 与 `id`。

---

## 6. 文本

- `TextStyle(font_size, options)`:color/font_family/bold/italic/letter_spacing/
  line_height/align/wrap;`line_height_px()`、`copy_with()`。
- `TextLayout`(契约):**只有 `line_width(line, style)` 是后端相关**;
  `layout(text, style, max_width)` 是通用实现(硬换行 + 贪心按词折行 + 段落尺寸),
  返回 `Paragraph{text, style, size, lines, line_height}`。
- **环境默认测量器**:`text_layout.set_default(layout)` / `get_default()`。
  宿主启动时注入 `AssTextLayout()`;`RenderText` 未显式给测量器时用它。
  这是"引擎替身",也是暂无 `InheritedWidget` 主题体系时的过渡方案。
- `AssTextLayout` 是**估算**:ASCII 按 0.5em、宽字符(CJK 等)按 1em,加字距。
  真实字宽表可参考 uosc `src/uosc/lib/text.lua`(未来升级点)。

---

## 7. `bind` 与 define 协议

### 7.1 目标(用户明确的设计意图)

- 在 **define 期**构建出供 App 使用的 Widget 树。
- **运行期不修改 Widget 树**。
- `bind` 的实质操作:**把指定 Widget 设为"目标节点"的子 Widget**。
- 目标节点用 `Widget.id` 命名;`bind` 在**挂载前**由注册表统一写入。
- 后续可扩展:更多 op、以及"有限度地改目标节点部分设置"。

### 7.2 现状(`widget/bind.lua`)

```lua
local binds = BindRegistry()
binds:add('title_bar', Text('hello'))                  -- 默认 op
binds:add('bar', Text('x'), { op = 'insert', position = 1 })
local binding = WidgetBinding(root_widget, render_owner, binds)   -- apply 在挂载前
-- 或显式： binds:apply(root_widget)
```

| 目标(`bind_target`) | 默认 op | 可用 op |
| --- | --- | --- |
| `'child'` | `replace` | `replace`、`replace_if_empty` |
| `'children'` | `append` | `append`、`insert`(+ `position`,1-based) |

- 目标不能接子节点 → `RuntimeError`;op 与目标种类不符 → `ValueError`。
- `Slot(id)` 是语法糖:一个带 `id`、无子节点的空节点;未绑定时**不产生任何渲染节点**。
- 遍历用 `Widget:child_widgets()`,所以 **`id` 必须出现在能静态遍历的声明式 widget
  树里**;藏在 `State:build()` 内部、define 期看不见的节点不能作为绑定目标。
- 绑定写入后再遍历,所以 **bind 可以命中另一个 bind 写进去的 widget**(id 传递)。
- 挂载后再 `add` 不会影响已挂载的树(测试里明确断言了这一行为)。

### 7.3 现状(`libs/sandbox.lua` + `libs/modules.lua` + `libs/define.lua`)

来自其他脚本的定义以**代码字符串**形式送达:

```
define_start
define(scope_id, lua_source) ...    -- 可多条,同一 scope 累加
define_end
```

框架在自己的 Lua State 里用**受限 env** 执行这些源码。协议与宿主解耦:
`DefineSession` 只暴露 `define_start()` / `define(scope_id, code)` /
`define_end()` 三个方法,**消息名 → 方法的映射在宿主**(mpv 侧是
`host/mpv_define.lua:listen()` 注册的三个 `script-message-to elxosc` 处理器)。

三层,每层只做一件事(早期版本把三者揉进一个 `DefineSession`,已按
`dev/feat_example.lua` 拆开):

**`libs/sandbox.lua` —— 无状态原语,没有沙箱对象**

- `load_chunk(code, chunkname, env)`:**先 `load(code, name, 't', env)`,再在
  `setfenv` 存在时套一层**。LuaJIT 是 5.1:未开 `LUA52COMPAT` 时第 4 个参数
  会被静默忽略,只靠 `load` 会得到"沙箱失效但不报错"的最坏结果;反过来只走
  `loadstring` 又在 5.2+ 上不存在。两条路都走,才在两个运行时上都成立。
- `new_env(api, protected_names, label)`:返回一张**普通表**,metatable 的
  `__index` 指向 `api`、`__newindex` 经守卫后 `rawset`。因此它同时是"环境"和
  该 scope 的"模块级变量":宿主读 `env[k]` 拿到 chunk 写的东西,chunk 读未定义
  的名字落到 `api`。标准库全局(`string`/`_G`/...)一律不可见。
- 没有 Sandbox/Scope 类、没有会话引用 —— 谁持有 env、何时运行 chunk 都不归它管。
  (早期版本有一个 `Sandbox`/`Scope` 对象对,把 env、`import`、`mod`、事件订阅
  全揽在身上;已按上面拆开。)

**`libs/modules.lua` —— 模块注册表,只认普通表**

- `mods`(数据模块)与 `loaders`(安装器)是**两张独立的表**,正是
  `dev/feat_example.lua` 里 `mods` / `mods_loader` 的形状:
  - `add(name, data)` / `get` / `has` / `protect(name)`(禁止 `mod` 覆盖);
  - `add_loader(name, fn)`,`fn(env, scope_id)`;
  - `publish(name, data)` 是 `mod` 内建走的入口(受 `protect` 约束);
  - `import_into(name, env, scope_id)`:**先摊平数据模块,再跑 loader**。
- 它不认识 `DefineSession`、不认识 widget,只接收 `env` 与 scope id。这是
  **跨 scope / 跨脚本共享代码的唯一通道**(mpv 每个脚本一个 Lua State,函数
  无法直接传递)。

**`libs/define.lua` —— 协议本身,刻意做薄**

只持有三样东西:阶段机 + 消息路由、各 scope 的 env(`env_for(scope_id)` 首次
创建、之后复用)、以及需要"当前 scope"的三个内建。

- `DefineSession({ builtins, modules, binds, protected_names })`:
  - `builtins` 是**每个 scope 都能直接读**的名字(widget 构造器、`print`……),
    构造时并入基 env;
  - `import` / `require`(别名)/ `mod` / `bind` 由框架提供,`bind` 写共享的
    `BindRegistry`(§7.2),`mod(name[, data])` 缺省发布当前 env;
  - `define_start()` / `define(scope_id, code)` / `define_end()` / `handle_message`;
    执行期间用 `current_define` / `current_env` 记录当前 scope(与草图一致);
  - `on_error(scope_id, err)` 可选:设了就不抛,交给宿主决定(超时/日志)。
- **框架不内置任何宿主服务**。事件服务不在框架里:`on_prop` 是 `mp` 模块的
  **数据**,`on_message` 由 `mp` 模块的 **loader** 安装到 env —— 草图里的
  `mods.mp` / `mods_loader.mp` 正是这个意思。谁注册、谁解绑由宿主模块自己负责。

与早期草图(`dev/feat_example.lua`)的对应与差异:

1. `__newindex` 用 `rawset`(草图的 `obj[k]=v` 会栈溢出)。
2. `load` 兼容 shim 见上;不依赖 `loadstring`。
3. `mods` / `loaders` 分表,loader 在数据复制**之后**运行,签名 `(env, scope_id)`。
4. `builtins` 并入基 env,`import` 只摊平被导入模块(不再把模块表绑到同名变量)。
5. `protected_mods` → `ModuleRegistry:protect(name)`。

**宿主侧接线见 §9.3**(`host/mpv_define.lua`):`script-message` → session、
`mp` 模块(数据 + loader)、`builtins`(来自 `libs/dsl.lua`)、定义窗口与超时兜底。
仍未做:env API 的版本化;`on_prop` 的订阅在 scope 销毁时解绑(当前归宿主模块
自行负责,见 §12)。

### 7.4 与 `dev/feat_example.lua` 的关系

`dev/feat_example.lua` 是**早期设计草图**(含占位 `error('...')`),不是可运行
代码,已用文件级 `---@diagnostic disable` 标注。§7.3 是它的正式实现,草图仅作
历史参考保留。

---

## 8. 后端

### 8.1 ASS(`backends/ass_canvas.lua`)

约定(对着 mpv 自己的 `sub/osd_libass.c` / `player/lua/assdraw.lua` / uosc
`lib/ass.lua` 核实过):

- 事件前缀 `{\pos(0,0)\rDefault\an7\blur0 ...}`,随后 `{\p<subpixel>}` + **绝对坐标**,
  末尾 `{\p0}`。`\rDefault` 用来中和 mpv 施加的 `OSD` 样式。
- 颜色 `\1c&HBBGGRR&`(**BGR**),透明度 `\1a&HAA&` 且 `AA = 255 - alpha`
  (00 = 不透明)。`M.ass_rgb` / `M.ass_alpha` 是唯一转换入口。
- 子像素:`subpixel` 默认 **4**(即 `\p4`,坐标 ×8,与 assdraw 默认一致)。
- `draw_line` 会降级成**填充四边形**(width = `stroke_width`);
  `style='stroke'` 用 `\bord<w>\3c...\1a&HFF` 表达描边。
- `\p=0` 表示关闭绘制;`draw_image` 未实现(基类抛 `NotImplementedError`)。
- 每行 `data` 就是 `osd-overlay` 的 `ass-events` 的一个 `Dialogue` 的 `Text` 部分;
  `AssCanvas:text()` 用 `\n` 拼接。

### 8.2 Record(`backends/record.lua`)

`RecordCanvas` 记录 `{name=..., n=..., ...}` 数组;`names()` / `count(name)` / `reset()`
用于断言。它是"离线快照测试"的基础,**不依赖 mpv**。

---

## 9. 宿主层(mpv)

### 9.1 `host/mpv_app.lua`(现状)

- `MpFrameClock`:基于 `mp.add_timeout`,`delay` 由 `estimated-display-fps` /
  `display-fps` 决定,并用"距上帧时间"做**限速**(uosc 的 `render_delay` 思路)。
- `AssPresenter`:持有 `mp.create_osd_overlay('ass-events')`,`z = 2000`;
  `present(canvas, w, h)` 在 `data`/`res_x`/`res_y` 未变时**直接跳过更新**。
- `App(root_widget, options)`:**已切到 Widget 层**。`_update_display()` 用
  `mp.get_osd_size()` 设 `Constraints.loose(w,h)` 作为 viewport;构造时建
  `WidgetBinding(root_widget, owner, options.binds)` 并注入
  `text_layout.set_default(AssTextLayout())`;帧回调是
  `binding:flush_build(); owner:layout(); canvas:reset(); owner:paint(canvas);
  presenter:present(...)`。
- `M.start(build, options)`:`build()` **返回 Widget**;`App:set_root_widget(widget)`
  换根(定义窗口封版后用)。
- `App:request_frame()` 仍然存在(手动触发一帧,输入层用)。

### 9.2 `host/mpv_input.lua`(现状)

- 指针来自 `mouse-pos`(坐标 **+0.5** 取像素中心);`hover=false` 时
  `owner:clear_hover()`。
- 鼠标键/滚轮通过**具名 key binding 组** `elxosc_mouse` 拦截;
  **创建时必须带第三个参数 `'force'`**(否则该段不会被 mpv 视作可启用的鼠标绑定组,
  即使之后 `enable_key_bindings` 也不生效 —— 已实测;uosc 同样传 `force`)。
- 只有光标位于**可交互节点**(`owner:wants_pointer('down'|'wheel', point)`)时才
  `mp.enable_key_bindings('elxosc_mouse', 'allow-vo-dragging+allow-hide-cursor')`,
  否则 `disable`,以便普通点击仍归 mpv。
- `_dispatch(event, data)`:`down` 前先刷新位置,再 `owner:dispatch_pointer(...)`,
  然后请求一帧。
- 依赖 `main.lua` 定义的全局 `debug_msgf`(已知瑕疵,见 §12)。

### 9.3 `host/mpv_define.lua`(定义期宿主,现状)

框架的 `DefineSession` 只认 `define_start` / `define` / `define_end` 三个消息,
不知道 mpv。这个模块补上它**有意不做**的三件事:

1. **传输**:`mp.register_script_message` 收 `script-message-to elxosc ...`,
   按协议直接调用 session;`define` 在没有 `define_start` 时被忽略并告警。
2. **`mp` 模块**:`mods['mp']` 是数据(`get_prop` / `set_prop` / `get_time` /
   `command` / `log` / `on_prop`),loader 把**按 scope id** 的 `on_message` 与
   `emit` 装进 env;`protect('mp')` 防止脚本用 `mod` 顶掉。`on_prop` 归数据、
   `on_message` 归 loader —— 与 §7.3 的分工一致。
3. **窗口策略**:`listen()` 非阻塞接线;`wait(wait_start, all_timeout)` 是
   `dev/feat_example.lua` 的 `wait_define`(墙钟 `mp.wait_event` 泵事件,超时兜底);
   `close()` 停止接受新的 `define_start` 并把未完成的 starter 强制 `define_end`;
   `on_sealed` 在最后一个 starter 结束时触发。
- `builtins` 默认取 `libs/dsl.lua` 的 `dsl.builtins()`(widget 库 + 值类型 +
  两个工厂),再叠上 `print`(走 `mp.msg.info`)。
- 复用了框架的计数语义:session 的 `define_start` / `define_end` 是**引用计数**的,
  多个脚本各发一对 `define_start`/`define_end`,全部结束才 `sealed`。

`main.lua` 的接线(非阻塞路线):`MpDefine():listen()` → `mpv_app.start(scaffold,
{ binds = define.binds })` → `define.on_sealed = remount` → `mp.add_timeout(window)`
作为兜底 `close()` + remount。`bind` 只写挂载前的 widget 树,所以 remount 是
**重建**一份 scaffold 再套 `binds:apply`,而不是改活树(§7.2)。

---

## 10. 代码风格与工具约定

- 文件头:`-- This file is part of elxosc ... MIT ...` + `-- Copyright (C) 2026 ErloneAlpha`。
- 缩进 4 空格、单引号、LF(见根 `.editorconfig`)。
- 类用 `std.class.new('Name', {Base})`;构造用 `:__init(...)`;
  需要基类初始化时显式 `std.super(Child, self, Parent).__init(self, ...)`。
- 抛错用 `local raise = std.raise` + `raise(std.RuntimeError('...'))`。
  `.emmyrc.json` 里 `runtime.special.raise = "error"` 让静态分析知道它不返回。
- 注解用 `---@class/@field/@param/@return/@overload/@alias`;静态方法写在类上
- 局部变量遮蔽标准库时保持 `local math = math` 这类写法(仓库既有风格)。
- 表达类型收窄用 `--[[@as Type]]`(例:`(a - b) --[[@as Offset]]`、`nil --[[@as Paint]]`)。

---

## 11. 验证流程(每次改动都要做)

```powershell
cd E:\mpvnet\portable_config\scripts\elxosc

# 1) 静态检查(必须在项目根运行,以便读到 .emmyrc.json)
emmylua_check.exe .
#    期望: "No issues found",退出码 0

# 2) 离线测试(裸 LuaJIT,不需要 mpv)
E:\lua\local\LuaJIT\bin\luajit.exe test\run.lua
#    期望: "ALL GOOD: <N> checks passed",退出码 0
```

当前基线:**0 诊断 / 408 checks**。

测试文件与职责:

| 文件 | 内容 |
| --- | --- |
| `test_foundation.lua` | 几何/颜色/Paint/Path/Canvas 契约 |
| `test_text.lua` | TextStyle、TextLayout 契约与换行 |
| `test_scheduler.lua` | FrameClock 契约、两阶段调度、Ticker |
| `test_layout.lua` | Constraints、盒子、owner、绘制与命中 |
| `test_input.lua` | pointer_path、gesture 分发、hover |
| `test_widget.lua` | build→element→render、复用、set_state 重建 |
| `test_button_contract.lua` | 按钮构造参数、样式复制、PointerEvent 契约 |
| `test_bind.lua` | InheritedWidget、bind 的 op 与错误分支 |
| `test_define.lua` | 沙箱 env/load shim、模块注册表(数据+loader)、define 协议 |
| `test_dsl.lua` | `new_widget` / `new_state` / `builtins` |
| `test_host_define.lua` | `MpDefine`:`mp` 模块、消息路由、窗口/计数(`mp` 用桩) |
| `test_host_app.lua` | `App`:帧时钟、overlay、`WidgetBinding`、定义窗口接线(`mp` 用桩) |
| `test_ass.lua` | ASS 颜色/图元/文本/变换/裁剪 |
| `constraints_examples.lua` | 素材:29 个 flutter/constraints 示例对应的 widget 树 |
| `test_constraints_examples.lua` | 29 个示例的原始 `ass-events` 输出逐字对标(400×670) |
| `test_layering.lua` | 守护:框架目录不得 `require 'mp'` |

约定:**框架目录要求 0 诊断**;测试文件在文件头统一禁用
`undefined-field, inject-field, need-check-nil, generic-constraint-mismatch,
preferred-local-alias, unused`(这些是 `std.class` 建模与可选字段带来的固有误报)。

---

## 12. 已完成路径(现状总结)

| 阶段 | 内容 | 状态 |
| --- | --- | --- |
| 基础 | geometry/color/paint/path/canvas 契约 | 完成 |
| 布局 | Constraints(enforce/tighten/expand/unbounded...) + Padding/Align/Flex/Stack/SizedBox/ConstrainedBox/LimitedBox/UnconstrainedBox/OverflowBox/FittedBox/DecoratedBox/Text | 完成(对齐 flutter/constraints) |
| 渲染树 | RenderObject/RenderOwner + 脏标记 + 指针路由 + set_children | 完成 |
| 调度 | FrameClock/Scheduler/Ticker | 完成 |
| 文本 | TextStyle/Paragraph/TextLayout + 环境默认测量器 | 完成(测量为估算) |
| 后端 | AssCanvas/AssTextLayout/RecordCanvas | 完成(ASS 已实机验证) |
| Widget | Widget/Element/State/BuildOwner/WidgetBinding | 完成 |
| 组件 | Container/Padding/Align/Flex/Row/Column/Stack/ConstrainedBox/LimitedBox/UnconstrainedBox/OverflowBox/FittedBox/SizedBox/Text/CustomPaint/GestureDetector | 完成(子集) |
| 数据下行 | InheritedWidget + `depend_on_inherited` | 完成(基础) |
| 绑定 | `Widget.id` + `BindRegistry` + `bind`(define 期写入) | 完成 |
| 定义期 | `libs/sandbox.lua` + `libs/modules.lua` + `libs/define.lua` + `libs/dsl.lua` | 完成 |
| 宿主 | `host/mpv_app.lua`(WidgetBinding 帧循环)+ `host/mpv_define.lua`(定义期)+ `host/mpv_input.lua` | 初步完成(未实机验证;`mp` 桩覆盖) |

已知限制(有意保留,写代码时不要"顺手修"成别的语义):

1. **没有 GlobalKey**:不支持把子树搬到树的其他位置(当前模型"从 element 树收集
   子渲染对象",搬运代价高且扩展协议用不到)。
2. **没有 RepaintBoundary / Viewport+Sliver**:大列表不可虚拟化。
3. **没有 AnimationController/Tween/Curve**:只有底层 `Ticker`。
4. **没有手势竞技场**:`RenderGesture` 是"谁在命中链上谁处理",点击/拖拽不可消歧。
5. **`bind` 只能命中静态可遍历的节点**(见 §7.2)。
6. `host/mpv_input.lua` 依赖 `main.lua` 的全局 `debug_msgf`;调试工具应下沉到
   `libs/debug.lua` 之类的模块。

---

## 13. 未来路径

### Phase 3 — 定义期 / 沙箱 / 模块 ✅ 完成

- `libs/sandbox.lua`:受限 env 原语 + `load` 兼容 shim + `rawset` 守卫。
- `libs/modules.lua`:模块注册表(数据模块 + loader + `protect`)。
- `libs/define.lua`:`define_start` / `define(scope, code)` / `define_end`
  (引用计数),`import` / `mod` / `bind` 内建,共享 `BindRegistry`。
- `libs/dsl.lua`:`new_widget` / `new_state` / `builtins`。
- 宿主侧(§9.3):`host/mpv_define.lua` 的传输、`mp` 模块、窗口与超时兜底。

待做:env API 版本化与兼容策略(第三方脚本依赖);`on_prop` 订阅的生命周期
管理(当前由宿主模块自行负责)。

### Phase 4 — 能力补齐

`Viewport` / Sliver 虚拟列表 → `RepaintBoundary` + `Picture` 缓存 →
`AnimationController` / `Tween` / `Curve` → 用 `InheritedWidget` 封装 Theme /
MediaQuery → `parentUsesSize` 与 relayout/repaint boundary → 手势竞技场。

### Phase 5 — 宿主扩展(初步完成)

- ✅ `host/mpv_app.lua` 切到 `WidgetBinding`(§9.1)。
- ✅ `host/mpv_define.lua`:`define` 消息 + `mp` 模块 + 定义窗口(§9.3)。
- ✅ `main.lua`:scaffold + `Slot` + 定义窗口接线。
- 待做:实机验证;mpv.net 后端(实现 `Canvas` + `TextLayout` + `FrameClock` +
  输入源四件套即可,框架层不动);未处理的鼠标事件转发回 `input.conf`;
  `osd-margins` 自动调整;文本度量升级(字宽表);env API 版本化;
  调试工具下沉为 `libs/debug.lua`(去掉 `main.lua` 的全局 `debug_msgf`)。

### 待决策

| # | 问题 | 现状 |
| --- | --- | --- |
| 1 | 扩展形态 | 已定:**代码字符串 + 沙箱 env**(`dev/feat_example.lua`) |
| 2 | 运行期可变性 | 已定:**Widget 树运行期不变**;变化只来自 `set_state` |
| 3 | 对外命名 | 已定:对外 **Widget / State**;`RenderObject` 仅内部渲染层 |
| 4 | 沙箱严格度 | 待定:纯 API 卫生 vs 防恶意脚本(是否屏蔽 `_G`/`load`) |
| 5 | 文本度量精度 | 待定:是否引入字宽表 |
