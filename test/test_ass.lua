-- ASS backend: colour encoding, drawing emission and the estimating text
-- layout. The emitted strings are exactly what `osd-overlay` wants.

-- See the note in test_widget.lua: the `std.class` / optional-ownership
-- diagnostics are disabled across the suite.
---@diagnostic disable: undefined-field, inject-field, need-check-nil, generic-constraint-mismatch, preferred-local-alias, unused

local F = require('framework')

local geometry = require('foundation.geometry')
local color = require('foundation.color')
local anchor_mod = require('foundation.anchor')
local paint = require('painting.paint')
local path_mod = require('painting.path')
local text_paint_mod = require('painting.text_paint')
local text_style = require('text.text_style')
local ass_canvas = require('backends.ass_canvas')
local ass_text = require('backends.ass_text_layout')

local Offset, Size, Rect = geometry.Offset, geometry.Size, geometry.Rect
local Color = color.Color
local Anchor = anchor_mod.Anchor
local Paint, Style = paint.Paint, paint.Style
local Path = path_mod.Path
local TextPaint = text_paint_mod.TextPaint
local TextStyle = text_style.TextStyle
local AssCanvas = ass_canvas.AssCanvas
local AssTextLayout = ass_text.AssTextLayout

--== colour ================================================================

F.section('ass: colour encoding')

F.test('converts to ASS BGR digits and inverted alpha', function()
    local c = Color.rgba255(0x10, 0x20, 0x30, 0xFF)
    F.eq(ass_canvas.ass_rgb(c), '302010', 'BGR order, no alpha')
    F.eq(ass_canvas.ass_alpha(c), '00', 'opaque -> 00')
    F.eq(ass_canvas.ass_alpha(Color.rgba255(0, 0, 0, 0x80)), '7F', 'half -> 7F')
    F.eq(ass_canvas.ass_alpha(Color.rgba255(0, 0, 0, 0x00)), 'FF', 'transparent -> FF')
end)

--== shapes ================================================================

F.section('ass: shapes')

F.test('emits a filled rect as an ASS drawing event', function()
    local canvas = AssCanvas()
    canvas:draw_rect(Rect(10, 20, 30, 40), Paint(Color.rgba255(0x10, 0x20, 0x30, 0xFF)))
    F.eq(#canvas.events, 1, 'one event')
    local ev = canvas.events[1]
    F.contains(ev, '\\pos(0,0)', 'absolute coordinate space')
    F.contains(ev, '\\rDefault', 'reset to the neutral style')
    F.contains(ev, '\\p4', 'drawing mode')
    F.contains(ev, '\\1c&H302010&', 'fill colour')
    F.contains(ev, '\\1a&H00&', 'alpha')
    F.contains(ev, 'm 80 160 l 240 160 l 240 320 l 80 320 c', 'absolute coords, 8x')
    F.contains(ev, '{\\p0}', 'drawing closed')
end)

F.test('a stroked rect becomes an outline, not a fill', function()
    local canvas = AssCanvas()
    canvas:draw_rect(Rect(0, 0, 10, 10),
        Paint(Color.rgba255(0xFF, 0, 0, 0xFF), Style.STROKE, 4))
    local ev = canvas.events[1]
    F.contains(ev, '\\bord4', 'border width')
    F.contains(ev, '\\3c&H0000FF&', 'outline colour (BGR)')
    F.contains(ev, '\\1a&HFF', 'transparent fill')
end)

F.test('rounded rects and ovals use bezier segments', function()
    local canvas = AssCanvas()
    canvas:draw_rrect(Rect(0, 0, 40, 40), 10, Paint(Color(1, 1, 1)))
    canvas:draw_path(Path():add_oval(Rect(0, 0, 20, 20)), Paint(Color(1, 1, 1)))
    F.contains(canvas.events[1], ' b ', 'rrect has curves')
    F.contains(canvas.events[2], ' b ', 'oval has curves')
end)

F.test('a line is lowered to a filled quad honoring the stroke width', function()
    local canvas = AssCanvas()
    canvas:draw_line(Offset(0, 0), Offset(100, 0),
        Paint(Color(1, 1, 1), Style.STROKE, 4))
    local ev = canvas.events[1]
    F.contains(ev, '\\bord0', 'filled, not outlined')
    F.contains(ev, 'm 0 16 l 800 16 l 800 -16 l 0 -16 c', 'quad of width 4 (8x)')
end)

F.test('images are not supported by the ASS backend', function()
    local canvas = AssCanvas()
    F.raises(function() canvas:draw_image(nil, Rect(0, 0, 1, 1)) end,
        'NotImplementedError', 'draw_image')
end)

--== text ==================================================================

F.section('ass: text')

F.test('draws a paragraph with size, colour and line breaks', function()
    local canvas = AssCanvas()
    local layout = AssTextLayout()
    local paragraph = layout:layout('a\nb', TextStyle({ font_size = 10 }))
    canvas:draw_text(paragraph, Offset(5, 6))
    local ev = canvas.events[1]
    F.contains(ev, '\\pos(5,6)', 'anchored at the offset')
    F.contains(ev, '\\rDefault\\an7', 'reset + top-left alignment')
    F.contains(ev, '\\fs10', 'font size')
    F.contains(ev, '\\1c&HFFFFFF&', 'default white')
    F.contains(ev, 'a\\Nb', 'hard line break')
end)

F.test('text positioning uses the translated logical top-left', function()
    local style = TextStyle({ font_size = 12.5, bold = true, italic = true })
    local original = style:copy_with()
    local paragraph = AssTextLayout():layout('ab', style)
    local canvas = AssCanvas()
    canvas:translate(10, 20)
    canvas:draw_text(paragraph, Offset(5, 6))
    F.contains(canvas:text(), '\\pos(15,26)\\rDefault\\an7\\blur0', 'top-left after translation')
    F.contains(canvas:text(), '\\fs12.5', 'fractional font size is retained')
    F.contains(canvas:text(), '\\b1\\i1', 'bold and italic have their own tags')
    F.contains(canvas:text(), '\\bord0\\shad0', 'bold does not create a border')
    F.eq(style, original, 'painting does not change style values')
end)

F.test('maps every backend-neutral anchor to the corresponding ASS anchor', function()
    local paragraph = AssTextLayout():layout('x', TextStyle({ font_size = 10 }))
    local expected = {
        { Anchor.TOP_LEFT, 7 },
        { Anchor.TOP_CENTER, 8 },
        { Anchor.TOP_RIGHT, 9 },
        { Anchor.CENTER_LEFT, 4 },
        { Anchor.CENTER, 5 },
        { Anchor.CENTER_RIGHT, 6 },
        { Anchor.BOTTOM_LEFT, 1 },
        { Anchor.BOTTOM_CENTER, 2 },
        { Anchor.BOTTOM_RIGHT, 3 },
    }
    for _, case in ipairs(expected) do
        local canvas = AssCanvas()
        canvas:draw_text(paragraph, Offset(20, 30), TextPaint({ anchor = case[1] }))
        F.contains(canvas:text(), '\\pos(20,30)\\rDefault\\an' .. case[2],
            'anchor ' .. case[1])
    end
end)

F.test('applies a text visual offset once in the active canvas transform', function()
    local paragraph = AssTextLayout():layout('x', TextStyle({ font_size = 10 }))
    local canvas = AssCanvas()
    canvas:translate(10, 20)
    canvas:scale(2)
    canvas:draw_text(paragraph, Offset(5, 6), TextPaint({ offset = Offset(2, 3) }))
    F.contains(canvas:text(), '\\pos(24,38)', 'offset is transformed with the target')
end)

F.test('the default text paint remains top-left compatible', function()
    local paragraph = AssTextLayout():layout('x', TextStyle({ font_size = 10 }))
    local canvas = AssCanvas()
    canvas:draw_text(paragraph, Offset(4, 5))
    F.contains(canvas:text(), '\\pos(4,5)\\rDefault\\an7', 'omitted paint')
end)

--== transforms / clipping =================================================

F.section('ass: transforms and clipping')

F.test('translate moves subsequent geometry', function()
    local canvas = AssCanvas()
    canvas:translate(10, 5)
    canvas:draw_rect(Rect(0, 0, 5, 5), Paint(Color(1, 1, 1)))
    F.contains(canvas.events[1], 'm 80 40', 'translated geometry')
end)

F.test('save / restore preserves the transform', function()
    local canvas = AssCanvas()
    canvas:translate(10, 0)
    canvas:save()
    canvas:translate(100, 0)
    canvas:restore()
    canvas:draw_rect(Rect(0, 0, 5, 5), Paint(Color(1, 1, 1)))
    F.contains(canvas.events[1], 'm 80 0', 'back to the saved transform')
end)

F.test('clip_rect is applied to later events', function()
    local canvas = AssCanvas()
    canvas:clip_rect(Rect(0, 0, 50, 50))
    canvas:draw_rect(Rect(0, 0, 10, 10), Paint(Color(1, 1, 1)))
    F.contains(canvas.events[1], '\\clip(0,0,50,50)', 'clip tag')
end)

F.test('reset clears the frame', function()
    local canvas = AssCanvas()
    canvas:draw_rect(Rect(0, 0, 1, 1), Paint(Color(1, 1, 1)))
    canvas:reset()
    F.eq(#canvas.events, 0, 'events cleared')
    F.eq(canvas:text(), '', 'empty payload')
end)

--== estimating text layout ================================================

F.section('ass: text layout')

F.test('estimates latin and wide glyph widths', function()
    local layout = AssTextLayout()
    F.close(layout:line_width('abc', TextStyle({ font_size = 10 })), 15, 'three latin glyphs')
    F.close(layout:line_width('中文', TextStyle({ font_size = 10 })), 20, 'two wide glyphs')
    F.close(layout:line_width('', TextStyle({ font_size = 10 })), 0, 'empty line')
end)

F.test('wraps through the shared TextLayout logic', function()
    local paragraph = AssTextLayout():layout('hello world', TextStyle({ font_size = 10 }), 30)
    F.eq(paragraph:line_count(), 2, 'wrapped')
    F.eq(paragraph.lines[1], 'hello', 'first line')
end)

F.test('logical line height is independent of opaque paint extensions', function()
    local style = TextStyle({ font_size = 10.5, line_height = 2, extra = { type = 'ass', scale_y = 4 } })
    local paragraph = AssTextLayout():layout('a\nb', style)
    F.close(paragraph.line_height, 21, 'ASS inherits the logical default')
    F.close(paragraph.size.height, 42, 'two logical lines')
    local canvas = AssCanvas()
    canvas:draw_text(paragraph, Offset.zero())
    F.contains(canvas:text(), 'a\\Nb', 'multi-line event retains hard breaks')
    F.ok(not canvas:text():find('\\fscy', 1, true), 'ASS does not silently consume extra scale')
end)
