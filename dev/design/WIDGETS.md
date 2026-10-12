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

## 新控件检查表

- 选项表有 `_TypeNameOptions` 类型，构造器不修改调用方表。
- Widget 字段只保存声明式配置，副作用放到事件或 State 生命周期。
- 对应 RenderObject setter 正确区分 layout/paint dirty。
- 独立模块、聚合入口和 `std.class` identity 有测试。
- 需要 host 能力时通过回调、State 或 Define module 注入，不 require `mp`。
