# 代码风格参考
本项目使用Emmylua_ls作为类型提示和检查工具。

## 本次更新后的约定

- 类型注释覆盖所有文件所有段落，包含函数声明、字段声明、类型转换等等；
  唯一可豁免的是明确的函数重载且签名不变时可不用重复编写函数声明和限度的测试场景。
- 全局变量需要本地化
- 生产文件使用 `---@namespace elxosc` 限定声明、`---@using elxosc` 简写类型引用；
  Material/player/Define/host 可追加对应的 `---@using elxosc.<owner>`。
  例如声明 `---@class mod.src.material.slider` 对应完整类型
  `elxosc.mod.src.material.slider`，声明 `material.Slider` 对应 `elxosc.material.Slider`；
  引用时可写 `Widget`、`Slider` 等明确可解析的短名，有冲突时保留 owner 前缀。
  不添加可由 namespace/using 解析的类名字符串强转；不更改运行时类名。
- 生产模块表解析为 `elxosc.mod.<canonical require>`，路径以 `.`
  连接。例如 `lib/src/material/slider.lua` 声明 `elxosc.mod.src.material.slider`，
  `lib/widgets.lua` collector 声明 `elxosc.mod.widgets`，`define/src/modules.lua`
  声明 `elxosc.mod.define.src.modules`。`src/widgets/init.lua` 是 collector 单向 alias，
  不重复声明类型。生产实例/Options/alias 已统一 owning namespace；运行时路径不添加 elxosc。
  模块表与 Widget 等实例类型分别命名；显式导出字段保留构造器和函数签名。
- 聚合表只重导出同一对象。完整重导出可继承来源模块类型；选取部分字段时只声明
  实际字段，不能通过继承虚报未导出的 API。扩展包使用 `DefinePackage<T>` 描述
  `{ name, exports, loader? }`，合并导出可用 `&` 连接模块类型（也可与数组合并）。
  `elxosc.` 是类型名前缀；运行时 `require`、`import`、`import_as` 仍使用裸模块名
  和短包名。源码 require 使用 `src.material.slider`，扩展 import 使用
  `material.slider`、`widgets`、`player`、`mp`。
- meta 的作用域名称使用 `elxosc.meta.Builtins` 局部表类型，不声明编辑器全局变量。
  Define `require` 与 `import_as` 返回局部包，`import` 注入成员；标准源码 require
  仍加载文件模块。默认 builtins 提供 new_widget/new_state 和选定 Lua 工具，
  包括 math/table；组件与框架值类型从包取得。外部 elxlib std 由 host 注册为独立包，
  不属于 lib collector，也不默认注入到 builtins。
- 重复使用的字符串联合提取为语义化的命名 alias，并逐行列出候选值。例如
  `MainAlignment`、`CrossAlignment`、`FlexDirection`、`PaintStyle`、`BindTarget`。
  声明、字段、参数及返回类型应复用同一 alias，而不是重复一长串字面量。
- 闭合集合不要追加 `| string`，否则会失去非法值检查。像可扩展事件名称这样的
  开放集合才允许保留 `string`，并说明扩展边界；类型注释不能代替运行时校验。
- 使用单引号书写项目 alias 的字面量，行末不保留空格。类与 Options 的注释块
  之间留空行，避免注释错误地关联到另一个声明。
- 下文摘录的 EmmyLua `builtin.lua` / `global.lua` 是类型工具参考，保留其来源
  和许可证；其中 Lua 5.2+ 的 API 不代表本项目 LuaJIT 5.1 运行时可用。
- `@return_overload` 适合描述成功与失败的关联返回值；泛型、`Partial<T>` 等应
  用于准确表达已有契约，不要为了绕过诊断扩大为 `any` 或伪造可调用类型。
- 设计资料集中在 `dev/design/`，贡献指南为根目录 `AGENTS.md`。区分当前实现、
  历史记录和未实现方案，避免将规划 API 描述为现有能力。

## 排版约定

- 独立 `elxlibs.dataclass` 值类显式声明实例字段、构造 overload 和
  `dataclass.Object` 基类；自定义 hooks/operators 在 `dataclass.finish` 前定义。
  类型守卫/继承使用该模块接口，不能标为 `std.object` 或假称兼容 std 反射。

- 模块导入、类型别名和局部字段分组时使用空行分隔，保持视觉层次清晰。
- 类声明的 `---@overload` 使用返回类型 `self` 表示构造器返回当前类；不要为
  `__init` 添加无意义的 `---@return nil`。
- 选项复制、默认样式等构造前处理放在局部 `config` 变量中，再传给父类构造器。
- 文件末尾保留一个换行；字段、类型别名和代码行末不保留空格。
- 单文件排版遵循：
  文件描述 -> 文件级注解（`@namespace` 和 `@using` 等） -> 模块引入 ->
  本地变量声明 -> 模块声明 -> 正文 -> 模块返回；
  以上仅表示顺序，从左至右为排版从上至下。

## emmylua可用内置类型
来自：emmylua/builtin.lua
```lua
--- @meta no-require

-- Built-in Types

--- @class nil

--- @class boolean

--- @class number

--- @class integer

--- *userdata* 类型用于允许将任意 C 数据存储在 Lua 变量中。
--- @class userdata

--- @class lightuserdata

--- *thread* 类型表示独立的执行线程，用于实现协程。
--- @class thread

--- @class table

--- @class any

--- @class void

--- @class unknown

--- @class never

--- @class self

--- @alias int integer

--- @class namespace<T: string>

--- @class function

--- @alias std.NotNull<T> T -?

--- @alias std.Nullable<T> T +?

--- Select 函数的内置类型
--- @alias std.Select<T, StartOrLen> unknown

--- Unpack 函数的内置类型
--- @alias std.Unpack<T, Start, End> unknown

--- Rawget 的内置类型
--- @alias std.RawGet<T, K> unknown

--- compact luals

--- @alias type std.type

--- @alias collectgarbage_opt std.collectgarbage_opt

--- @alias metatable std.metatable

--- @alias TypeGuard<T> boolean

--- @alias Language<T: string> string

--- 以元组形式获取函数的参数
--- @alias Parameters<T extends function> T extends (fun(...: infer P): any) and P or never

--- 以元组形式获取构造函数的参数
--- @alias ConstructorParameters<T> T extends new (fun(...: infer P): any) and P or never

--- 获取函数类型的返回类型
--- @alias ReturnType<T extends function> T extends (fun(...: any): infer R) and R or any

--- 使 T 中的所有属性变为可选
--- @alias Partial<T> { [P in keyof T]?: T[P]; }

--- 排除 T 中可以赋值给 U 的类型
--- @alias Exclude<T, U> T extends U and never or T

--- 提取 T 中可以赋值给 U 的类型
--- @alias Extract<T, U> T extends U and T or never

--- attribute

--- @class Attribute

--- 标记为`已弃用`。接收一个可选的消息参数。
--- @class deprecated: Attribute
--- @overload fun(message?: string)

---
--- Language Server Optimization Items.
---
--- Parameters:
--- - `skip_table_fields_check`: Skip table field diagnostics. It is recommended to use this option for all large configuration tables.
--- - `delayed_definition`: Indicates that the type of the variable is determined by the first assignment.
---    Only valid for `local` declarations with no initial value.
--- @class lsp_optimization: Attribute
--- @overload fun(code: "skip_table_fields_check" | "delayed_definition")

---
--- Index field alias, will be displayed in `hint` and `completion`.
---
--- Receives a string parameter for the alias name.
--- @class index_alias: Attribute
--- @overload fun(name: string)

---
--- This attribute must be applied to function parameters, and the function parameter's type must be a string template generic,
--- used to specify the default constructor of a class.
---
--- Parameters:
--- - `name`: The name of the method as a constructor.
--- - `root_class`: Used to mark the root class, will implicitly inherit this class, such as `System.Object` in c#. Defaults to empty.
--- - `strip_self`: Whether the `self` parameter can be omitted when calling the constructor, defaults to `true`
--- - `return_mode`: Constructor return strategy. `"self"` forces `self`, `"doc"` uses the documented return type,
---                 and `"default"` prefers the documented return type and falls back to `self`.
---                 Defaults to `"default"`
--- @class constructor: Attribute
--- @overload fun(name: string, root_class?: string, strip_self?: boolean, return_mode?: "self" | "doc" | "default")

--- 将 `getter` 和 `setter` 方法与字段关联。目前仅提供定义跳转功能，
--- 且目标方法必须位于同一个类中。
---
--- ### 参数
---
--- - `convention`: 命名约定，默认为 `camelCase`。隐式添加 `get` 和 `set` 前缀，例如 `_age` -> `getAge`、`setAge`。
--- - `getter`: Getter 方法名。优先级高于 `convention`。
--- - `setter`: Setter 方法名。优先级高于 `convention`。
--- @class field_accessor: Attribute
--- @overload fun(convention?: "camelCase" | "PascalCase" | "snake_case", getter?: string, setter?: string)
```

## emmylua如何定义示例
来自：emmylua/global.lua
```lua
---@meta no-require

--- 如果参数 `v` 的值为假（即 **nil** 或 **false**），则调用 error；
--- 否则返回所有参数。在发生错误的情况下，`message` 将是错误对象；
--- 如果省略，默认为 "assertion failed!"。
--- @generic T, T1
--- @param v   T
--- @param ... T1...
--- @return std.NotNull<T>, T1...
function assert(v, ...) end

--- @alias std.collectgarbage_opt
--- |> "collect"      # 执行完整的垃圾收集循环。这是默认选项。
--- | "stop"         # 停止垃圾收集器的自动执行。收集器只会在显式调用之前运行，直到调用 restart。
--- | "restart"      # 重启垃圾收集器的自动执行。
--- | "count"        # 以 Kbytes 为单位返回 Lua 使用的总内存数。该值有小数部分，乘以 1024 可得到 Lua 使用的确切字节数（溢出除外）。
--- | "step"         # 执行一次垃圾回收步骤。步进由 `arg` 控制。 如果值为 0，收集器将执行一个基础（不可分割）步进。 对于非零值，收集器执行的效果等同于 Lua 分配了相应数量（以 KBytes 为单位）的内存。 如果步进完成了一个收集循环，则返回 true。
--- | "setpause"     # 将 `arg` 设置为收集器 *pause* （参见 §2.5）的新值。返回 *pause* 的前一个值。
--- | "setstepmul"   # 将 `arg` 设置为收集器 *step multiplier* （参见 §2.5）的新值。返回 *step* 的前一个值。
--- | "incremental"  # 将收集器模式更改为增量模式。此选项后面可以跟三个数字：垃圾收集器暂停、步进倍率和步进大小。
--- | "generational" # 将收集器模式更改为分代模式。此选项后面可以跟两个数字：垃圾收集器次要倍率和主要倍率。
--- | "isrunning"    # 返回一个布尔值，指示收集器是否正在运行（即未停止）。

--- @alias std.collectgarbage.param
--- | "minormul"   # minor multiplier
--- | "majorminor" # major/minor ratio
--- | "minormajor" # minor/major ratio
--- | "pause"      # collector pause
--- | "stepmul"    # step multiplier
--- | "stepsize"   # step size

--- 此函数是垃圾收集器的通用接口。它根据第一个参数 `opt` 执行不同的功能。
---
--- ### opt
---
--- - **"collect"**: 执行完整的垃圾回收。这是默认选项。
---
--- - **"stop"**: 停止垃圾收集器的自动执行。收集器只会在显式调用之前运行，
--- 直到调用 restart。
---
--- - **"restart"**: 重启垃圾收集器的自动执行。
---
--- - **"count"**: 以 Kbytes 为单位返回 Lua 使用的总内存数。该值有小数部分，
--- 乘以 1024 可得到 Lua 使用的确切字节数（溢出除外）。
---
--- - **"step"**: 执行垃圾收集步进。步进 "size" 由 `arg` 控制。
--- 如果值为 0，收集器将执行一个基础（不可分割）步进。
--- 对于非零值，收集器执行的效果等同于 Lua 分配了相应数量（以 KBytes 为单位）的内存。
--- 如果步进完成了一个回收周期，则返回 **true**。
---
--- - **"setpause"**: 将 `arg` 设置为收集器 *pause* （参见 §2.5）的新值。
--- 返回 *pause* 的前一个值。
---
--- - **"incremental"**: 将收集器模式更改为增量模式。此选项后面可以跟三个数字：
--- 垃圾收集器暂停、步进倍率和步进大小。
---
--- - **"generational"**: 将收集器模式更改为分代模式。此选项后面可以跟两个数字：
--- 垃圾收集器次要倍率和主要倍率。
---
--- - **"isrunning"**: 返回一个布尔值，指示收集器是否正在运行（即未停止）。
--- @overload fun(opt: "param", param: std.collectgarbage.param, value: integer): integer
--- @param opt? std.collectgarbage_opt
--- @param ...  any
--- @return any
function collectgarbage(opt, ...) end

-- 省略
```

## 风格参考
```lua
--- 使用空格作为缩进样式
--- 缩进大小为 4
--- 使用单引号作为首选字符串引号样式

--- 模块加载如下所示
local std = require 'elxlibs.std'

--- 需要使用其他模块内容时优先 local 化 (参考：高频内容尤其注意，低频如std.class.new就很少进行local处理)
local widget_mod = require 'src.widgets.framework'
--- 尽量不要使用
local W = require('src.widgets.framework').Widget
--- 而是统一
local Widget = widget_mod.Widget


--- 使用 `std.class.new` 定义类型必须显式指定继承自 `std.object` 或你指定的继承自 `std.object` 的类型
---@class MyClass : std.object --- `std.object` 提供基础类型和函数信息
---@field prop type
---@field protected _protected_prop type
---@overload fun(options: _MyClassOptions):self; --- 为 `MyClass(...)` 提供类型提示，参数同 `__init`
local MyClass = std.class.new('MyClass')
function MyClass:__init(options)
    self.prop = options.prop
end

--- 注意给class注解 `@overload fun(options: _MyClassOptions):self` 可以解决 EmmyLua(call-non-callable)

--- 针对构造参形如 `init(..., options: table, ...)` 时应该类型化 `options`
--- 通用 `options` 名称构造 `_YourClassNameOptions`
---@class _MyClassOptions
---@field prop type

--- 技巧：当 `options` 属性全部为可选时可以直接使用 `Partial<_Options>` 包装

function MyClass:some(options)
    -- 尽量不使用如下格式
    self.some_a, self.some_b, self.some_c = options.a, options.b, options.c
    -- 平铺更利于阅读
    self.some_a = options.a
    self.some_b = options.b
    self.some_c = options.c
    -- Condition 不要过长
    if (self.some_a and self.some_b) or
        self.some_c then
        -- ok
    end
end

--- 函数声明使用 `function name() end`
--- 而不是 `name = function() end`
local function build()
    local rex = require 'elxlibs.rex'
    --- 使用 `call[[]]` 简化调用以及去除转义
    rex.safe_new[[\d+]]

    --- 使用 `call{}` 简化单options构造参类型的调用
    return MyClass{
        prop = ''
    }
end

--- 尽量不折叠块
function MyClass:copy() return MyClass({prop = self.prop}) end
--- 展开
function MyClass:copy()
    return MyClass({prop = self.prop})
end

--- 每个函数声明，只要不是 override 应该声明参数类型
---@param command string
function MyClass:command(command)
end

--- 进阶
---@generic T
---@param val T
---@return T[]
function MyClass:convert(val)
    return {val}
end

---@alias A<T> {some: T}
---@generic T
---@param t T
---@return A<T>
function MyClass.A(t)
    return {some = t}
end
local a = MyClass.A('a')
local some_a = a.some -- string

---@alias B<T> A<T> & {some_for_B: 'B'}
---@generic T
---@param t T
---@return B<T>
function MyClass.B(t)
    return {some = t, some_for_B = 'B'}
end
local b = MyClass.B('b')
local some_b = b.some -- string
local some_b_special = b.some_for_B -- 'B'


--- 枚举示例
---@alias EnumType
---| "A"
---| "B"
---| "C"

---@param e EnumType
local function useenum(e)
end
```

## 项目约束

以下规则是本项目的工程约束，不只是格式偏好：

1. **不使用文件级 `---@diagnostic disable` 掩盖生产代码问题**。优先补充
   `---@class`、`---@field`、`---@overload`、`---@param` 和 `---@return`；只有
   测试桩、第三方接口或已确认的 EmmyLua 限制才允许局部禁用，并必须靠近具体
   表达式且写明原因。
2. **每个 `std.class.new` 都要有明确的类型契约**：声明继承关系、实例字段和
   构造器 overload。Options 构造参数使用 `_TypeNameOptions`，字段按实际默认值
   标记可选；不要把类强转成无关的 `table` 或 `any`。
3. **构造函数不得修改调用方传入的 options 表**。默认值应写入新对象或浅复制的
   options；变体控件尤其不能通过 `options.style = ...`、`options.child = ...`
   等方式改变调用方数据。
4. **模块导入保持可读且无环**：先 `local module = require 'path'`，再提取需要的
   字段；避免 `require('path').Field`。聚合模块只能转出独立模块的同一对象，不能
   重复定义类。
5. **公共模块显式导出 API**。不要用无法推导类型的动态聚合表作为唯一类型来源；
   兼容聚合入口可以使用显式字段和返回类型声明。
6. **函数体保持展开**。不把构造函数、条件分支、循环、回调和方法压成单行；每个
   非 override 函数补齐参数和返回类型，复杂参数使用命名 alias。
7. **Widget 配置保持声明式和不可变**。Widget 构造后只读取配置；状态变化放在
   State，宿主副作用放在事件回调或生命周期方法，不在 build 中注册一次性资源。
8. **框架层保持宿主无关**。`foundation`、`layout`、`render`、`widget` 等目录不
   得依赖 `mp`；宿主交互通过明确的事件值对象和 owner 契约传递。
9. **每个新增公共控件同时提供行为测试和加载/聚合测试**。测试应验证用户可观察
   行为、边界状态和独立模块与兼容入口的 identity，而不是只验证内部字段。
10. **提交前必须运行**：`emmylua_check .`、`luajit test/run.lua`，以及受
    影响的 `uv run --group test python -m pytest -q test/real_host`；未运行的检查
    不得在文档或提交说明中宣称通过。
