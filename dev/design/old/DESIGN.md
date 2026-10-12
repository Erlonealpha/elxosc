# elxosc 设计现状与路线

阶段性总结:当前框架结构、与 Flutter 的对照、扩展形态与下一步目标。

---

## 1. 分层现状

```
elxosc/
  foundation/   geometry(Offset/Size/Rect/EdgeInsets) · color
  painting/     canvas · paint · path
  text/         text_style · paragraph · text_layout(测量契约 + 环境默认)
  scheduler/    frame_clock(契约) · scheduler(帧管线) · ticker
  layout/       constraints
  render/       render_object · render_owner · padding · align · flex · stack
                · sized_box · decorated_box · text · custom_paint · gesture
  widget/       widget · element · state · key · bind · build_owner · binding · init
                widgets/layout(Padding Align Center SizedBox DecoratedBox
                                Flex Row Column Stack Flexible Expanded
                                Spacer Container)
                widgets/basic(Text Icon CustomPaint GestureDetector)
  libs/         sandbox(受限 env) · modules(模块表) · define(协议) · dsl(DSL 面)
  backends/     ass_canvas · ass_text_layout · record
  host/         mpv_app(帧循环/显示/overlay) · mpv_define(定义期) · mpv_input(指针/按键)
  dev/          feat_example(设计草图) · feat_example_meta(DSL meta 桩)
  main.lua      入口:装配 host + 后端 + scaffold + 定义窗口
```

**解耦约束(可回归)**:框架层不得依赖 mpv。目前只有 `main.lua`、
`elxlib_load.lua`、`host/*` 允许 `require 'mp'`,由 `test/test_layering.lua`
自动守护。

宿主相关的只有四处,其余全是可复用的纯逻辑:

| 契约 | 作用 | ASS 实现 | 未来 mpv.net 实现 |
| --- | --- | --- | --- |
| `Canvas` | 绘制原语 | `backends/ass_canvas` | 原生绘制调用 |
| `TextLayout` | 文本测量 | `backends/ass_text_layout`(估算) | 真实字体度量 |
| `FrameClock` | 帧/时间驱动 | `host.MpFrameClock` | vsync/渲染回调 |
| 输入源 | 指针与按键 | `host/mpv_input` | 宿主事件 |

---

## 2. 与 Flutter 的对照

图例:完成 / 部分 / 缺失 / 计划

| Flutter 概念 | elxosc 对应 | 状态 |
| --- | --- | --- |
| `dart:ui` 几何 / `Color` | `foundation/geometry` · `foundation/color` | 完成 |
| `Canvas` / `Paint` / `Path` | `painting/*` | 完成 |
| `Picture` / `PictureRecorder` | `backends/record` | 部分(无跨帧复用) |
| `BoxConstraints` | `layout/constraints` | 完成 |
| `RenderObject` / `RenderBox` | `render/render_object` | 完成 |
| `RenderPadding` / `RenderPositionedBox` / `RenderFlex` / `RenderStack` / `CustomPaint` | `render/*` | 完成(子集) |
| `RenderView` + `PipelineOwner` | `render/render_owner` | 部分(合并) |
| `SchedulerBinding` 帧阶段 + `Ticker` | `scheduler/*` | 完成 |
| `TextStyle` / `TextPainter` / `Paragraph` | `text/*` | 部分(测量为估算) |
| `GestureDetector` | `render/gesture` | 部分(无竞技场) |
| `HitTestResult`(带变换) | `render_object:pointer_path` | 部分 |
| `Widget` / `Element` / `BuildContext` | `widget/widget.lua` · `widget/element.lua` | 完成(Element 即 BuildContext) |
| `StatelessWidget` / `StatefulWidget` / `State` / `setState` | `widget/{widget,state,build_owner}.lua` | 完成 |
| `Container` / `Row` / `Column` / `Stack` / `Text` … | `widget/widgets/*` | 完成(子集) |
| `ParentDataWidget`(`Flexible`/`Expanded`) | `widget/widgets/layout.lua` + `ParentDataElement` | 完成(简化) |
| `RenderParagraph` | `render/text.lua` | 完成(测量走后端) |
| `RenderConstrainedBox` / `RenderDecoratedBox` | `render/sized_box.lua` · `render/decorated_box.lua` | 完成 |
| `WidgetsBinding` | `widget/binding.lua` | 完成(精简,无 host 依赖) |
| `InheritedWidget`(主题/MediaQuery) | `widget/widget.lua` · `widget/element.lua` | 完成(基础) |
| `bind`(把 widget 挂到命名目标节点) | `widget/bind.lua`(`BindRegistry` + `bind`) | 完成 |
| 插件扩展协议(Flutter 无对应) | `libs/sandbox.lua` · `libs/modules.lua` · `libs/define.lua` | 完成(协议核心;宿主服务/传输层待接) |
| `AnimationController` / `Tween` / `Curve` | `animation/*` | 完成 |
| 正轴向 TransformBox / LayoutScaleBox | `render/*` · `widget/widgets/transform_box.lua` | 完成 |
| `RepaintBoundary` / 图层缓存 | — | 计划(Phase 4) |
| `Viewport` / Sliver(虚拟列表) | — | 计划(Phase 4) |
| Semantics | — | 不适用 |

**结论**:渲染层(rendering / painting / layout / scheduler)与 Widgets 层均已与
Flutter 对齐;**仍缺 Viewport/Sliver/RepaintBoundary**。此外多了一层
Flutter 没有的**定义期协议**(`libs/`),供其他脚本声明界面。

---

## 3. 与 Flutter 的结构性差异(有意取舍)

1. **Widget→Element→RenderObject 三棵树已就位**(Phase 1/2);宿主仍可绕过
   Widget 层直接命令式地构 RenderObject(§9.1 的过渡形态,不是最终形态)。
2. **脏标记传播到根**;Flutter 有 relayout/repaint boundary 截断。功能正确,性能待优化。
3. **命中测试返回节点路径**,无逐级变换、无手势竞技场 → 点击/拖拽无法消歧。
4. **文本测量是后端职责**(ASS 无法测量),ASS 后端目前是估算。
5. **布局缺 `parentUsesSize`**(Flutter 用它做断言与优化)。

### 3.1 Widget 层的简化(相对 Flutter)

1. **子渲染对象从 element 树收集**(`Element:first_render_object`)而不是
   Flutter 的 slot + GlobalKey 机制。这让"复合 widget 夹在两个渲染对象之间"
   无需额外记录,但**不支持把子节点搬到别处**(Overlay / Portal / GlobalKey
   重挂载)。当前布局类 widget 不需要它。
2. **`Element:update` 立即重建子树**,等价于 Flutter 的
   `ComponentElement.update` → `rebuild(force: true)`;但缺
   `didChangeDependencies` / `deactivate` / `activate` 等生命周期钩子。
3. **`InheritedWidget` 已有但未封装成主题**:数据下行用
   `context:depend_on_inherited(SomeWidget)`;把主题 / MediaQuery 做成具体
   provider 属于 Phase 4。文本度量仍走环境默认(`text_layout.set_default`)。
4. **`bind` 只在 define 期改树**:注册表把 widget 写进目标节点的 `child` /
   `children`,**在挂载前**应用一次;运行期不修改 widget 树,后续变化只能来自
   `set_state`。代价是 `id` 必须出现在**能静态遍历的声明式 widget 树**里 ——
   藏在 `build()` 内部、define 期看不见的节点不能作为绑定目标。

---

## 4. 扩展形态(方向已定,协议核心已实现)

实现见 `libs/sandbox.lua` + `libs/define.lua`;本节保留设计推演与坑的记录,
与现状的差异以 `dev/design/old/DESIGN_PATH.md` §7.3 为准。历史草图在 `dev/feat_example.lua`。

其他脚本通过 `script-message-to elxosc` 发送:

```
define_start
define(<scope_id>, <lua 源码字符串>)   -- 一到多条
define_end
```

框架在自己的 Lua State 里用**受限环境**执行这段源码,它写出的是 Flutter 式的
**Widget / State DSL**,配合**命名插槽**与**模块共享**。

### 4.1 生命周期

1. `define_start` → 进入**定义期**(可与 `elxlib` 的 amp 事件循环共存,用超时兜底:
   `wait_start_timeout` 等第一条,`all_timeout` 收尾)。`feat_example` 里就是挂在
   `_G.mp_event_loop`(elxlib asyncio 的 amp 循环,已确认)之前抢先跑。
2. `define(scope, code)` → `load` 进沙箱 env 执行:注册 state / widget 类、
   调用 `bind(slot, widget)` 挂载。
3. `define_end` → **封版**:校验插槽、构建 Widget 树 → Element 树 → RenderObject 树,
   进入运行期。
4. 运行期:只允许 `set_state` 触发的**重建**,不允许外部再改 widget 定义。

### 4.2 DSL ↔ Flutter

| feat_example | Flutter | 说明 |
| --- | --- | --- |
| `new_widget(name, parent)` | `StatefulWidget` 子类 | 返回可实例化的 widget 类 |
| `Widget:create_state()` | `createState()` | |
| `new_state(name, parent)` | `State` 子类 | 构造走 `__init` |
| `State:build(ctx)` | `State.build(context)` | 返回 widget 子树 |
| `State:set_state(fn)` | `setState(fn)` | 触发重建 |
| `bind('title_bar', Widget{...})` | 写入命名目标节点的子槽位 | 见 4.4 |
| `mod(name)` / `import(name)` | 库共享 | 见 4.5 |
| `on_prop` / `on_message` / `on_event` | 外部事件绑定 | 见 4.6 |

**这确认了运行期模型是方案 B**:`set_state` 必须能重建子树,所以
Widget→Element→RenderObject 三棵树与 type/key 复用是硬需求,而不是可选优化。

### 4.3 沙箱环境

`env` 是一张普通表,metatable 的 `__index` 指向 `api`、`__newindex` 守卫后
`rawset`(`libs/sandbox.new_env`):

- 读:落到 `api`,即可读的名字。**框架只提供四个内建**
  `import` / `require`(别名)/ `mod` / `bind`,其余全部由宿主注入 ——
  `new_state` / `new_widget` / widget 构造器走 `builtins`,`on_prop` /
  `on_message` 走 `mp` 模块;
- 写:落进 env 自身,即该 scope 的"模块级变量"(`MyState`、`MyWidget`);
- `import('mp')`:暴露的应是**受控 facade**,而非原始 `mp`;
- 模块级 `local`(chunk 内的 `local x`)天然私有。

### 4.4 `bind(id, widget, opts)`

宿主在 scaffold 里给节点起名(`Widget.id`),脚本用 `bind` 把 widget 写进去。
绑定在 **define 期收集**,由 `BindRegistry:apply(root)` 在**挂载前**写入目标
节点 —— 因此不存在运行期修改 widget 树。默认操作就是"设为目标节点的子 widget":

| 目标 | 默认 op | 可用 op |
| --- | --- | --- |
| `child`(单子节点) | `replace` | `replace`, `replace_if_empty` |
| `children`(多子节点) | `append` | `append`, `insert`(+ `position`) |

`Widget:child_widgets()` 提供静态遍历,`Widget:bind_target()` 声明该节点接受
`child` 还是 `children`。后续可在同一注册表上扩展更多 op,以及"改目标节点部分
设置"的能力。

### 4.5 模块共享 `mod` / `import`

注册表(`libs/modules.lua`)分两张表,对应脚本侧的两个名字:

- `mods` 是**数据模块**:`import(name)` 把它的键值摊进当前 env;
- `loaders` 是**安装器**:复制之后运行 `loader(env, scope_id)`,用于需要 scope
  本身的函数(典型例子:`mp` 的 loader 安装 `on_message`);
- `mod(name[, data])` 发布模块(缺省发布当前 env),`protect(name)` 可禁止覆盖。

这是**跨 scope/跨脚本共享代码**的唯一通道 —— 因为 mpv 每个脚本是独立 Lua State,
函数无法直接传递。

### 4.6 事件服务

`on_prop(name, cb)` / `on_message(cb)` / `on_event(name, cb)` 把 mpv 的
property/event/script-message 转成 state 更新:`cb` 里调 `self:set_state(...)`,
触发对应子树重建。

**这属于宿主模块,不属于框架**:`on_prop` 是 `mp` 模块的数据,`on_message` 由
`mp` 的 loader 装进 env;订阅、解绑、随脚本卸载的清理都由该模块自己负责。

### 4.7 已核实的坑(实现时踩过 / 已处理)

1. **`__newindex` 递归**:示例里 `__newindex = function(obj,k,v) obj[k]=v end`
   会 `stack overflow`(已实测)。必须 `rawset(obj, k, v)` —— 已照此实现。
2. **`load(code, name, 't', env)` 的可移植性**:本机 LuaJIT 实测**支持** 5.2 签名
   (env 生效、无 `_G` 泄漏),但构建若未开 `LUA52COMPAT` 就会**静默忽略 env**
   → 沙箱失效。**已处理**:`libs/sandbox.load_chunk` 先 `load(...)`,再在
   `setfenv` 存在时套一层(不依赖 `loadstring`)。
3. **`import` 的复制范围**:示例 `for k,v in pairs(mods)` 复制的是**全部**模块。
   **已处理**:按单个模块复制,并拆成 `mods`(数据)/ `loaders`(安装器)两张表。
4. **`import('mp')` 依赖预注册**:`mods['mp']` 必须由宿主预先登记(并且是 facade),
   否则 `ImportError`。宿主接线仍在 Phase 5。
5. **命名不一致**:env 里写 `on_event`,示例里用 `on_prop`/`on_message`。
   **已处理**:`on_prop` 归 `mp` 模块的数据,`on_message` 归其 loader,名字与
   草图一致。
6. **定义期超时是墙钟等待**,要保证不阻塞 mpv 启动太久(0.5s/1s 量级尚可),
   且超时后要能继续而非卡死。宿主侧待做(Phase 5)。
7. **`bind`**:已实现(`widget/bind.lua`),插槽机制见 4.4。

详见 `dev/design/old/DESIGN_PATH.md` §7.3(现状与草图差异)。

---

## 5. 路线图

### Phase 1 — Widget / State / Element ✅ 完成

- `widget/widget.lua`:`Widget`、`StatelessWidget`、`StatefulWidget`、
  `ProxyWidget`/`ParentDataWidget`、`Leaf/Single/MultiChildRenderObjectWidget`、
  `can_update`(`runtime_type + key`)。
- `widget/element.lua`:`Element` 及子类(Stateless/Stateful/Proxy/ParentData/
  Leaf/Single/Multi RenderObject),`first_render_object` 收集,`update_child`
  复用或重建。
- `widget/state.lua`:`State`(`init_state`/`build`/`set_state`/
  `did_update_widget`/`dispose`)。
- `widget/build_owner.lua` + `widget/binding.lua`:脏 element 队列、深度排序重建、
  根渲染对象同步。
- 组件库与新增渲染叶子:`Container`/`Padding`/`Align`/`Center`/`SizedBox`/
  `DecoratedBox`/`Flex`/`Row`/`Column`/`Stack`/`Flexible`/`Expanded`/`Spacer`/
  `Text`/`CustomPaint`/`GestureDetector` + `RenderText`/`RenderSizedBox`/
  `RenderDecoratedBox`。
- `widget/init.lua`:`require 'widget'` 聚合入口。

### Phase 2 — 运行期重建 / 插槽 ✅ 完成

- `set_state` → 脏 element → 深度序重建 → `can_update` 复用 element/render
  object → 重新 layout/paint(`test/test_widget.lua`)。
- `InheritedWidget` / `InheritedElement` + `Element:depend_on_inherited`
  依赖追踪;provider 变化只重建依赖者。
- `BindRegistry` + `Widget.id` + `Widget:bind_target()` / `child_widgets()`:
  define 期把 widget 写进命名目标节点的子槽位,挂载前应用一次,运行期不变
  (`test/test_bind.lua`)。
- **不做 `GlobalKey`**:当前模型是"从 element 树收集子渲染对象",跨树搬运子树
  需要 detach/attach 渲染对象并维护 slot 记录,代价高且扩展协议用不到。

### Phase 3 — 定义期 / 沙箱 / 模块 ✅ 完成

- `libs/sandbox.lua`:受限 env 原语 + 兼容 `load` shim + `rawset` 守卫(无状态)。
- `libs/modules.lua`:模块注册表,数据模块与 loader 分表,`protect` 防覆盖。
- `libs/define.lua`:`define_start` / `define(scope, code)` / `define_end`
  (引用计数),`import`/`mod`/`bind` 内建,共享 `BindRegistry`。
- `libs/dsl.lua`:`new_widget` / `new_state` / `builtins`。
- 宿主接线见 Phase 5;待做:env API 版本化。

### Phase 4 — 能力补齐（进行中）

✅ `AnimationController`/`Tween`/`Curve` 与正轴向 `TransformBox`/`LayoutScaleBox`。
待做:`Viewport`/`Sliver` 虚拟列表;`RepaintBoundary` + `Picture` 缓存;
`InheritedWidget`(主题/MediaQuery);`parentUsesSize` 与 relayout/repaint boundary;
手势竞技场。

### Phase 5 — 宿主扩展(初步完成)

- ✅ `host/mpv_app.lua` 切到 `WidgetBinding`;`host/mpv_define.lua` 接
  `script-message` + `mp` 模块 + 定义窗口;`main.lua` 装配 scaffold。
- 待做:实机验证;mpv.net 后端四件套;未处理事件转发回 `input.conf`;
  `osd-margins` 自动调整;文本度量升级;`libs/debug.lua`。

---

## 6. 决策状态

| # | 问题 | 结论 |
| --- | --- | --- |
| 1 | 扩展形态:数据 vs 加载器 | **代码字符串 + 沙箱 env**(`feat_example.lua`) |
| 2 | 运行期可变性:仅叶子绑定 vs 重建 | **方案 B**:`set_state` 触发重建 + Element 复用 |
| 3 | 对外命名 | **Widget / State**(Flutter 同名);`RenderObject` 仅内部渲染层 |
| 4 | 文本度量升级 | 待定(可参考 uosc `lib/text.lua` 的字体宽度表) |
| 5 | 沙箱严格度 | 待定:纯 API 卫生,还是防恶意脚本(影响是否屏蔽 `_G`/`load`) |
| 6 | 文本测量的传入方式 | 环境默认(`text_layout.set_default`)+ widget 可显式覆盖;`InheritedWidget` 已可用,但 Theme/MediaQuery 的具体 provider 属 Phase 4 |
| 7 | 宿主接入 Widget 层的时机 | 已定并已执行:`host/mpv_app.lua` 走 `WidgetBinding`,`main.lua` 装配 scaffold + 定义窗口 |

## 7. 已知待清理

- `host/mpv_input.lua` 依赖 `main.lua` 定义的全局 `debug_msgf`;调试工具应下沉为
  独立模块(如 `libs/debug.lua`),避免 host 依赖入口脚本的全局。
- `dev/feat_example.lua` 是早期设计草图(含占位 `error('...')`),不要当作可运行
  代码;正式实现见 `libs/sandbox.lua` + `libs/modules.lua` + `libs/define.lua`
  + `libs/dsl.lua`(`dev/design/old/DESIGN_PATH.md` §7.3)。
- mpv 平台层**尚未实机验证**(`mp` 用桩测试);`on_prop` 的订阅没有随 scope
  销毁解绑,当前归宿主模块自行负责(`dev/design/old/DESIGN_PATH.md` §9.3、§12)。
