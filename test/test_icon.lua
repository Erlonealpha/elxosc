-- Icon widget: a single glyph from the bundled icon font.
---@namespace test.icon

-- See the note in test_widget.lua: the `std.class` / optional-ownership
-- diagnostics are disabled across the suite.generic-constraint-mismatch
---@diagnostic disable: undefined-field, inject-field, need-check-nil, preferred-local-alias, unused

local F = require('framework')
local std = require('elxlibs.std')

local color = require('foundation.color')
local geometry = require('foundation.geometry')
local text_layout = require('text.text_layout')
local constraints_mod = require('layout.constraints')
local render_owner = require('render.render_owner')
local ass_canvas = require('backends.ass_canvas')
local record = require('backends.record')
local binding_mod = require('widget.binding')
local basic_widgets = require('widget.widgets.basic')
local icon_mod = require('widget.widgets.icon')
local player_mod = require('widget.player')
local icon_map = require('widget.player.icon_map')

local Color = color.Color
local Offset = geometry.Offset
local Constraints = constraints_mod.Constraints
local RenderOwner = render_owner.RenderOwner
local AssCanvas = ass_canvas.AssCanvas
local RecordCanvas = record.RecordCanvas
local WidgetBinding = binding_mod.WidgetBinding
local Icon = icon_mod.Icon
local IconButton = basic_widgets.IconButton

-- Matches `FluentIconFontName` in fonts/fluent_icon_names.lua.
local ICON_FONT = 'Material Symbols Rounded'

---@class FixedLayout : TextLayout
---@overload fun(): self
local FixedLayout = std.class.new('FixedLayout', text_layout.TextLayout)
function FixedLayout:line_width(line, style)
    return #line * style.font_size * 0.5
end
text_layout.set_default(FixedLayout())

---@param widget Widget
---@param constraints Constraints?
---@return RenderOwner
local function mount(widget, constraints)
    local owner = RenderOwner()
    WidgetBinding.ensure_initialized():attach(widget, owner)
    owner:set_viewport(constraints or Constraints.loose(400, 400))
    owner:layout()
    return owner
end

F.section('icon: construction')

F.test('ModernX semantic icons map to bundled Material Symbols glyphs', function()
    F.eq(icon_map.glyph_name('play'), 'play_arrow', 'play glyph')
    F.eq(icon_map.glyph_name('subtitle_off'), 'subtitles_off', 'subtitle off glyph')
    F.eq(icon_map.glyph_name('fullscreen_exit'), 'fullscreen_exit', 'fullscreen glyph')
    F.eq(icon_map.glyph_name('open_in_full'), 'open_in_full', 'bottom fullscreen glyph')
    F.eq(icon_map.glyph_name('close_fullscreen'), 'close_fullscreen', 'bottom fullscreen exit glyph')
    F.eq(icon_map.glyph_name('loop_on'), 'repeat_on', 'loop glyph')
    F.raises(function()
        ---@diagnostic disable-next-line: param-type-mismatch
        icon_map.glyph_name('missing')
    end,
        'unknown ModernX icon', 'unknown semantic icon is rejected')
    local mapped = icon_map.icon('play')
    F.eq(mapped.__class, Icon, 'icon factory returns Icon')
    F.eq(mapped.name, 'play_arrow', 'icon factory uses mapped glyph')
    F.eq(mapped.size, 30, 'play icon uses ModernX play/pause size')
    F.eq(mapped.fill, 0, 'Material Symbols fill axis')
    F.eq(mapped.weight, 400, 'Material Symbols weight axis')
    F.eq(mapped.grade, 0, 'Material Symbols grade axis')
    F.eq(mapped.optical_size, 24, 'Material Symbols optical size axis')
    F.eq(icon_map.spec('minimize').size, 18, 'window control size')
    F.eq(player_mod.glyph_name, icon_map.glyph_name, 'player aggregate preserves identity')
end)

F.test('defaults match the bundled icon font', function()
    local icon = Icon('play_arrow')
    F.eq(icon.name, 'play_arrow', 'glyph name')
    F.eq(icon.size, 24, 'default size')
    F.eq(icon.font_family, ICON_FONT, 'default icon font')
    F.eq(icon.color, Color.argb(0xFFFFFFFF), 'default colour')
    F.eq(icon.fill, 0, 'default fill axis')
    F.eq(icon.weight, 400, 'default weight axis')
    F.eq(icon.grade, 0, 'default grade axis')
    F.eq(icon.optical_size, 24, 'default optical size axis')
end)

F.test('options are read without mutating the caller table', function()
    local options = { size = 32, color = Color.rgba255(1, 2, 3), font_family = ICON_FONT }
    local icon = Icon('search', options)
    F.eq(icon.size, 32, 'custom size')
    F.eq(icon.color, Color.rgba255(1, 2, 3), 'custom colour')
    F.eq(options.size, 32, 'caller size retained')
    F.eq(options.color, Color.rgba255(1, 2, 3), 'caller colour retained')
    F.eq(options.font_family, ICON_FONT, 'caller family retained')
end)

F.test('Material Symbols axes reject values outside the font contract', function()
    F.raises(function()
        Icon('play_arrow', { fill = 2 })
    end, 'between 0 and 1', 'fill axis')
    F.raises(function()
        Icon('play_arrow', { weight = 99 })
    end, 'between 100 and 700', 'weight axis')
    F.raises(function()
        Icon('play_arrow', { grade = -26 })
    end, 'between -25 and 200', 'grade axis')
    F.raises(function()
        Icon('play_arrow', { optical_size = 49 })
    end, 'between 20 and 48', 'optical size axis')
end)

F.test('semantic icon options are merged without mutating caller options', function()
    local options = { color = Color.rgba255(1, 2, 3), weight = 500 }
    local icon = icon_map.icon('pause', options)
    F.eq(icon.size, 30, 'semantic size is retained')
    F.eq(icon.weight, 500, 'caller variation overrides the default')
    F.eq(options.weight, 500, 'caller variation retained')
    F.eq(options.size, nil, 'caller options are not populated')
end)

F.test('the class is shared across module and aggregate entry points', function()
    F.eq(icon_mod.Icon, Icon, 'direct module')
    F.eq(basic_widgets.Icon, Icon, 'basic aggregate')
    F.eq(require('widget').Icon, Icon, 'widget aggregate')
end)

F.section('icon: rendering')

F.test('builds a text glyph carrying the icon font family', function()
    local owner = mount(Icon('play_arrow', { size = 20 }))
    local glyph = owner.root:children()[1]:children()[1]
    local paragraph = glyph.paragraph
    F.eq(paragraph.text, 'play_arrow', 'glyph name reaches the paragraph')
    F.eq(paragraph.style.font_family, ICON_FONT, 'icon font family')
    F.eq(paragraph.style.font_size, 20, 'size drives the font size')
    F.eq(paragraph.style.wrap, false, 'icon glyphs never wrap')
    F.eq(paragraph.style.extra.type, 'material-symbols', 'variation intent type')
    F.eq(paragraph.style.extra.weight, 400, 'variation intent weight')
end)

F.test('uses the nominal box center even when the ligature name measures wider', function()
    local owner = mount(Icon('play_arrow', { size = 20 }))
    local glyph = owner.root:children()[1]:children()[1]
    local canvas = RecordCanvas()
    owner:paint(canvas)
    F.eq(owner.root.size.width, 20, 'nominal width')
    F.eq(owner.root.size.height, 20, 'nominal height')
    F.eq(glyph.paragraph.size.width, 100, 'natural ligature-name width')
    F.eq(canvas.ops[1][2], Offset(10, 10), 'paint target uses the constrained box center')
    F.eq(canvas.ops[1][3].anchor, 'center', 'center paint anchor')
end)

F.test('optical offset is paint data and does not change the nominal box', function()
    local owner = mount(Icon('play_arrow', {
        size = 20,
        optical_offset = Offset(1.5, -2),
    }))
    local glyph = owner.root:children()[1]:children()[1]
    local canvas = RecordCanvas()
    owner:paint(canvas)
    F.eq(owner.root.size.width, 20, 'offset keeps width')
    F.eq(owner.root.size.height, 20, 'offset keeps height')
    F.eq(canvas.ops[1][3].offset, Offset(1.5, -2), 'offset reaches TextPaint')
    F.eq(glyph.text_paint.anchor, 'center', 'icon anchor remains center')
end)

F.test('the nominal box remains subject to tighter parent constraints', function()
    local owner = mount(Icon('play_arrow', { size = 24 }), Constraints.tight(10, 12))
    F.eq(owner.root.size.width, 10, 'parent constrains width')
    F.eq(owner.root.size.height, 12, 'parent constrains height')
end)

F.test('paints the glyph with the icon font override', function()
    local owner = mount(Icon('play_arrow', {
        size = 20,
        color = Color.rgba255(0x10, 0x20, 0x30),
    }))
    local canvas = AssCanvas()
    owner:paint(canvas)
    local text = canvas:text()
    F.contains(text, '\\fn' .. ICON_FONT, 'font family override')
    F.contains(text, '\\fs20', 'font size override')
    F.contains(text, 'play_arrow', 'glyph ligature name')
    F.contains(text, '\\1c&H302010&', 'icon colour')
end)

F.test('semantic icon output keeps the mapped glyph and variation intent', function()
    local owner = mount(icon_map.icon('minimize'))
    local glyph = owner.root:children()[1]:children()[1]
    local canvas = RecordCanvas()
    owner:paint(canvas)
    F.eq(glyph.paragraph.text, 'minimize', 'mapped glyph reaches RecordCanvas')
    F.eq(glyph.paragraph.style.font_family, ICON_FONT, 'mapped font family')
    F.eq(glyph.paragraph.style.font_size, 18, 'mapped window control size')
    F.eq(glyph.paragraph.style.extra.fill, 0, 'mapped fill intent')

    local ass_owner = mount(icon_map.icon('minimize'))
    local ass = AssCanvas()
    ass_owner:paint(ass)
    F.contains(ass:text(), '\\fn' .. ICON_FONT, 'mapped ASS font family')
    F.contains(ass:text(), '\\fs18', 'mapped ASS size')
    F.contains(ass:text(), 'minimize', 'mapped ASS glyph')
end)

F.test('IconButton accepts an Icon as its child', function()
    local icon = Icon('play_arrow')
    local button = IconButton({ icon = icon })
    F.eq(button.child, icon, 'icon supplies the button child')
end)
