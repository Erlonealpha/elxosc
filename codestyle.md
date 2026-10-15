# 代码风格参考
本项目使用Emmylua_ls作为类型提示和检查工具。

## 本次更新后的约定

- 普通模块导出表使用 `local M = {}`，依靠显式字段导出推导类型；不再为每个
  模块机械添加 `elx...` 的 `---@class`。真正的实例类、Options 和公共结构仍需
  明确的类型声明；模块表与实例类不能混为一谈。
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

- 模块导入、类型别名和局部字段分组时使用空行分隔，保持视觉层次清晰。
- 类声明的 `---@overload` 使用返回类型 `self` 表示构造器返回当前类；不要为
  `__init` 添加无意义的 `---@return nil`。
- 选项复制、默认样式等构造前处理放在局部 `config` 变量中，再传给父类构造器。
- 文件末尾保留一个换行；字段、类型别名和代码行末不保留空格。

## emmylua可用内置类型
来自：emmylua/builtin.lua
```lua
--- @meta no-require

-- Copyright (c) 2018. tangzx(love.tangzx@qq.com)
--
-- Licensed under the Apache License, Version 2.0 (the "License"); you may not
-- use this file except in compliance with the License. You may obtain a copy of
-- the License at
--
-- http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
-- WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
-- License for the specific language governing permissions and limitations under
-- the License.

-- Built-in Types

--- *nil* 类型只有一个值 **nil**，其主要特性是与任何其他值都不同；
--- 它通常表示缺少有用的值。
--- @class nil

--- *boolean* 类型有两个值：**false** 和 **true**。**nil** 和 **false**
--- 都会使条件为假；任何其他值都会使条件为真。
--- @class boolean

--- **number** 类型在内部使用两种表示形式，或称为两种子类型，一种叫做
--- *integer*，另一种叫做 *float*。Lua 对于何时使用哪种表示形式有明确的规则，
--- 但也会在需要时自动进行转换。因此，程序员可以选择忽略整数和浮点数之间的差异，
--- 也可以完全控制每个数字的表示形式。标准 Lua 使用 64 位整数和双精度（64 位）
--- 浮点数，但你也可以将 Lua 编译为使用 32 位整数和/或单精度（32 位）浮点数。
--- 对于小型机器和嵌入式系统来说，同时使用 32 位整数和 32 位浮点数的选项特别有吸引力。
--- （参见 `luaconf.h` 文件中的宏 `LUA_32BITS`。）
--- @class number

--- @class integer

--- *userdata* 类型用于允许将任意 C 数据存储在 Lua 变量中。userdata 值
--- 表示一块原始内存。有两种 userdata：*full userdata*，是一个由 Lua
--- 管理内存块的对象；*light userdata*，它仅是一个 C 指针值。userdata 在
--- Lua 中没有预定义的操作，除了赋值和相等性测试。通过使用 *metatables*，程序员
--- 可以为 full userdata 值定义操作。userdata 值不能在 Lua 中创建或修改，
--- 只能通过 C API 进行。这保证了宿主程序所拥有数据的完整性。
--- @class userdata

--- @class lightuserdata

--- *thread* 类型表示独立的执行线程，用于实现协程。Lua 线程与操作系统
--- 线程无关。Lua 在所有系统上都支持协程，即使是那些原生不支持线程的系统。
--- @class thread

--- *table* 类型实现关联数组，即索引不仅可以是数字，还可以是除 **nil**
--- 和 NaN 之外的任何 Lua 值的数组。（*NaN* 是 IEEE 754 标准用于表示
--- 未定义或不可表示的数值结果的特殊浮点值，例如 `0/0`。）表可以是异构的；
--- 也就是说，它们可以包含所有类型的值（除了 **nil**）。值为 **nil** 的
--- 任何键都不被视为表的一部分。相反，任何不属于表的键其关联值都为 **nil**。
---
--- 表是 Lua 中唯一的数据结构；它们可以用来表示普通数组、列表、符号表、
--- 集合、记录、图、树等。为了表示记录，Lua 使用字段名作为索引。语言通过
--- 提供 `a.name` 作为 `a["name"]` 的语法糖来支持这种表示。
---
--- 与索引一样，表字段的值可以是任何类型。特别地，由于函数是一等公民，表
--- 字段可以包含函数。因此表也可以携带 *methods*。
---
--- 表的索引遵循语言中原始相等的定义。表达式 `a[i]` 和 `a[j]` 当且仅当
--- `i` 和 `j` 原始相等（即不使用元方法的相等）时表示相同的表元素。特别地，
--- 具有整数值的浮点数等于其对应的整数。为避免歧义，任何用作键的具有整数值
--- 的浮点数都会转换为其对应的整数。例如，如果你写 `a[2.0] = true`，
--- 插入表中的实际键将是整数 `2`。（另一方面，2 和 "`2`" 是不同的 Lua 值，
--- 因此表示不同的表条目。）
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

## emmylua如何定义
来自：emmylua/global.lua
```lua
---@meta no-require
-- Copyright (c) 2018. tangzx(love.tangzx@qq.com)
--
-- Licensed under the Apache License, Version 2.0 (the "License"); you may not
-- use this file except in compliance with the License. You may obtain a copy of
-- the License at
--
-- http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
-- WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
-- License for the specific language governing permissions and limitations under
-- the License.

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

--- 打开指定的文件并将其内容作为 Lua 代码块执行。不带参数调用时，
--- `dofile` 执行标准输入（`stdin`）的内容。返回代码块返回的所有值。
--- 如果发生错误，`dofile` 将错误传播给调用者（即 `dofile` 不在保护模式下运行）。
--- @param filename? string
--- @return any ...
function dofile(filename) end

--- 终止最后调用的受保护函数，并将 `message` 作为错误对象返回。
--- Function `error` 永远不会返回。通常，如果消息是字符串，`error`
--- 会在消息开头添加一些关于错误位置的信息。`level` 参数指定如何获取
--- 错误位置。使用 level 1（默认值），错误位置是调用 `error` 函数的位置。
--- Level 2 将错误指向调用 `error` 的函数的调用位置；依此类推。
--- 传递 level 0 可以避免向消息添加错误位置信息。
--- @param message any
--- @param level?  integer
function error(message, level) end

--- 一个保存全局环境的全局变量（不是函数）。Lua 本身不使用此变量；
--- 更改其值不会影响任何环境，反之亦然。
--- @type global
_G = {}

--- 如果 `object` 没有元表，则返回 **nil**。否则，如果对象的元表
--- 具有 `"__metatable"` 字段，则返回关联的值。否则，返回给定对象的元表。
--- @param object any
--- @return any
function getmetatable(object) end

--- 返回三个值（一个迭代器函数、表 `t` 和 0），以便构造
--- > `for i,v in ipairs(t) do` *body* `end`
--- 将遍历键值对 (1,`t[1]`), (2,`t[2]`), ...，直到第一个不存在的索引。
--- @generic V
--- @param t V[] | table<int, V> | { [int]: V }
--- @return fun(tbl: any): int, V
function ipairs(t) end

--- @alias std.loadmode
--- | "b"  # 仅二进制块
--- | "t"  # 仅文本块
--- | "bt" # 二进制和文本块

--- 加载一个代码块。
--- 如果 `chunk` 是字符串，则代码块就是该字符串。如果 `chunk` 是函数，
--- `load` 会重复调用它以获取代码块片段。每次调用 `chunk` 必须返回
--- 一个与先前结果连接的字符串。返回空字符串、**nil** 或无值表示代码块结束。
---
--- 如果没有语法错误，则将编译后的代码块作为函数返回；
--- 否则，返回 **nil** 加上错误消息。
---
--- 如果生成的函数有上值，则第一个上值设置为 `env` 的值（如果给定了该参数），
--- 或者设置为全局环境的值。其他上值初始化为 **nil**。（当你加载主代码块时，
--- 生成的函数将始终只有一个上值，即 _ENV 变量。但是，当你加载从函数创建的
--- 二进制代码块时（参见 string.dump），生成的函数可以有任意数量的上值。）
--- 所有上值都是新的，即它们不与任何其他函数共享。
---
--- `chunkname` 用作错误消息和调试信息的代码块名称。如果省略，
--- 由于 `chunk` 是字符串，默认为 `chunk`，否则默认为 "=(load)"。
---
--- 字符串 `mode` 控制代码块是文本还是二进制（即预编译代码块）。
--- 它可以是字符串 "b"（仅二进制代码块）、"t"（仅文本代码块）
--- 或 "bt"（二进制和文本）。默认为 "bt"。
---
--- Lua 不检查二进制代码块的一致性。恶意构造的二进制代码块可能会导致解释器崩溃。
--- @param chunk      (fun(...: any): string) | Language<"Lua">
--- @param chunkname? string
--- @param mode?      std.loadmode
--- @param env?       table
--- @return_overload function chunk
--- @return_overload nil, string error_message
--- @nodiscard
function load(chunk, chunkname, mode, env) end

--- 从给定字符串加载代码块。
--- @version 5.1, JIT
--- @param text       Language<"Lua">
--- @param chunkname? string
--- @return_overload function chunk
--- @return_overload nil, string error_message
--- @nodiscard
function loadstring(text, chunkname) end

--- 类似于 `load`，但从文件 `filename` 获取代码块，或者如果没有给出文件名，
--- 则从标准输入获取。
--- @param filename? string
--- @param mode?     std.loadmode
--- @param env?      table
--- @return_overload function chunk
--- @return_overload nil, string error_message
function loadfile(filename, mode, env) end

--- @version 5.1, JIT
--- @param proxy boolean | table | userdata
--- @return userdata
function newproxy(proxy) end

--- @version 5.1, JIT
--- 创建一个模块。
--- @param name string
--- @param ...  any
function module(name, ...) end

--- 允许程序遍历表的所有字段。它的第一个参数是一个表，第二个参数是
--- 表中的一个索引。`next` 返回表的下一个索引及其关联的值。当使用 **nil**
--- 作为第二个参数调用时，`next` 返回初始索引及其关联的值。当使用最后一个索引
--- 调用，或者在空表中使用 **nil** 调用时，`next` 返回 **nil**。
--- 如果省略第二个参数，则将其解释为 **nil**。特别是，你可以使用 `next(t)`
--- 来检查表是否为空。
---
--- 索引枚举的顺序未指定，*即使对于数字索引也是如此*。（要按数字顺序
--- 遍历表，请使用数字 **for**。）
---
--- 如果在遍历过程中将任何值赋给表中不存在的字段，则 `next` 的行为未定义。
--- 但是，你可以修改现有字段。特别是，你可以将现有字段设置为 nil。
--- @generic K, V
--- @overload fun(table: table<K, V>): K?, V?
--- @param table  table<K, V> | V[] | { [K]: V }
--- @param index? K
--- @return K?, V?
function next(table, index) end

--- 如果 `t` 具有元方法 `__pairs`，则以 `t` 作为参数调用它，并返回该调用的前三个结果。
---
--- 否则，返回三个值：`next` 函数、表 `t` 和 `nil`，
--- 因此结构 `for k,v in pairs(t) do *body* end` 会遍历表 `t` 的所有键值对。
---
--- 关于在遍历过程中修改表的注意事项，请参见函数 `next`。
--- @generic K, V, I
--- @param t table<K, V> | V[] | { [K]: V }
--- @return (fun(tbl: table<I, V>, index: I?): K, V), table<I, V>, I?
function pairs(t) end

--- 以 *保护模式* 调用给定参数的函数 `f`。这意味着 `f` 内部的任何错误
--- 都不会传播；相反，`pcall` 会捕获错误并返回状态码。它的第一个结果是
--- 状态码（一个布尔值），如果调用成功且没有错误，则为 true。在这种情况下，
--- `pcall` 还会返回调用后的所有结果。如果发生任何错误，`pcall` 返回
--- **false** 加上错误消息。
--- @generic T, R
--- @param f   sync fun(...: T...): R...
--- @param ... T...
--- @return_overload true, R...
--- @return_overload false, string
function pcall(f, ...) end

--- 接收任意数量的参数，并使用 `tostring` 函数将它们转换为字符串，
--- 然后将它们的值打印到 `stdout`。`print` 不用于格式化输出，
--- 仅作为显示值的快速方式，例如用于调试。为了完全控制输出，
--- 请使用 `string.format` 和 `io.write`。
function print(...) end

--- 检查 `v1` 是否等于 `v2`，不调用 `__eq` 元方法。返回布尔值。
--- @param v1 any
--- @param v2 any
--- @return boolean
function rawequal(v1, v2) end

--- 获取 `table[index]` 的实际值，不调用 `__index` 元方法。`table`
--- 必须是一个表；`index` 可以是任何值。
--- @generic const T, const K
--- @param table T
--- @param index K
--- @return std.RawGet<T, K>
function rawget(table, index) end

--- @version >5.2
--- 返回对象 `v` 的长度，该对象必须是表或字符串，不调用任何元方法。返回一个整数。
--- @param v string | table
--- @return integer
function rawlen(v) end

--- 将 `table[index]` 的实际值设置为 `value`，不调用 `__newindex` 元方法。
--- `table` 必须是一个表，`index` 是除 **nil** 和 NaN 之外的任何值，
--- `value` 是任何 Lua 值。
--- @param table table
--- @param index any
--- @param value any
--- @return table
function rawset(table, index, value) end

--- 加载给定的模块。该函数首先在 'package.loaded' 表中查找 `modname`
--- 是否这就加载。如果是，则 `require` 返回存储在 `package.loaded[modname]`
--- 中的值。否则，它尝试为模块查找 *加载器*。
---
--- 为了查找加载器，`require` 由 `package.searchers` 序列引导。
--- 通过更改此序列，我们可以改变 `require` 查找模块的方式。
--- 以下解释基于 `package.searchers` 的默认配置。
---
--- 首先 `require` 查询 `package.preload[modname]`。如果它有值，
--- 该值（应该是一个函数）就是加载器。否则 `require` 使用存储在
--- `package.path` 中的路径搜索 Lua 加载器。如果这也失败，它使用
--- 存储在 `package.cpath` 中的路径搜索 C 加载器。如果这也失败，
--- 它尝试 *一体化* 加载器（参见 `package.loaders`）。
---
--- 一旦找到加载器，`require` 就会使用两个参数调用加载器：`modname`
--- 和一个取决于它如何获取加载器的额外值。（如果加载器来自文件，
--- 这个额外值就是文件名。）如果加载器返回任何非 nil 值，require
--- 将返回的值赋值给 `package.loaded[modname]`。如果加载器没有返回
--- 非 nil 值并且没有给 `package.loaded[modname]` 赋值，则 `require`
--- 将 true 赋值给该条目。在任何情况下，require 返回
--- `package.loaded[modname]` 的最终值。
---
--- 如果加载或运行模块时出现任何错误，或者找不到模块的任何加载器，
--- 则 `require` 引发错误。
--- @param modname string
--- @return any
function require(modname) end

--- 如果 `index` 是数字，则返回参数编号 `index` 之后的所有参数；
--- 负数从末尾开始索引（-1 是最后一个参数）。
--- 否则，`index` 必须是字符串 "#"，`select` 返回接收到的额外参数的总数。
--- @generic T, const Num: integer | '#'
--- @param index Num
--- @param ...   T...
--- @return std.Select<T..., Num>
function select(index, ...) end

--- @class std.metatable
--- @field __mode?      'v' | 'k' | 'kv'
--- @field __metatable? any
--- @field __tostring?  (fun(t): string)
--- @field __gc?        fun(t)
--- @field __add?       fun(t1, t2): any
--- @field __sub?       fun(t1, t2): any
--- @field __mul?       fun(t1, t2): any
--- @field __div?       fun(t1, t2): any
--- @field __mod?       fun(t1, t2): any
--- @field __pow?       fun(t1, t2): any
--- @field __unm?       fun(t): any
--- @field __idiv?      fun(t1, t2): any
--- @field __band?      fun(t1, t2): any
--- @field __bor?       fun(t1, t2): any
--- @field __bxor?      fun(t1, t2): any
--- @field __bnot?      fun(t): any
--- @field __shl?       fun(t1, t2): any
--- @field __shr?       fun(t1, t2): any
--- @field __concat?    fun(t1, t2): any
--- @field __len?       fun(t): integer
--- @field __eq?        fun(t1, t2): boolean
--- @field __lt?        fun(t1, t2): boolean
--- @field __le?        fun(t1, t2): boolean
--- @field __index?     table | fun(t, k): any
--- @field __newindex?  table | fun(t, k, v)
--- @field __call?      fun(t, ...): any...
--- @field __pairs?     fun(t): ((fun(t, k, v): any, any), any, any)
--- @field __close?     fun(t, errobj): any

-- NOTE: The actual implementation of setmetatable is provided by the language server

--- 为给定表设置元表。（要从 Lua 代码更改其他类型的元表，必须使用调试库。）
--- 如果 `metatable` 为 **nil**，则移除给定表的元表。如果原始元表
--- 具有 `"__metatable"` 字段，则引发错误。
---
--- 此函数返回 `table`。
--- @generic T: table
--- @param table     T
--- @param metatable std.metatable | table | nil
--- @return T
function setmetatable(table, metatable) end

--- 当不带 `base` 调用时，`tonumber` 尝试将其参数转换为数字。
--- 如果参数已经是数字或可转换为数字的字符串，则 `tonumber` 返回该数字；
--- 否则，返回 **nil**。
---
--- 字符串的转换可以根据 Lua 的词法约定产生整数或浮点数。（字符串可以有
--- 前导和尾随空格以及符号。）
---
--- 当带 `base` 调用时，e 必须是一个字符串，被解释为该进制的整数。
--- 进制可以是 2 到 36 之间的任何整数（含）。在 10 以上的进制中，
--- 字母 'A'（大写或小写）表示 10，'B' 表示 11，依此类推，'Z' 表示 35。
--- 如果字符串 `e` 不是给定进制的有效数字，则函数返回 **nil**。
--- @overload fun(e: string, base: integer): integer?
--- @param e any
--- @return number?
--- @nodiscard
function tonumber(e) end

--- 接收任何类型的值并将其转换为人类可读格式的字符串。（为了完全控制
--- 数字的转换方式，请使用 `string.format`）。
---
--- 如果 `v` 的元表具有 `__tostring` 字段，则 `tostring` 使用 `v`
--- 作为参数调用相应的值，并将调用的结果作为其结果。
--- @param v any
--- @return string
function tostring(v) end

--- @alias std.type
--- | "nil"
--- | "number"
--- | "string"
--- | "boolean"
--- | "table"
--- | "function"
--- | "thread"
--- | "userdata"

--- 返回其唯一参数的类型，编码为字符串。此函数的可能结果是 "`nil`"
--- （字符串，不是值 **nil**）、"`number`"、"`string`"、"`boolean`"、
--- "`table`"、"`function`"、"`thread`" 和 "`userdata`"。
--- @param v any
--- @return std.type type
function type(v) end

--- 一个保存包含运行 Lua 版本字符串的全局变量（不是函数）。
--- 此变量的当前值是 "`Lua 5.4`"。
_VERSION = "Lua 5.5"

--- 此函数类似于 `pcall`，只是它设置了一个新的消息处理程序 `msgh`。
--- @generic T, R
--- @param f    sync fun(...: T...): R...
--- @param msgh fun(err: any): any
--- @param ...  T...
--- @return boolean, R...
function xpcall(f, msgh, ...) end

--- @version 5.1, JIT
---
--- @generic const T, const Start: integer, const End: integer
--- @param i?   Start
--- @param j?   End
--- @param list T
--- @return std.Unpack<T, Start, End>
function unpack(list, i, j) end

--- @version >5.4
--- 发出一条警告，其消息由其所有参数（应为字符串）拼接而成。
---
--- 按照约定，以“@”开头的单段消息被视为控制消息，也就是发给警告系统本身的消息。
--- 具体来说，Lua 中的标准警告函数会识别控制消息“@off”，用于停止发出警告，
--- 以及“@on”，用于（重新）开始发出警告；它会忽略未知的控制消息。
--- @param msg1 string | number
--- @param ...  string | number
function warn(msg1, ...) end

--- @type string[]
arg = {}

--- 这是一个不正确的注解，但真正支持 _ENV 会完全破坏变量分析路径；目前将其视为一个全局变量。
--- @version >5.3
--- @type global
_ENV = {}

--- @version 5.1, JIT
--- 设置指定函数的环境。
--- @param f   function | integer 要设置环境的函数。
--- @param env table              要分配给函数的环境表。
function setfenv(f, env) end

--- @version 5.1, JIT
--- 检索指定函数的环境表。
--- @param f function | integer 要检索环境的函数。
--- @return table The 与给定函数关联的环境表。
function getfenv(f) end
```

## 风格参考
```lua
--- 使用空格作为缩进样式
--- 缩进大小为 4
--- 使用单引号作为首选字符串引号样式

--- 模块加载如下所示
local std = require 'elxlibs.std'

--- 需要使用其他模块内容时优先 local 化 (参考：高频内容尤其注意，低频如std.class.new就很少进行local处理)
local widget_mod = require 'widget.widget'
--- 尽量不要使用
local W = require('widget.widget').Widget
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
