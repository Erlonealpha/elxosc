-- Text layer: TextStyle, the TextLayout contract and generic wrapping.

-- See the note in test_widget.lua: the `std.class` / optional-ownership
-- diagnostics are disabled across the suite.
---@diagnostic disable: undefined-field, inject-field, need-check-nil, generic-constraint-mismatch, preferred-local-alias, unused

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
---@class test.FixedLayout : TextLayout
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
    local s = TextStyle({ font_size = 10, bold = true, align = Align.CENTER, line_height = 2, color = Color(1, 0, 0) })
    F.ok(s.bold, 'bold')
    F.eq(s.align, Align.CENTER, 'align')
    F.close(s:line_height_px(), 20, 'line height px')
end)

F.test('copy_with derives new styles without mutating the source', function()
    local s = TextStyle({ font_size = 10, bold = false })
    local t = s:copy_with({ bold = true, color = Color(1, 1, 1) })
    F.ok(t.bold, 'copy is bold')
    F.ok(not s.bold, 'source unchanged')
    F.eq(t.font_size, s.font_size, 'font size kept')
end)

F.test('fractional size and copied size affect logical line metrics', function()
    local options = { font_size = 10.5, wrap = false, bold = false, letter_spacing = -0.5 }
    local style = TextStyle(options)
    local overrides = { font_size = 20.25, line_height = 2 }
    local copy = style:copy_with(overrides)
    F.close(style:line_height_px(), 12.6, 'fractional logical line height')
    F.close(copy:line_height_px(), 40.5, 'copy uses the new font size')
    F.eq(copy.wrap, false, 'omitted wrap preserves false')
    F.eq(copy.bold, false, 'omitted bold preserves false')
    F.eq(copy.letter_spacing, -0.5, 'negative spacing is preserved')
    F.eq(style.font_size, 10.5, 'source size is unchanged')
    F.eq(options.font_size, 10.5, 'constructor options are unchanged')
    F.eq(options.color, nil, 'defaults are not added to constructor options')
    F.eq(overrides.wrap, nil, 'inherited values are not added to copy options')
    F.eq(overrides.font_size, 20.25, 'copy options are unchanged')
end)

F.test('copy_with preserves and overrides false and zero', function()
    local source = TextStyle({ bold = true, italic = true, wrap = true, letter_spacing = 2 })
    local zero = source:copy_with({
        font_size = 0,
        line_height = 0,
        letter_spacing = 0,
        bold = false,
        italic = false,
        wrap = false,
    })
    local copy = zero:copy_with()
    F.eq(copy.font_size, 0, 'zero size survives copying')
    F.eq(copy:line_height_px(), 0, 'zero logical line height')
    F.eq(copy.letter_spacing, 0, 'zero spacing')
    F.eq(copy.bold, false, 'bold can be disabled')
    F.eq(copy.italic, false, 'italic can be disabled')
    F.eq(copy.wrap, false, 'wrapping can be disabled')
    F.ok(source.bold and source.italic and source.wrap, 'source flags are unchanged')
end)

F.test('equality includes every style field and extension identity', function()
    local extra = { type = 'test.backend', scale_y = 2 }
    local source = TextStyle({ font_family = 'Example', extra = extra })
    F.ok(source == source:copy_with(), 'copy has equal values')
    F.ok(not rawequal(source, source:copy_with()), 'copy is a distinct instance')
    F.ok(rawequal(source:copy_with().extra, extra), 'opaque extension is shared')
    local changes = {
        { font_size = 20 },
        { color = Color(1, 0, 0) },
        { font_family = 'Another' },
        { bold = true },
        { italic = true },
        { letter_spacing = 1 },
        { line_height = 2 },
        { align = Align.RIGHT },
        { wrap = false },
        { extra = { type = 'test.backend', scale_y = 2 } },
    }
    for _, options in ipairs(changes) do
        F.ok(source ~= source:copy_with(options), 'changed field: ' .. next(options))
    end
    F.eq(extra.scale_y, 2, 'extension data is not mutated')
end)

F.test('rejects the old positional API and invalid option containers', function()
    F.raises(function()
        -- Deliberately call the removed positional API to check its runtime error.
        ---@diagnostic disable-next-line: param-type-mismatch
        TextStyle(10)
    end, 'options table', 'old positional size')
    F.raises(function()
        -- Invalid options must not be treated as defaults.
        ---@diagnostic disable-next-line: param-type-mismatch
        TextStyle(false)
    end, 'options table', 'false is not default options')
    F.raises(function()
        -- Exercise the same invalid boundary on copy_with.
        ---@diagnostic disable-next-line: param-type-mismatch
        TextStyle():copy_with('bad')
    end, 'options table', 'invalid copy options')
end)

F.test('rejects invalid style values at construction and copy boundaries', function()
    local cases = {
        { options = { font_size = '12' }, error = 'finite number' },
        { options = { font_size = false }, error = 'finite number' },
        { options = { font_size = -1 }, error = 'non-negative' },
        { options = { font_size = math.huge }, error = 'finite number' },
        { options = { font_size = 0 / 0 }, error = 'finite number' },
        { options = { line_height = -1 }, error = 'non-negative' },
        { options = { line_height = math.huge }, error = 'finite number' },
        { options = { font_size = 1e308, line_height = 2 }, error = 'line_height_px' },
        { options = { letter_spacing = -math.huge }, error = 'finite number' },
        { options = { bold = 1 }, error = 'boolean' },
        { options = { italic = 'yes' }, error = 'boolean' },
        { options = { wrap = 0 }, error = 'boolean' },
        { options = { color = false }, error = 'Color' },
        { options = { color = {} }, error = 'Color' },
        { options = { font_family = 123 }, error = 'string' },
        { options = { align = 'middle' }, error = 'align' },
        { options = { extra = 'ass' }, error = 'extra' },
        { options = { extra = { type = '' } }, error = 'extra' },
        { options = { extra = {} }, error = 'extra' },
        { options = { anchor_point = 5 }, error = 'unsupported TextStyle option' },
        { options = { border = 2 }, error = 'unsupported TextStyle option' },
    }
    local source = TextStyle()
    for _, case in ipairs(cases) do
        F.raises(function()
            -- Invalid fields intentionally violate the public options type.
            ---@diagnostic disable-next-line: param-type-mismatch
            TextStyle(case.options)
        end, case.error, 'constructor boundary')
        F.raises(function()
            -- Copying must validate the same invalid fields.
            ---@diagnostic disable-next-line: param-type-mismatch
            source:copy_with(case.options)
        end, case.error, 'copy boundary')
    end
end)

F.section('text: TextLayout')

F.test('the base line advance works without a width implementation', function()
    local style = TextStyle({ font_size = 10.5, line_height = 2 })
    F.close(TextLayout():line_height(style), 21, 'logical default is public')
    local paragraph = layout():layout('ab', style)
    F.close(paragraph.line_height, 21, 'width-only backends inherit the default')
    F.close(paragraph.size.height, 21, 'paragraph uses the same advance')
end)

F.test('a backend can override the uniform line advance', function()
    ---@class test.CustomLineHeight : test.FixedLayout
    ---@overload fun(): self
    local Backend = std.class.new('test.CustomLineHeight', { FixedLayout })
    function Backend:line_height(style)
        return style.font_size + 5
    end
    local style = TextStyle({ font_size = 10, line_height = 2 })
    local paragraph = Backend():layout('ab\nc d', style, 10)
    F.eq(paragraph:line_count(), 3, 'hard and soft breaks both participate')
    F.close(paragraph.line_height, 15, 'backend override')
    F.close(paragraph.size.height, 45, 'three uniform advances')
    F.close(style:line_height_px(), 20, 'style intent stays unchanged')
end)

F.test('rejects invalid backend line advances before returning a paragraph', function()
    ---@class test.InvalidLineHeight : test.FixedLayout
    ---@field height number|string|boolean
    ---@overload fun(): self
    local Backend = std.class.new('test.InvalidLineHeight', { FixedLayout })
    local backend = Backend()
    function Backend:line_height(style)
        -- Deliberately violate the backend contract to verify runtime rejection.
        ---@diagnostic disable-next-line: return-type-mismatch
        return self.height
    end
    for _, height in ipairs({ -1, math.huge, -math.huge, 0 / 0, '12', false }) do
        backend.height = height
        F.raises(function() backend:layout('x', TextStyle()) end,
            'line_height must return', 'invalid backend line advance')
    end
end)

F.test('lays a single line out to its natural width', function()
    local p = layout():layout('hello', TextStyle({ font_size = 10 }))
    F.eq(p:line_count(), 1, 'one line')
    F.close(p.size.width, 25, 'width = 5 chars * 5px')
    F.close(p.size.height, 12, 'height = one line')
end)

F.test('wraps greedily at word boundaries', function()
    local p = layout():layout('hello world', TextStyle({ font_size = 10 }), 30)
    F.eq(p:line_count(), 2, 'wrapped into two lines')
    F.eq(p.lines[1], 'hello', 'first line')
    F.eq(p.lines[2], 'world', 'second line')
    F.close(p.size.width, 25, 'width is the widest line')
    F.close(p.size.height, 24, 'height is two lines')
end)

F.test('honours explicit line breaks', function()
    local p = layout():layout('a\nbb', TextStyle({ font_size = 10 }))
    F.eq(p:line_count(), 2, 'two hard lines')
    F.eq(p.lines[1], 'a', 'first hard line')
    F.eq(p.lines[2], 'bb', 'second hard line')
    F.close(p.size.width, 10, 'widest line')
end)

F.test('does not wrap when style.wrap is false', function()
    local p = layout():layout('hello world', TextStyle({ font_size = 10, wrap = false }), 5)
    F.eq(p:line_count(), 1, 'single line')
    F.eq(p.lines[1], 'hello world', 'unwrapped')
end)

F.test('treats a nil max width as unbounded', function()
    local p = layout():layout('a very long line', TextStyle({ font_size = 10 }))
    F.eq(p:line_count(), 1, 'no wrapping without a bound')
end)

F.test('produces an empty paragraph for empty text', function()
    local p = layout():layout('', TextStyle({ font_size = 10 }))
    F.ok(p:is_empty(), 'empty')
    F.close(p.size.width, 0, 'width')
    F.close(p.size.height, 0, 'height')
end)

F.test('the base contract requires a backend', function()
    F.raises(function() TextLayout():line_width('x', TextStyle()) end,
        'NotImplementedError', 'line_width')
end)
