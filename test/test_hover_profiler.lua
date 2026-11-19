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
    local Offset = require('src.foundation.geometry').Offset
    local original = class_mod.object.__new
    local profiler = profiler_mod.new('class-count')
    profiler:start()
    Offset(1, 2)
    profiler:stop()
    local report = profiler:report()
    local restored = class_mod.object.__new
    F.eq(restored, original, 'original construction restored')
    F.eq(report.constructors.Offset.entries, 1, 'one instance entry counted')
    Offset(3, 4)
    F.eq(report.constructors.Offset.entries, 1, 'later oracle creation not counted')
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
