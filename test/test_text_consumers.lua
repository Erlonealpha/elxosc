-- Prepared Tooltip paragraphs and content-bounded player text controls.
---@namespace test.textConsumers
---@using elxosc
-- Inspection of persistent nodes uses the suite's std.class typing limitation.
---@diagnostic disable: undefined-field, inject-field, need-check-nil, preferred-local-alias
local F = require 'framework'
local std = require 'elxlibs.std'
local widgets = require 'widgets'
local text_mod = require 'src.text.text_layout'
local text_style_mod = require 'src.text.text_style'
local record_mod = require 'src.backends.record'
local render_mod = require 'src.render.render_owner'
local binding_mod = require 'src.widgets.widgets_binding'
local constraints_mod = require 'src.layout.constraints'
local geometry = require 'src.foundation.geometry'
local time_mod = require 'player.src.text_controls'
local player_mod = require 'player.src.context'
local player_app_mod = require 'player.src.ambients'
local player_layout_mod = require 'player.src.layout'
local player_theme_mod = require 'player.src.theme'
local actions_mod = require 'player.src.actions'
local RenderOwner = render_mod.RenderOwner
local Constraints = constraints_mod.Constraints
local Offset = geometry.Offset
local TextStyle = text_style_mod.TextStyle
local RecordCanvas = record_mod.RecordCanvas

---@class ConsumerLayout : TextLayout
---@field calls integer
---@field labels string[]
---@overload fun(): self
local ConsumerLayout = std.class.new('ConsumerLayout', text_mod.TextLayout)

function ConsumerLayout:__init()
    self.calls = 0
    self.labels = {}
end

function ConsumerLayout:line_width(line, style)
    self.calls = self.calls + 1
    self.labels[#self.labels + 1] = line
    local width = 0
    for index = 1, #line do
        width = width + (line:sub(index, index) == '1' and 4 or 8)
    end
    -- Mixed shaping can be wider than any repeated-digit candidate.
    if line == '12:34' then
        width = width + 12
    end
    return width
end

local function mount(widget, constraints)
    local owner = RenderOwner()
    local tree = binding_mod.WidgetsBinding.ensure_initialized():attach(widget, owner)
    owner:set_viewport(constraints or Constraints.tight(200, 30))
    owner:layout()
    owner:paint(RecordCanvas())
    return owner, tree
end

local function find(element, class)
    if element.widget.__class == class then
        return element
    end
    for _, child in ipairs(element:element_children()) do
        local found = find(child, class)
        if found then
            return found
        end
    end
end

F.section('text consumers: owner preparation')

F.test('ordered queue coalesces, cancels, preserves next-frame work and other errors', function()
    local owner = RenderOwner()
    local order = {}
    local function third()
        order[#order + 1] = 3
    end
    local function first()
        order[#order + 1] = 1
        owner:schedule_prepare(third)
        owner:flush_prepare()
    end
    local function second()
        order[#order + 1] = 2
        error('prepare failure')
    end
    owner:schedule_prepare(first)
    owner:schedule_prepare(first)
    owner:schedule_prepare(second)
    owner:schedule_prepare(third)
    owner:cancel_prepare(third)
    F.ok(not owner:needs_layout(), 'prepare does not invalidate layout')
    F.raises(function() owner:flush_prepare() end, 'prepare failure', 'first failure preserved')
    F.eq(table.concat(order, ','), '1,2', 'ordered once with cancellation')
    owner:flush_prepare()
    F.eq(table.concat(order, ','), '1,2,3', 'new preparation waits for next flush')
    owner:schedule_prepare(third)
    owner:dispose()
    owner:flush_prepare()
    F.eq(#order, 3, 'dispose releases queued callbacks')
end)

F.test('Tooltip prepares only final labels and paint never invokes measurement', function()
    local layout = ConsumerLayout()
    text_mod.set_default(layout)
    local root = widgets.Tooltip({ child = widgets.SizedBox({ width = 200, height = 30 }),
        text_for_point = function(point)
            return 'label-' .. math.floor(point.x)
        end,
        follow_pointer = true,
        style = TextStyle({ wrap = false }),
    })
    local owner, tree = mount(root)
    local regions = owner:region_snapshot()
    local calls = layout.calls
    owner:dispatch_pointer('move', Offset(10, 10))
    owner:dispatch_pointer('move', Offset(20, 10))
    owner:dispatch_pointer('move', Offset(30, 10))
    F.eq(layout.calls, calls, 'pointer callbacks do not measure')
    owner:paint(RecordCanvas())
    F.eq(layout.calls, calls, 'unprepared paint does not measure')
    owner:layout()
    F.eq(layout.labels[#layout.labels], 'label-30', 'only final label is prepared')
    F.eq(layout.calls, calls + 1, 'single unwrapped line measured once')
    local prepared_calls = layout.calls
    owner:mark_needs_paint()
    local canvas = RecordCanvas()
    owner:paint(canvas)
    F.eq(layout.calls, prepared_calls, 'painting uses prepared paragraph')
    local drawn
    for _, op in ipairs(canvas.ops) do
        if op.name == 'draw_text' then
            drawn = op[1].text
        end
    end
    F.eq(drawn, 'label-30', 'paint uses final text')
    owner:dispatch_pointer('move', Offset(30, 11))
    owner:layout()
    owner:paint(RecordCanvas())
    F.eq(layout.calls, prepared_calls, 'same label movement only paints')
    F.eq(owner:region_snapshot(), regions, 'prepare does not invalidate input geometry')
    F.ok(not tree.build_owner:has_dirty(), 'prepare does not rebuild widgets')
    owner:dispatch_pointer('move', Offset(40, 10))
    owner:dispatch_pointer('move', Offset(30, 10))
    owner:layout()
    F.eq(layout.calls, prepared_calls, 'returning to the prepared label cancels obsolete work')
    owner:dispatch_pointer('move', Offset(40, 10))
    tree:dispose()
    owner:flush_prepare()
    F.eq(layout.calls, prepared_calls, 'unmount cancels pending label')
end)

F.test('HoverText claims only content and clips long text without moving its anchor', function()
    local layout = ConsumerLayout()
    text_mod.set_default(layout)
    for _, x in ipairs({ 0, 1 }) do
        local clicks = 0
        local owner, tree = mount(widgets.HoverText({ text = 'abc', alignment = Offset(x, 0.5),
            style = TextStyle({ wrap = false }), on_tap = function() clicks = clicks + 1 end }))
        local region = owner:pointer_regions()[1]
        F.eq(region.rect:width(), 24, 'content width')
        F.eq(region.rect.left, x == 0 and 0 or 176, 'original left/right placement')
        local blank = Offset(x == 0 and 100 or 30, 15)
        F.ok(not owner:dispatch_pointer('down', blank, 'left'), 'blank part of region passes through')
        local point = Offset(region.rect.left + 12, 15)
        owner:dispatch_pointer('down', point, 'left')
        owner:dispatch_pointer('up', point, 'left')
        F.eq(clicks, 1, 'content still receives click')
        tree:dispose()
    end
    local owner, tree = mount(widgets.HoverText({ text = string.rep('a', 80),
        style = TextStyle({ wrap = false }), on_tap = function() end }), Constraints.tight(100, 30))
    local canvas = RecordCanvas()
    owner:mark_needs_paint()
    owner:paint(canvas)
    F.eq(canvas:count('clip_rect'), 1, 'overwide text clips to finite content box')
    F.eq(owner:pointer_regions()[1].rect:width(), 100, 'input remains within available width')
    tree:dispose()
end)

F.section('text consumers: player time widths')

F.test('time reservations respect proportional digits, shaped mixed labels and environment replacement', function()
    local layout = ConsumerLayout()
    local policy = time_mod.PlayerTimeWidth()
    local style = TextStyle({ font_size = 18, wrap = false })
    local first = policy:resolve(layout, '11:11', style)
    local second = policy:resolve(layout, '12:34', style)
    F.ok(second > first, 'actual mixed shaping expands the reservation')
    F.eq(policy:resolve(layout, '11:11', style), second, 'reservation does not shrink within template')
    F.ok(policy:resolve(layout, '01:23.456', style) > second, 'milliseconds use another template')
    F.ok(policy:resolve(layout, '−01:23 • LIVE', style) > second, 'sign/suffix are part of template')
    F.eq(policy:resolve(ConsumerLayout(), '11:11', style), first, 'new service resets observed reservation')
    F.eq(require('player').PlayerTimeWidth, time_mod.PlayerTimeWidth, 'player collector identity')
    F.eq(require('player').PlayerTimeTooltip, require('player.src.tooltip').PlayerTimeTooltip,
        'persistent time tooltip collector identity')
end)

F.test('time tooltip keeps its reservation state across parent Widget updates', function()
    local layout = ConsumerLayout()
    text_mod.set_default(layout)
    local PlayerTimeTooltip = require('player.src.tooltip').PlayerTimeTooltip
    local owner, tree = mount(PlayerTimeTooltip({ text = '11:11',
        child = widgets.SizedBox({ width = 200, height = 30 }) }))
    owner:dispatch_pointer('move', Offset(100, 10))
    owner:layout()
    local state = tree.root_element.state
    local width = state._width
    tree:set_root_widget(PlayerTimeTooltip({ text = '12:34',
        child = widgets.SizedBox({ width = 200, height = 30 }) }))
    tree:flush_build()
    owner:layout()
    F.ok(rawequal(tree.root_element.state, state), 'wrapper State survives updates')
    F.ok(rawequal(state._width, width), 'format reservation helper survives updates')
    tree:dispose()
end)

F.test('invalid Tooltip reservation errors during preparation while paint remains measurement-free', function()
    local layout = ConsumerLayout()
    text_mod.set_default(layout)
    local owner, tree = mount(widgets.Tooltip({ text = 'label',
        child = widgets.SizedBox({ width = 200, height = 30 }), width_for_text = function()
            return math.huge
        end }))
    owner:dispatch_pointer('move', Offset(100, 10))
    F.raises(function() owner:flush_prepare() end, 'finite non-negative width', 'reservation boundary')
    local calls = layout.calls
    owner:paint(RecordCanvas())
    F.eq(layout.calls, calls, 'failed preparation does not move native requests into paint')
    tree:dispose()
    F.raises(function() widgets.HoverText({ min_width = -1 }) end, 'finite and non-negative', 'invalid content width')
    F.raises(function()
        ---@diagnostic disable-next-line: param-type-mismatch
        widgets.Text('a', { clip = 'yes' })
    end, 'must be a boolean', 'clip option boundary')
end)

F.test('time toggles and metadata preview shrink inside original player regions', function()
    text_mod.set_default(ConsumerLayout())
    local store = player_mod.PlayerStore({ time_pos = 11, duration = 100, percent_pos = 11,
        file_size = 2048, media_title = 'short' })
    local owner, tree = mount(player_app_mod.PlayerApp({
        display = widgets.DisplaySnapshot({ width = 1280, height = 720, initialized = true }),
        child = player_mod.PlayerScope({ store = store, child = require('player.src.app').Main() }),
    }), Constraints.tight(1280, 720))
    local description = assert(find(tree.root_element, player_layout_mod.PlayerDescriptionLayer))
    local bounds = description.widget.bounds
    local points = owner:pointer_regions()
    ---@type Rect?
    local preview_region
    for _, region in ipairs(points) do
        if region.down and math.abs(region.rect.top - bounds.top) < 6
            and region.rect.left >= bounds.left and region.rect.right <= bounds.right then
            preview_region = region.rect
        end
    end
    F.ok(preview_region ~= nil, 'file size metadata has a content region')
    preview_region = assert(preview_region)
    F.ok(preview_region:width() < bounds:width(), 'file size preview does not fill allocated region')
    local blank = Offset(bounds.right - 2, bounds.top + bounds:height() / 2)
    owner:dispatch_pointer('down', blank, 'left')
    owner:dispatch_pointer('up', blank, 'left')
    tree:flush_build()
    F.ok(not description.state.open, 'preview blank does not open panel')
    local inside = Offset(preview_region.left + 3, preview_region.top + preview_region:height() / 2)
    owner:dispatch_pointer('down', inside, 'left')
    owner:dispatch_pointer('up', inside, 'left')
    tree:flush_build()
    F.ok(description.state.open, 'content opens size/description panel')
    description.state:handle_key('ESC')
    tree:flush_build()
    owner:layout()
    tree:dispose()
end)
