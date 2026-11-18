-- Original ranges, finite cluster wrapping, ellipsis and logical line painting.
---@namespace test.multilineText
---@using elxosc
-- Runtime class inspection follows the suite's std.class typing limitation.
---@diagnostic disable: undefined-field, inject-field, need-check-nil
local F = require 'framework'
local std = require 'elxlibs.std'
local text_mod = require 'src.text.text_layout'
local style_mod = require 'src.text.text_style'
local grapheme_mod = require 'src.text.grapheme'
local ass_mod = require 'src.backends.ass_canvas'
local geometry = require 'src.foundation.geometry'
local text_paint_mod = require 'src.painting.text_paint'
local widgets = require 'widgets'
local constraints_mod = require 'src.layout.constraints'
local record_mod = require 'src.backends.record'
local binding_mod = require 'src.widgets.widgets_binding'
local TextStyle = style_mod.TextStyle
local Offset = geometry.Offset
local TextPaint = text_paint_mod.TextPaint
local RecordCanvas = record_mod.RecordCanvas

---@class MultilineLayout : TextLayout
---@field calls string[]
---@overload fun(): self
local MultilineLayout = std.class.new('MultilineLayout', text_mod.TextLayout)

function MultilineLayout:__init()
    self.calls = {}
end

function MultilineLayout:line_width(line, style)
    self.calls[#self.calls + 1] = line
    return #grapheme_mod.clusters(line) * 10
end

F.section('multiline text: original ranges and boundaries')

F.test('text collector retains direct source identity', function()
    local public = require 'text'
    F.eq(public.clusters, grapheme_mod.clusters, 'cluster utility identity')
    F.eq(public.validate_utf8, grapheme_mod.validate_utf8, 'UTF-8 validator identity')
    F.eq(public.TextStyle, TextStyle, 'style identity')
    F.eq(public.TextLayout, text_mod.TextLayout, 'layout identity')
end)

F.test('preserves whitespace, tabs, hard breaks and trailing empty lines', function()
    local text = ' A  B\tC\r\n\nD\r'
    local paragraph = MultilineLayout():layout(text, TextStyle({ wrap = false }))
    F.eq(paragraph.text, text, 'original bytes retained')
    F.eq(paragraph.lines[1], ' A  B    C', 'tab expands four spaces, other whitespace retained')
    F.eq(paragraph.lines[2], '', 'explicit empty line')
    F.eq(paragraph.lines[3], 'D', 'CR is a hard break')
    F.eq(paragraph.lines[4], '', 'trailing break creates an empty line')
    F.eq(paragraph.line_metrics[1].start_byte, 1, 'one-based original range')
    F.eq(paragraph.line_metrics[1].end_byte, 8, 'original tab consumes one byte')
    F.eq(paragraph.line_metrics[2].start_byte, 10, 'CRLF consumes two original bytes')
    F.eq(paragraph.line_metrics[2].end_byte, 10, 'empty range is half-open')
    F.eq(paragraph.line_metrics[3].start_byte, 11, 'range after empty hard line')
    F.eq(paragraph.line_metrics[3].source, 'backend', 'generic backend provenance')
end)

F.test('wraps CJK and long words without deleting source characters', function()
    local layout = MultilineLayout()
    local cjk = '中文文本測試'
    local p = layout:layout(cjk, TextStyle(), 20)
    F.eq(#p.lines, 3, 'finite CJK wraps')
    F.eq(table.concat(p.lines), cjk, 'all original characters remain')
    F.eq(p.line_metrics[1].end_byte, 7, 'two CJK codepoints consume six bytes')
    local text = 'hello   world'
    local spaced = layout:layout(text, TextStyle(), 80)
    F.eq(spaced.lines[1], 'hello   ', 'all break whitespace retained')
    F.eq(spaced.lines[2], 'world', 'word remains together when it fits')
    F.eq(table.concat(spaced.lines), text, 'no normalization on soft wrap')
    local long = layout:layout('abcdefgh', TextStyle(), 30)
    F.eq(table.concat(long.lines, '/'), 'abc/def/gh', 'long unit breaks by safe clusters')
    F.eq(long.line_metrics[2].start_byte, 4, 'original range follows soft break')
end)

F.test('combining, emoji, flag and Hangul sequences stay in supported clusters', function()
    for _, unit in ipairs({ 'á', '👩‍💻', '👍🏽', '🇨🇳', '각', '각', '✈️' }) do
        F.eq(#grapheme_mod.clusters(unit), 1, 'one supported cluster: ' .. unit)
        local p = MultilineLayout():layout(unit .. 'X', TextStyle(), 5)
        F.eq(p.lines[1], unit, 'overwide cluster is not damaged: ' .. unit)
        F.eq(p.line_metrics[1].end_byte, #unit + 1, 'original byte boundary')
        F.eq(p.lines[2], 'X', 'next cluster on next line')
    end
    F.eq(#grapheme_mod.clusters('🇨🇳🇯🇵'), 2, 'regional indicators pair by flag')
    for _, invalid in ipairs({ '\128', '\192\175', '\237\160\128', '\244\144\128\128', '\226\128' }) do
        F.raises(function() MultilineLayout():layout(invalid, TextStyle()) end,
            'valid UTF-8', 'invalid encoding rejected')
    end
end)

F.test('max_lines and ellipsis keep visible prefixes mapped to original bytes', function()
    local layout = MultilineLayout()
    local p = layout:layout('abcdefgh', TextStyle({ max_lines = 1, overflow = 'ellipsis' }), 30)
    F.eq(p.lines[1], 'ab…', 'ellipsis participates in the final whole-line width')
    F.eq(p.line_metrics[1].width, 30, 'final visible width')
    F.eq(p.line_metrics[1].end_byte, 3, 'ellipsis adds no original bytes')
    F.ok(p.truncated and p.line_metrics[1].truncated, 'truncation visible in result')
    F.eq(p.text, 'abcdefgh', 'full source retained')
    local tight = layout:layout('ab', TextStyle({ wrap = false, overflow = 'ellipsis' }), 5)
    F.eq(tight.lines[1], '', 'narrower than ellipsis yields empty visible line')
    F.eq(tight.line_metrics[1].end_byte, 1, 'zero visible original prefix')
    local tab = layout:layout('A\tB\nC', TextStyle({ max_lines = 1, overflow = 'ellipsis', wrap = false }), 65)
    F.eq(tab.lines[1], 'A    …', 'tab is not split across source ranges')
    F.eq(tab.line_metrics[1].end_byte, 3, 'expanded tab retains original byte range')
    local visible = layout:layout('a\nb\nc', TextStyle({ max_lines = 2 }), 100)
    F.eq(#visible.lines, 2, 'line limit works with visible overflow')
    F.eq(visible.lines[2], 'b', 'visible mode does not synthesize ellipsis')
    F.ok(visible.truncated, 'line limit truncation reported')
end)

F.test('paragraph paint copies retain results and snapshot caller arrays', function()
    local p = MultilineLayout():layout('a\nb', TextStyle(), 40)
    local paint = p:with_style(p.style:copy_with({ bold = true }))
    F.eq(paint.line_metrics[2].start_byte, 3, 'ranges survive paint style copies')
    F.eq(paint.max_width, 40, 'layout bounds survive paint style copies')
    paint.lines[1] = 'changed'
    paint.line_metrics[1].width = 99
    F.eq(p.lines[1], 'a', 'line arrays are independent')
    F.eq(p.line_metrics[1].width, 10, 'metric records are independent')
    F.raises(function() TextStyle({ max_lines = 0 }) end, 'positive integer', 'zero line count')
    F.raises(function()
        ---@diagnostic disable-next-line: param-type-mismatch
        TextStyle({ max_lines = 1.5 })
    end, 'positive integer', 'fractional line count')
    F.raises(function()
        ---@diagnostic disable-next-line: param-type-mismatch
        TextStyle({ overflow = 'unknown' })
    end, 'visible, clip or ellipsis', 'closed overflow values')
    F.raises(function() MultilineLayout():layout('a', TextStyle(), -1) end, 'non-negative', 'negative width')
    F.raises(function()
        MultilineLayout():layout('a\nb', TextStyle({ font_size = 1e308, line_height = 1 }))
    end, 'height must be finite', 'finite row advances cannot overflow the paragraph boundary')
end)

F.test('line limits bound measurement and still validate hidden source bytes', function()
    local layout = MultilineLayout()
    local p = layout:layout(string.rep('word\n', 1000), TextStyle({ max_lines = 1 }))
    F.eq(#p.lines, 1, 'only visible row retained')
    F.eq(#layout.calls, 2, 'one extra row detects truncation without measuring hidden tail')
    F.raises(function()
        layout:layout('visible\nhidden\n\128', TextStyle({ max_lines = 1 }))
    end, 'valid UTF-8', 'hidden invalid bytes are not silently accepted')
    local long = MultilineLayout()
    local word = string.rep('a', 1000)
    local wrapped = long:layout(word, TextStyle(), 20)
    F.eq(table.concat(wrapped.lines), word, 'overlong unit remains lossless')
    local total_bytes = 0
    for _, candidate in ipairs(long.calls) do
        total_bytes = total_bytes + #candidate
    end
    F.ok(total_bytes < #word * 6, 'overlong unit is not remeasured in full for every row')
    local nbsp = MultilineLayout():layout('A B C', TextStyle(), 40)
    F.eq(nbsp.lines[1], 'A B ', 'NBSP stays within the word, ordinary space permits a break')
end)

F.test('ellipsis measures later prefixes after a wider shaped candidate', function()
    local layout = MultilineLayout()
    layout.line_width = function(_, line)
        local widths = { ['…'] = 10, ['a…'] = 40, ['ab…'] = 25, ['abc…'] = 45, abc = 50 }
        return widths[line] or 0
    end
    local p = layout:layout('abc', TextStyle({ wrap = false, overflow = 'ellipsis', letter_spacing = -2 }), 30)
    F.eq(p.lines[1], 'ab…', 'longest measured fitting prefix survives nonmonotonic widths')
    F.eq(p.line_metrics[1].end_byte, 3, 'selected prefix maps to original bytes')
    F.eq(p.line_metrics[1].width, 25, 'final result uses whole-shaped measurement')
    local limited = TextStyle({ max_lines = 2 })
    F.eq(limited:copy_with({ bold = true }).max_lines, 2, 'paint-style copies preserve the line limit')
    F.eq(limited:copy_with({ max_lines = nil }).max_lines, 2, 'nil preserves optional fields in copy_with')
end)

F.section('multiline text: static ASS line advances')

F.test('all anchors use logical line advances and preserve paint offsets', function()
    local p = MultilineLayout():layout('Hg\n\nHg', TextStyle({ font_size = 10, line_height = 2 }))
    for _, fixture in ipairs({
        { 'top_left', 7, 0 }, { 'top_center', 8, 0 }, { 'top_right', 9, 0 },
        { 'center_left', 4, 0.5 }, { 'center', 5, 0.5 }, { 'center_right', 6, 0.5 },
        { 'bottom_left', 1, 1 }, { 'bottom_center', 2, 1 }, { 'bottom_right', 3, 1 },
    }) do
        local canvas = ass_mod.AssCanvas()
        canvas:draw_text(p, Offset(100, 100), TextPaint({ anchor = fixture[1], offset = Offset(3, 4) }))
        F.eq(#canvas.events, 2, 'blank line keeps spacing without a glyph event')
        local x1, y1 = assert(canvas.events[1]):match('\\pos%((%-?%d+),(%-?%d+)%)')
        local x2, y2 = assert(canvas.events[2]):match('\\pos%((%-?%d+),(%-?%d+)%)')
        F.eq(tonumber(x1), 103, 'visual x offset preserved')
        F.eq(tonumber(x2), 103, 'line alignment shares the same horizontal anchor')
        F.eq(tonumber(y1), 114 - 60 * fixture[3], 'paragraph anchor determines logical top')
        F.eq(tonumber(y2) - tonumber(y1), 40, 'blank line advances two line heights')
        F.ok(not canvas:text():find('\\N', 1, true), 'backend does not use native line spacing')
    end
end)

F.test('clip overflow is paint-only and multiline layout changes reuse RenderText', function()
    local layout = MultilineLayout()
    local tree = binding_mod.WidgetsBinding.ensure_initialized():attach(widgets.Text('abc\ndef', {
        text_layout = layout, style = TextStyle({ overflow = 'clip' }),
    }))
    tree.render_owner:set_viewport(constraints_mod.Constraints.tight(15, 15))
    tree.render_owner:layout()
    local node = tree.render_owner.root
    local canvas = RecordCanvas()
    tree.render_owner:paint(canvas)
    F.eq(canvas:count('clip_rect'), 1, 'clip applies to the constrained render box')
    tree:set_root_widget(widgets.Text('abc\ndef', { text_layout = layout,
        style = TextStyle({ max_lines = 1, overflow = 'ellipsis' }) }))
    tree:flush_build()
    tree.render_owner:layout()
    -- layout/update mutates the owner root; retain explicit runtime identity check.
    ---@diagnostic disable-next-line: preferred-local-alias
    F.ok(rawequal(node, tree.render_owner.root), 'Text render node reused')
    F.eq(#node.paragraph.lines, 1, 'new line-limit contract applied')
    tree:dispose()
end)

F.test('Tooltip prepares bounded multiline text and renews it after a bounds update', function()
    local layout = MultilineLayout()
    local function root(width)
        return widgets.TextLayoutScope({ layout = layout, child = widgets.Tooltip({
            text = 'hello world\nsecond row', bounds_width = width, bounds_height = 300, margin = 0,
            style = TextStyle({ font_size = 10, line_height = 2, max_lines = 2, overflow = 'ellipsis' }),
            child = widgets.SizedBox({ width = 100, height = 20 }),
        }) })
    end
    local tree = binding_mod.WidgetsBinding.ensure_initialized():attach(root(80))
    tree.render_owner:set_viewport(constraints_mod.Constraints.tight(100, 20))
    tree.render_owner:layout()
    tree.render_owner:dispatch_pointer('move', Offset(10, 10))
    tree.render_owner:layout()
    local canvas = RecordCanvas()
    tree.render_owner:paint(canvas)
    local paragraph
    for _, op in ipairs(canvas.ops) do
        if op.name == 'draw_text' then
            paragraph = op[1]
        end
    end
    F.eq(paragraph.max_width, 80, 'Tooltip layout uses horizontal fit bounds')
    F.eq(#paragraph.lines, 2, 'Tooltip line limit is prepared')
    F.ok(paragraph.truncated, 'hidden rows are reported')
    local calls = #layout.calls
    tree.render_owner:mark_needs_paint()
    tree.render_owner:paint(RecordCanvas())
    F.eq(#layout.calls, calls, 'multiline paint performs no measurement')
    tree:set_root_widget(root(200))
    tree:flush_build()
    tree.render_owner:layout()
    local updated = RecordCanvas()
    tree.render_owner:paint(updated)
    for _, op in ipairs(updated.ops) do
        if op.name == 'draw_text' then
            F.eq(op[1].max_width, 200, 'bounds update renews the prepared layout')
            F.ok(not op[1].truncated, 'wider bounds retain both hard rows')
        end
    end
    tree:dispose()
end)
