-- Scope accounting, return/exception semantics and reversible instrumentation.
---@namespace test.hoverProfiler
local F = require 'framework'
local profiler_mod = require 'tools.hover_profiler'

F.section('hover phase profiler')
F.test('nested scopes preserve nil/multiple returns and unwind thrown callbacks', function()
    local profiler = profiler_mod.new('phase')
    profiler:start()
    local first, second, third = profiler:call('outer', function()
        return profiler:call('inner', function() return nil, 3, 'last' end)
    end)
    F.eq(first, nil, 'leading nil retained')
    F.eq(second, 3, 'middle return retained')
    F.eq(third, 'last', 'last return retained')
    local ok = pcall(function()
        profiler:call('throws', function() error('expected profiler failure') end)
    end)
    F.ok(not ok, 'exception propagated')
    F.eq(#profiler.stack, 0, 'exception scope unwound')
    profiler:stop()
    local report = profiler:report()
    F.eq(report.phases['outer > inner'].calls, 1, 'nested call accounted once')
    F.ok(report.phases.outer.inclusive.mean_ms >= report.phases.outer.exclusive.mean_ms,
        'exclusive bounded by inclusive')
end)

F.test('class counter freezes before later objects and restores the creation method', function()
    local class_mod = require 'elxlibs.std.class'
    ---@class CountedStdValue : std.object
    ---@overload fun(): self
    local Value = class_mod.new('CountedStdValue')
    function Value:__init()
    end
    local original = class_mod.object.__new
    local profiler = profiler_mod.new('class-count')
    profiler:start()
    Value()
    profiler:stop()
    local report = profiler:report()
    local restored = class_mod.object.__new
    F.eq(restored, original, 'original construction restored')
    F.eq(report.constructors.CountedStdValue.entries, 1, 'one instance entry counted')
    Value()
    F.eq(report.constructors.CountedStdValue.entries, 1, 'later oracle creation not counted')
end)

F.test('wrapping restores inherited slot absence and rejects live export', function()
    local target = setmetatable({}, { __index = { callback = function() return 7 end } })
    local profiler = profiler_mod.new('phase')
    profiler:wrap(target, 'callback', 'callback')
    profiler:start()
    F.eq(target.callback(), 7, 'wrapped callback output')
    F.ok(not pcall(profiler.report, profiler), 'live report rejected')
    profiler:stop()
    F.eq(rawget(target, 'callback'), nil, 'inherited slot restored to nil')
end)

F.test('dataclass counter covers cached custom allocation and inherited init once per call', function()
    local dc = require 'elxlibs.dataclass'
    local init_calls = 0
    local new_calls = 0
    ---@class CountedValue
    ---@field value number
    ---@overload fun(value: number?): self
    local Value = dc.new('CountedValue', nil, { eq = false, repr = false })({
        dc.field('value', 0),
    })
    function Value:__init(value)
        init_calls = init_calls + 1
        self.value = value or 0
        if value == -1 then
            error('expected dataclass init failure')
        end
    end
    function Value.__new(cls)
        new_calls = new_calls + 1
        return dc.allocate(cls)
    end
    ---@class CountedChild : CountedValue
    ---@overload fun(value: number?): self
    local Child = dc.new('CountedChild', Value, { init = false, eq = false, repr = false })({})
    Child.__init = Value.__init
    dc.finish(Value)
    dc.finish(Child)
    local original = getmetatable(Child).__call
    local profiler = profiler_mod.new('class-count')
    profiler:track_dataclass(Child)
    profiler:track_dataclass(Child)
    Child(2)
    profiler:start()
    F.eq(Child(3).value, 3, 'cached init and custom new run normally')
    F.ok(not pcall(Child, -1), 'initializer failure propagated')
    dc.allocate(Child)
    profiler:stop()
    local report = profiler:report()
    F.eq(report.constructors.CountedChild.entries, 2, 'success and failure counted once')
    F.eq(init_calls, 3, 'no repeated inherited init')
    F.eq(new_calls, 3, 'no repeated custom allocator')
    F.eq(getmetatable(Child).__call, original, 'cached call restored')
    Child(4)
    F.eq(report.constructors.CountedChild.entries, 2, 'warmup and later calls excluded')
end)

F.test('dataclass registration leaves baseline call identity unchanged', function()
    local dc = require 'elxlibs.dataclass'
    ---@class UncountedValue
    local Value = dc.new('UncountedValue')({ dc.field('value', 0) })
    local original = getmetatable(Value).__call
    local profiler = profiler_mod.new('baseline')
    profiler:track_dataclass(Value)
    F.eq(getmetatable(Value).__call, original, 'baseline does not finish or wrap')
end)

F.test('recursive accounting and bounded-key failure leave a recoverable profiler', function()
    local profiler = profiler_mod.new('phase')
    profiler:start()
    local function recurse(depth)
        if depth > 0 then
            profiler:call('recursive', recurse, depth - 1)
        end
    end
    profiler:call('recursive', recurse, 2)
    F.eq(#profiler.stack, 0, 'recursive scopes unwound')
    profiler.max_keys = profiler.keys
    F.ok(not pcall(profiler.call, profiler, 'overflow', function() end), 'capacity failure explicit')
    profiler:stop()
end)
