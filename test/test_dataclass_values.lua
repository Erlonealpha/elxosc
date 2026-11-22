---@namespace test.dataclassValues
---@using elxosc
local F = require 'framework'
local dc = require 'elxlibs.dataclass'
local Size = require('src.foundation.geometry').Size

F.section('independent value integration')
F.test('Size retains constructor, raw mutation, arithmetic and collector identity', function()
    local value = Size(nil, 3)
    F.eq(value.width, 0, 'nil default')
    F.eq(require('foundation').Size, Size, 'collector identity')
    F.ok(dc.isinstance(value, Size), 'independent type guard')
    F.eq(rawget(value, '__dict'), nil, 'direct mutable storage')
    value.width = 2
    F.eq(rawget(value, 'width'), 2, 'direct write')
    F.ok(value * 2 == Size(4, 6), 'arithmetic returns new value')
    F.eq(value.width, 2, 'receiver retained')
end)
