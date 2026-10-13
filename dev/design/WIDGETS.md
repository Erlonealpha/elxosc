# Widget、Element 与控件

本文负责声明式 Widget 树、Element 生命周期、State rebuild、绑定和控件 API。

## Widget 不可变

Widget 是轻量描述，不负责 layout/paint，也不在 mount 后修改自己的 child 或
options。构造器应复制/规范化 caller options；运行时变化放进 State 或 RenderObject
的明确 setter。

`Widget.can_update(old, new)` 以运行时类和 key 判断复用。相同类/等 key 保留
Element、State 和 RenderObject；key 改变或类型改变则重建对应实例。

## Element 生命周期

Element 负责：

1. mount Widget 并创建子 Element/RenderObject；
2. 在 rebuild 中按类型和 key reconciliation；
3. 将 RenderObject 子节点收集到正确父节点；
4. 更新 Inherited 依赖和 ParentData；
5. unmount 时调用 State.dispose 并断开运行时资源。

State 的 `init_state` 只在首次挂载调用，`set_state` 只包裹状态修改并将 element
加入 build 队列，`dispose` 必须释放 controller、ticker 和宿主订阅。State 不应在
build 中反复注册一次性宿主资源。

## 控件层

`widget/widgets/` 按职责拆成：

- 布局：Padding、Align、SizedBox、Container、Flex/Row/Column、Stack、
  ConstrainedBox、LimitedBox、OverflowBox、UnconstrainedBox、FittedBox、
  OffsetBox、TransformBox、LayoutScaleBox；
- 内容：Text、Icon、CustomPaint；
- 输入：GestureDetector、Button 及其样式/变体、IconButton。

兼容聚合入口 `widget.widgets.basic` 和 `widget.widgets.layout` 只重导出独立模块
的同一对象。新增控件应优先创建独立模块，再补聚合入口、模块 README 和加载/行为
测试。

## 绑定和插槽

`Widget.id` 为 Define 期命名目标。`BindRegistry` 在 mount 前静态遍历 Widget 树，
向可接收 `child` 或 `children` 的目标写入 Widget：单子节点默认 replace，多子
节点默认 append；显式操作包括 replace_if_empty 和 insert。

绑定完成后不再管理运行时 Widget 树。后续 UI 变化必须由 State rebuild；绑定注册
表不提供回滚、运行时 unbind、scope shutdown 或 root rebuild。一个 scope 的多个
绑定按注册顺序保留，不引入 priority。

## Pages、Main 和扩展区域

播放器应用层计划在 Widget 组合层提供：

```text
Root
└── Pages
    ├── Main
    │   ├── title bar
    │   ├── timeline
    │   ├── bottom buttons
    │   └── left/right buttons
    ├── 3x3 grid
    └── more
```

Main 的固定结构由播放器拥有；扩展通过 Define 暴露的 Pages/region 接口提供内容，
而不是绕过 Widget 树直接写入 RenderObject。grid 和 more 的稳定区域 id、single/
multi-child 规则、ordered append 和冲突诊断由 Pages API 明确规定。

Define 仍是扩展内容的唯一入口。它只负责传入扩展内容，不规定扩展页面内部的行为；
扩展可以在自己的 StatefulWidget 中处理状态、消息和配置/API 更新。配置/API 热更新
是数据事件，不是第二条 Widget 注入路径，也不重新执行扩展源代码。

Pages 是应用组合层，不是 Navigator，也不提供运行时 unbind、树回滚或外部直接修改
mounted Widget。区域结构变化应通过 Pages 的受控更新接口或扩展自己的 State/build
完成。

## BuildContext、Provider 与播放器状态

当前 `BuildContext` 是 `Element` 的类型别名，并已支持
`depend_on_inherited(widget_class)`。播放器应用阶段继续完善稳定的
`SomeProvider.of(context)` / `maybe_of(context)` 入口，例如 Theme、MediaQuery 和
只读 PlayerSnapshot。

Provider 的更新必须让依赖者走既有 dirty/build 管线；控件不能直接读取 `mp`，也不能
在 `build()` 中注册一次性 property observer。播放器配置/API 热更新形成新 snapshot，
由 Provider/State 或明确 RenderObject setter 消费；扩展通过 Define 获得允许的 provider
和更新接口，更新本身不构成新的内容注入。

## 新控件检查表

- 选项表有 `_TypeNameOptions` 类型，构造器不修改调用方表。
- Widget 字段只保存声明式配置，副作用放到事件或 State 生命周期。
- 对应 RenderObject setter 正确区分 layout/paint dirty。
- 独立模块、聚合入口和 `std.class` identity 有测试。
- 需要 host 能力时通过回调、State 或 Define module 注入，不 require `mp`。
