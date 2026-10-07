-- Text layer: TextStyle, the TextLayout contract and generic wrapping.

local F = require('framework')
local std = require('elxlibs.std')

local color = require('foundation.color')
local text_style = require('text.text_style')
local text_layout = require('text.text_layout')

local Color = color.Color
local TextStyle, Align = text_style.TextStyle, text_style.Align
local TextLayout = text_layout.TextLayout

-- A deterministic reference text backend: every glyph is half the font size
-- wide, so a 10px font is 5px per character.
---@class test.FixedLayout
---@overload fun():self
local FixedLayout = std.class.new('test.FixedLayout', { TextLayout })
function FixedLayout:line_width(line, style)
    return #line * style.font_size * 0.5
end

local function layout()
    return FixedLayout()
end

F.section('text: TextStyle')

F.test('has sensible defaults', function()
    local s = TextStyle()
    F.eq(s.font_size, 16, 'font size')
    F.eq(s.align, Align.LEFT, 'align')
    F.ok(s.wrap, 'wrap')
    F.close(s.line_height, 1.2, 'line height multiple')
    F.ok(s.color == Color.argb(0xFFFFFFFF), 'default colour is opaque white')
end)

F.test('accepts options and measures line height in px', function()
    local s = TextStyle(10, { bold = true, align = Align.CENTER, line_height = 2, color = Color(1, 0, 0) })
    F.ok(s.bold, 'bold')
    F.eq(s.align, Align.CENTER, 'align')
    F.close(s:line_height_px(), 20, 'line height px')
end)

F.test('copy_with derives new styles without mutating the source', function()
    local s = TextStyle(10, { bold = false })
    local t = s:copy_with({ bold = true, color = Color(1, 1, 1) })
    F.ok(t.bold, 'copy is bold')
    F.ok(not s.bold, 'source unchanged')
    F.eq(t.font_size, s.font_size, 'font size kept')
end)

F.section('text: TextLayout')

F.test('lays a single line out to its natural width', function()
    local p = layout():layout('hello', TextStyle(10))
    F.eq(p:line_count(), 1, 'one line')
    F.close(p.size.width, 25, 'width = 5 chars * 5px')
    F.close(p.size.height, 12, 'height = one line')
end)

F.test('wraps greedily at word boundaries', function()
    local p = layout():layout('hello world', TextStyle(10), 30)
    F.eq(p:line_count(), 2, 'wrapped into two lines')
    F.eq(p.lines[1], 'hello', 'first line')
    F.eq(p.lines[2], 'world', 'second line')
    F.close(p.size.width, 25, 'width is the widest line')
    F.close(p.size.height, 24, 'height is two lines')
end)

F.test('honours explicit line breaks', function()
    local p = layout():layout('a\nbb', TextStyle(10))
    F.eq(p:line_count(), 2, 'two hard lines')
    F.eq(p.lines[1], 'a', 'first hard line')
    F.eq(p.lines[2], 'bb', 'second hard line')
    F.close(p.size.width, 10, 'widest line')
end)

F.test('does not wrap when style.wrap is false', function()
    local p = layout():layout('hello world', TextStyle(10, { wrap = false }), 5)
    F.eq(p:line_count(), 1, 'single line')
    F.eq(p.lines[1], 'hello world', 'unwrapped')
end)

F.test('treats a nil max width as unbounded', function()
    local p = layout():layout('a very long line', TextStyle(10))
    F.eq(p:line_count(), 1, 'no wrapping without a bound')
end)

F.test('produces an empty paragraph for empty text', function()
    local p = layout():layout('', TextStyle(10))
    F.ok(p:is_empty(), 'empty')
    F.close(p.size.width, 0, 'width')
    F.close(p.size.height, 0, 'height')
end)

F.test('the base contract requires a backend', function()
    F.raises(function() TextLayout():line_width('x', TextStyle()) end,
        'NotImplementedError', 'line_width')
end)
