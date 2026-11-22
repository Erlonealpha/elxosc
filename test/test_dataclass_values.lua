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

F.test('TextPaint retains exact resolution, offsets and explicit anchor copies', function()
    local mod = require 'src.painting.text_paint'
    local Offset = require('src.foundation.geometry').Offset
    local value = mod.TextPaint({ offset = Offset(2, 3) })
    F.ok(dc.isinstance(value, mod.TextPaint), 'independent text paint guard')
    F.eq(mod.resolve(value), value, 'exact instance resolution')
    F.eq(value._anchor_explicit, false, 'default anchor intent')
    local copy = value:copy_with({ anchor = 'bottom_right' })
    F.eq(copy._anchor_explicit, true, 'explicit anchor intent')
    F.eq(copy.offset, value.offset, 'offset value retained')
    F.ok(not rawequal(copy, value), 'copy returns new value')
    --- Deliberately probe the exact-class boundary with an invalid plain table.
    ---@diagnostic disable-next-line: missing-fields, param-type-mismatch
    F.ok(not pcall(mod.resolve, {}), 'struct table rejected')
end)

F.test('Paint retains fresh defaults and copy Color identity', function()
    local Paint = require('src.painting.paint').Paint
    local value = Paint()
    local other = Paint()
    F.ok(dc.isinstance(value, Paint), 'independent paint guard')
    F.ok(not rawequal(value.color, other.color), 'default Color constructed per instance')
    value.stroke_width = 4
    local copied = value:copy()
    F.ok(not rawequal(value, copied), 'Paint copy is new')
    F.ok(rawequal(value.color, copied.color), 'copy retains Color reference')
    F.eq(copied.stroke_width, 4, 'current field copied')
    F.eq(require('painting').Paint, Paint, 'painting collector identity')
end)

F.test('generated Color initialization keeps channel defaults and rejects extra arguments', function()
    local Color = require('src.foundation.color').Color
    local value = Color(nil, nil, nil, nil)
    F.eq(value.r, 0, 'explicit nil channel default')
    F.eq(value.a, 1, 'explicit nil alpha default')
    --- Historical false input has channel defaults and preserves false alpha.
    ---@diagnostic disable-next-line: param-type-mismatch
    F.eq(Color(false, false, false, false).r, 0, 'false channel default')
    F.ok(not pcall(function()
        --- Boundary probe deliberately exceeds the generated constructor signature.
        ---@diagnostic disable-next-line: redundant-parameter
        Color(0, 0, 0, 1, 'extra')
    end), 'generated constructor rejects extra arguments')
end)

F.test('Color retains typed consumers, custom encoding and mutable channels', function()
    local Color = require('src.foundation.color').Color
    local TextStyle = require('src.text.text_style').TextStyle
    local value = Color(1, 0, 0)
    F.ok(dc.isinstance(value, Color), 'independent color guard')
    F.eq(TextStyle({ color = value }).color, value, 'typed color accepted')
    value.g = 0.5
    F.eq(rawget(value, 'g'), 0.5, 'mutable channel')
    F.ok(value:with_alpha(0) == Color(1, 0.5, 0, 0), 'custom value helper')
end)

F.test('Constraints retains infinity, zero bounds and direct mutable storage', function()
    local Constraints = require('src.layout.constraints').Constraints
    local value = Constraints()
    F.ok(dc.isinstance(value, Constraints), 'independent constraints guard')
    F.eq(require('layout').Constraints, Constraints, 'layout collector identity')
    F.eq(value.max_width, math.huge, 'default upper bound')
    F.eq(Constraints(0, 0, 0, 0).max_width, 0, 'zero bound retained')
    F.ok(Constraints.expand():has_infinite_width(), 'tight infinity retained')
    value.max_width = 7
    F.eq(rawget(value, 'max_width'), 7, 'direct mutation')
end)

F.test('Matrix2D keeps affine inverse and scalar mapping after type migration', function()
    local Matrix2D = require('src.foundation.transform').Matrix2D
    local Offset = require('src.foundation.geometry').Offset
    local matrix = Matrix2D(2, 1, 3, 4, 7, 6)
    F.ok(dc.isinstance(matrix, Matrix2D), 'independent matrix guard')
    F.eq(require('foundation').Matrix2D, Matrix2D, 'matrix collector identity')
    local point = matrix:transform_offset(Offset(1, 2))
    local inverse = assert(matrix:inverse())
    local restored = inverse:transform_offset(point)
    F.close(restored.x, 1, 'inverse x')
    F.close(restored.y, 2, 'inverse y')
end)

F.test('geometry values retain direct module identity and custom inherited comparison', function()
    local geometry = require 'src.foundation.geometry'
    for _, name in ipairs({ 'Offset', 'Point', 'Rect', 'EdgeInsets' }) do
        local cls = geometry[name]
        F.ok(dc.isinstance(cls(), cls), name .. ' independent guard')
        F.eq(require('foundation')[name], cls, name .. ' collector identity')
    end
    ---@class DerivedSize : Size
    ---@overload fun(width: number?, height: number?): self
    local DerivedSize = dc.new('DerivedSize', Size, { init = false, eq = false, repr = false })({})
    DerivedSize.__init = Size.__init
    dc.finish(DerivedSize)
    F.ok(dc.isinstance(DerivedSize(2, 3), Size), 'dataclass inheritance')
    F.ok(DerivedSize(2, 3) == Size(2, 3), 'custom inherited equality')
end)
