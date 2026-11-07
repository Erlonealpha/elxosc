-- ModernX original/reduced root-relative player geometry and theme profiles.
---@namespace test.playerlayout
---@diagnostic disable: undefined-field, inject-field, need-check-nil, preferred-local-alias, unused

local F = require('framework')
local std = require('elxlibs.std')

local geometry = require('foundation.geometry')
local constraints_mod = require('layout.constraints')
local text_layout = require('text.text_layout')
local render_owner = require('render.render_owner')
local binding_mod = require('widget.binding')
local app_mod = require('widget.app')
local ambient_mod = require('widget.ambient')
local actions_mod = require('widget.actions')
local player_context = require('widget.player_context')
local player_layout_mod = require('widget.player.layout')
local player_theme_mod = require('widget.player.theme')
local progress_mod = require('widget.player.progress_bar')
local tooltip_mod = require('widget.player.tooltip')
local record_mod = require('backends.record')
local ass_mod = require('backends.ass_canvas')

local Rect = geometry.Rect
local Size = geometry.Size
local Constraints = constraints_mod.Constraints
local RenderOwner = render_owner.RenderOwner
local WidgetBinding = binding_mod.WidgetBinding
local WidgetsApp = app_mod.WidgetsApp
local DisplaySnapshot = ambient_mod.DisplaySnapshot
local HostActions = actions_mod.HostActions
local Main = require('widget.player.app').Main
local PlayerStore = player_context.PlayerStore
local PlayerScope = player_context.PlayerScope
local PlayerLayout = player_layout_mod.PlayerLayout
local PlayerThemeData = player_theme_mod.PlayerThemeData
local ProgressBar = progress_mod.ProgressBar
local PlayerTooltip = tooltip_mod.PlayerTooltip
local PlayerDescriptionLayer = player_layout_mod.PlayerDescriptionLayer
local RecordCanvas = record_mod.RecordCanvas
local AssCanvas = ass_mod.AssCanvas

---@class FixedLayout : TextLayout
---@overload fun(): self
local FixedLayout = std.class.new('FixedLayout', text_layout.TextLayout)
function FixedLayout:line_width(line, style)
    return #line * style.font_size * 0.5
end
text_layout.set_default(FixedLayout())

local function mount(widget)
    local owner = RenderOwner()
    local binding = WidgetBinding.ensure_initialized():attach(widget, owner)
    owner:set_viewport(Constraints.tight(1280, 720))
    owner:layout()
    return owner, binding
end

local function find_widget_element(element, widget_class)
    if element == nil then
        return nil
    end
    if element.widget and element.widget.__class == widget_class then
        return element
    end
    for _, child in ipairs(element:element_children()) do
        local found = find_widget_element(child, widget_class)
        if found then
            return found
        end
    end
    return nil
end

local function find_widget_elements(element, widget_class, result)
    result = result or {}
    if element == nil then
        return result
    end
    if element.widget and element.widget.__class == widget_class then
        result[#result + 1] = element
    end
    for _, child in ipairs(element:element_children()) do
        find_widget_elements(child, widget_class, result)
    end
    return result
end

F.section('player layout: theme and geometry')

F.test('player component extraction preserves public module identity', function()
    F.eq(require('widget.player.geometry').geometry_for, player_layout_mod.geometry_for,
        'geometry remains the same function through the compatibility entry')
    F.eq(require('widget.player.description').PlayerDescriptionLayer, PlayerDescriptionLayer,
        'description class remains the same object through layout')
    F.eq(require('widget.player').PlayerDescriptionLayer, PlayerDescriptionLayer,
        'player aggregate exports the direct description class')
end)

F.test('window controls and title use the top-edge ModernX placement', function()
    local result = player_layout_mod.geometry_for('original', 1280, 720, {})
    F.eq(result.window_controls.top, 0, 'window controls have no extra top margin')
    F.eq(result.window_controls.bottom, 30, 'window controls retain the original height')
    F.eq(result.window_title.top, 0, 'window title shares the top row')
end)

F.test('blurred backgrounds cross viewport edges without an internal edge line', function()
    local visuals = require('widget.player.visuals')
    local theme = PlayerThemeData()
    for _, top in ipairs({ true, false }) do
        local canvas = RecordCanvas()
        local background = visuals.panel(theme, theme.controller_color,
            theme.controller_border_color, 75, top)
        background.draw(canvas, geometry.Offset(0, 0), Size(1280, 720))
        local edge = canvas.ops[1][1]
        F.ok(edge.left < 0 and edge.right > 1280, 'blurred corners extend beyond horizontal edges')
        F.ok(top and edge.bottom < 0 or not top and edge.top >= 720,
            'gradient source remains outside the visible viewport')
    end
end)

F.test('volume icons distinguish zero volume from mute', function()
    local icon_class = require('widget.widgets.icon').Icon
    for _, fixture in ipairs({
        { volume = 100, mute = false, icon = 'volume_up' },
        { volume = 50, mute = false, icon = 'volume_down' },
        { volume = 0, mute = false, icon = 'volume_mute' },
        { volume = 100, mute = true, icon = 'volume_off' },
    }) do
        local owner, binding = mount(WidgetsApp({
            actions = HostActions({ toggle_mute = function() end }),
            display = DisplaySnapshot({ width = 1280, height = 720, initialized = true }),
            child = PlayerScope({ store = PlayerStore(fixture), child = Main() }),
        }))
        local found = false
        for _, element in ipairs(find_widget_elements(binding.root_element, icon_class)) do
            if element.widget.name == fixture.icon then
                found = true
            end
        end
        F.ok(found, 'volume state paints ' .. fixture.icon)
        binding:dispose()
        owner:dispose()
    end
end)

F.test('disabled player controls are translucent and do not claim click input', function()
    local icon_buttons = require('widget.widgets.icon_button').IconButton
    local render_text_class = require('render.text').RenderText
    local owner, binding = mount(WidgetsApp({
        display = DisplaySnapshot({ width = 1280, height = 720, initialized = true }),
        child = Main(),
    }))
    local previous
    for _, element in ipairs(find_widget_elements(binding.root_element, icon_buttons)) do
        if element.widget.key == 'player-playlist_prev' then
            previous = element
        end
    end
    F.ok(previous ~= nil, 'unavailable playlist control remains visible')
    if previous == nil then
        return
    end
    local function find_text(node)
        if node.__class == render_text_class then
            return node
        end
        for _, child in ipairs(node:children()) do
            local found = find_text(child)
            if found then
                return found
            end
        end
    end
    local text = find_text(previous:first_render_object())
    F.close(text.color_override.a, 40 / 255, 'disabled glyph uses ModernX alpha 215')
    local geometry_result = player_layout_mod.geometry_for('original', 1280, 720, {
        chapter_skip_buttons = true, track_nextprev_buttons = true,
    })
    local point = geometry.Offset(geometry_result.center.playlist_prev.left + 5, 680)
    F.ok(not owner:dispatch_pointer('down', point, 'left'), 'disabled control leaves clicks unclaimed')
end)

F.test('tooltip moves paint directly with stable layout, input and child identity', function()
    local store = PlayerStore({ duration = 100, percent_pos = 25 })
    local owner, binding = mount(WidgetsApp({
        actions = HostActions({ seek_to = function() end }),
        display = DisplaySnapshot({ width = 1280, height = 720, initialized = true }),
        child = PlayerScope({ store = store, child = Main() }),
    }))
    local progress = find_widget_element(binding.root_element, ProgressBar)
    local identity = progress.render_object
    local snapshot = owner:region_snapshot()
    owner:paint(AssCanvas())
    owner:dispatch_pointer('move', geometry.Offset(400, 615))
    local function tooltip_draw(canvas)
        for _, op in ipairs(canvas.ops) do
            if op.name == 'draw_text' and op[1].text == '00:30' then
                return op
            end
        end
    end
    local canvas = RecordCanvas()
    owner:paint(canvas)
    local first = tooltip_draw(canvas)
    F.ok(first ~= nil, 'time tooltip paints without a build flush')
    F.eq(first[3].anchor, 'bottom_center', 'tooltip bottom is anchored at the timeline top')
    F.eq(first[2].y, 612, 'tooltip is adjacent to the timeline')
    owner:dispatch_pointer('move', geometry.Offset(410, 619))
    F.ok(not binding.build_owner:has_dirty(), 'hover does not schedule Widget rebuilds')
    F.ok(not owner:needs_layout(), 'hover does not relayout the player')
    F.eq(owner:region_snapshot(), snapshot, 'tooltip motion reuses the input snapshot')
    F.eq(progress.render_object, identity, 'seekbar capture target identity stays stable')
    local next_canvas = RecordCanvas()
    owner:paint(next_canvas)
    local second
    for _, op in ipairs(next_canvas.ops) do
        if op.name == 'draw_text' and op[3].anchor == 'bottom_center' then
            second = op
        end
    end
    F.eq(second[2].y, first[2].y, 'vertical mouse movement does not move the tooltip')
    owner:dispatch_pointer('move', geometry.Offset(0, 300))
    local hidden_canvas = RecordCanvas()
    owner:paint(hidden_canvas)
    local found = false
    for _, op in ipairs(hidden_canvas.ops) do
        if op.name == 'draw_text' and op[3].anchor == 'bottom_center' then
            found = true
        end
    end
    F.ok(not found, 'leave clears the tooltip without rebuilding')
end)

F.test('PlayerThemeData freezes ModernX original defaults', function()
    local theme = PlayerThemeData()
    F.eq(theme.layout_option, 'original', 'original is the default layout')
    F.eq(theme.controller_height, 180, 'controller height')
    F.eq(theme.title_font_size, 28, 'title size')
    F.eq(theme.time_font_size, 18, 'time size')
    F.eq(theme.playpause_size, 30, 'play/pause size')
    F.eq(theme.middle_button_size, 24, 'middle control size')
    F.eq(theme.window_control_size, 18, 'window control size')
    F.eq(theme.window_control_color, theme.title_color, 'window control color')
    F.close(theme.seek_range_color.a, 175 / 255, 'ModernX cache-range alpha')
    F.eq(theme.controller_border_width, 100, 'ModernX controller edge width')
    F.eq(theme.window_border_width, 100, 'ModernX window edge width')
    F.eq(theme.controller_blur_radius, 75, 'ModernX controller blur strength')
    F.eq(theme.window_blur_radius, 75, 'ModernX window blur strength')
    F.eq(theme.hover_scale, 1.15, 'hover scale')
    F.eq(theme.thumbnail_border, 1, 'thumbnail border is one physical pixel')
    F.eq(theme.thumbnail_border_radius, 5, 'thumbnail radius matches ModernX')
    F.eq(theme.thumbnail_border_color, require('foundation.color').Color.rgba255(255, 255, 255),
        'thumbnail border is white')
    F.eq(theme.thumbnail_border_outline, require('foundation.color').Color.rgba255(0, 0, 0),
        'thumbnail border outline is black')
    F.ok(theme.compact_mode, 'compact mode follows the ModernX default')
    F.ok(not theme.info_button and not theme.loop_button, 'optional controls start disabled')
    F.raises(function()
        ---@diagnostic disable-next-line: param-type-mismatch
        PlayerThemeData({ layout_option = 'wide' })
    end, 'layout_option', 'invalid layout option')
    F.raises(function()
        PlayerThemeData({ controller_height = 0 })
    end, 'controller_height', 'invalid controller height')
    F.raises(function()
        PlayerThemeData({ thumbnail_border = -1 })
    end, 'thumbnail_border', 'negative thumbnail border is rejected')
    F.raises(function()
        PlayerThemeData({ thumbnail_border_radius = math.huge })
    end, 'thumbnail_border_radius', 'nonfinite thumbnail radius is rejected')
end)

F.test('original geometry uses the ModernX bottom-origin measurements', function()
    local theme = PlayerThemeData()
    local g = player_layout_mod.geometry_for('original', 1280, 720, {
        controller_height = theme.controller_height,
        progress_bar_height = theme.progress_bar_height,
        seekbar_height = theme.seekbar_height,
        chapter_skip_buttons = theme.chapter_skip_buttons,
        jump_buttons = false,
        track_nextprev_buttons = theme.track_nextprev_buttons,
        ontop_button = theme.ontop_button,
        volume_control = theme.volume_control,
        show_title = theme.show_title,
        show_chapter_title = theme.show_chapter_title,
    })
    F.eq(g.controller, Rect(0, 540, 1280, 720), '180px controller at the root bottom')
    F.eq(g.seekbar_background, Rect(25, 619, 1255, 621), 'original seekbar background')
    F.eq(g.seekbar, Rect(25, 612, 1255, 628), 'original seekbar paint box')
    F.eq(g.title, Rect(25, 568, 1255, 603), 'original title box')
    F.eq(g.time_left, Rect(25, 626, 115, 646), 'left time box')
    F.eq(g.center.play, Rect(617.5, 657.5, 662.5, 702.5), 'center play box')
    F.eq(g.side.audio, Rect(25, 668, 49, 692), 'left audio box')
    F.eq(g.right.fullscreen, Rect(1231, 668, 1255, 692), 'right fullscreen box')
end)

F.test('reduced geometry has its independent seek/title/chapter arrangement', function()
    local g = player_layout_mod.geometry_for('reduced', 1280, 720, {
        controller_height = 180,
        progress_bar_height = 16,
        seekbar_height = 2,
        chapter_skip_buttons = true,
        jump_buttons = false,
        track_nextprev_buttons = true,
        show_title = true,
        show_chapter_title = true,
    })
    F.eq(g.seekbar_background, Rect(100, 644, 1180, 646), 'reduced seekbar background')
    F.eq(g.seekbar, Rect(100, 637, 1180, 653), 'reduced seekbar paint box')
    F.eq(g.title, Rect(25, 588, 1135, 623), 'reduced title width')
    F.eq(g.chapter, Rect(25, 576, 145, 595), 'reduced chapter box')
    F.eq(g.center.chapter_prev, Rect(565, 668, 595, 692), 'reduced chapter placement')
end)

F.test('width thresholds hide controls without changing root geometry', function()
    local options = {
        chapter_skip_buttons = true,
        jump_buttons = false,
        track_nextprev_buttons = true,
        volume_control = true,
        ontop_button = true,
    }
    local narrow = player_layout_mod.geometry_for('original', 450, 720, options)
    F.ok(narrow.visibility.audio, 'audio remains at the first threshold')
    F.ok(not narrow.visibility.subtitle, 'subtitle hides below its threshold')
    F.ok(not narrow.visibility.volume, 'volume hides below its threshold')
    F.ok(not narrow.visibility.ontop, 'ontop hides below its threshold')

    local wide = player_layout_mod.geometry_for('original', 700, 720, options)
    F.ok(wide.visibility.audio and wide.visibility.subtitle and wide.visibility.volume,
        'side controls appear as width grows')
    F.ok(wide.visibility.ontop, 'ontop appears at the ModernX threshold')
    F.eq(wide.controller.top, narrow.controller.top, 'thresholds do not move the controller')
end)

F.test('right controls keep ModernX spacing when optional buttons are hidden', function()
    local without_loop = player_layout_mod.geometry_for('original', 1280, 720, {
        loop_button = false,
        ontop_button = true,
        info_button = false,
        screenshot_button = false,
        download_button = false,
    })
    F.eq(without_loop.right.fullscreen, Rect(1231, 668, 1255, 692),
        'fullscreen remains at the right edge')
    F.eq(without_loop.right.ontop, Rect(1186, 668, 1210, 692),
        'ontop sits one control slot beside fullscreen')
    local with_loop = player_layout_mod.geometry_for('original', 1280, 720, {
        loop_button = true,
        ontop_button = true,
    })
    F.eq(with_loop.right.loop, Rect(1186, 668, 1210, 692),
        'loop occupies the slot beside fullscreen')
    F.eq(with_loop.right.ontop, Rect(1141, 668, 1165, 692),
        'ontop follows loop with stable spacing')
end)

F.test('PlayerLayout mounts Positioned geometry and records layer order', function()
    local store = PlayerStore({
        media_title = 'Episode',
        time_pos = 25,
        duration = 100,
        percent_pos = 25,
        is_url = false,
    })
    local owner, binding = mount(WidgetsApp({
        display = DisplaySnapshot({ width = 1280, height = 720, initialized = true }),
        actions = HostActions({ seek_to = function() end }),
        child = PlayerScope({ store = store, child = Main() }),
    }))
    local progress = find_widget_element(binding.root_element, ProgressBar)
    F.ok(progress ~= nil, 'the root-relative seekbar mounts')
    if progress == nil then
        return
    end
    local offset = progress.render_object.parent_data.offset
    F.eq(offset.x, 25, 'seekbar root x')
    F.eq(offset.y, 612, 'seekbar root y')
    F.eq(progress.render_object.size, Size(1230, 16), 'seekbar root size')

    local canvas = RecordCanvas()
    owner:paint(canvas)
    F.ok(canvas:count('draw_rect') > 0 or canvas:count('draw_rrect') > 0,
        'RecordCanvas receives the player layers')
    F.eq(player_layout_mod.PlayerLayout, PlayerLayout, 'direct layout module identity')

    local ass_owner = mount(WidgetsApp({
        display = DisplaySnapshot({ width = 1280, height = 720, initialized = true }),
        actions = HostActions({ seek_to = function() end }),
        child = PlayerScope({ store = store, child = Main() }),
    }))
    local ass = AssCanvas()
    ass_owner:paint(ass)
    F.contains(ass:text(), '\\blur75', 'theme blur reaches ASS output')
    F.contains(ass:text(), '\\bord100', 'ModernX edge border reaches ASS output')

    local has_full_controller_fill = false
    for _, op in ipairs(canvas.ops) do
        if op.name == 'draw_rect' and op[1] == Rect(0, 540, 1280, 720) then
            has_full_controller_fill = true
        end
    end
    F.ok(not has_full_controller_fill, 'controller uses the blurred edge instead of a gray block')
end)

F.test('default window controls keep all three ModernX actions and glyphs', function()
    local store = PlayerStore({ fullscreen = true, border = true, title_bar = true })
    local actions = HostActions({
        minimize = function() end,
        toggle_fullscreen = function() end,
        close = function() end,
    })
    local owner, binding = mount(WidgetsApp({
        display = DisplaySnapshot({ width = 1280, height = 720, initialized = true }),
        actions = actions,
        child = PlayerScope({ store = store, child = Main() }),
    }))
    local ass = AssCanvas()
    owner:paint(ass)
    F.contains(ass:text(), 'minimize', 'minimize glyph is present')
    F.contains(ass:text(), 'fullscreen_exit', 'window fullscreen glyph is present')
    F.contains(ass:text(), 'close', 'close glyph is present')
end)

F.test('optional loop control uses the bundled semantic icon mapping', function()
    local store = PlayerStore({ loop_file = true })
    local owner = mount(WidgetsApp({
        player_theme = PlayerThemeData({ loop_button = true }),
        actions = HostActions({ toggle_loop = function() end }),
        display = DisplaySnapshot({ width = 1280, height = 720, initialized = true }),
        child = PlayerScope({ store = store, child = Main() }),
    }))
    local canvas = AssCanvas()
    owner:paint(canvas)
    F.contains(canvas:text(), 'repeat_on', 'loop control uses the mapped repeat-on glyph')
end)

F.test('chapter title uses chapter metadata instead of the numeric chapter index', function()
    local store = PlayerStore({
        time_pos = 10,
        duration = 100,
        percent_pos = 10,
        chapter = 0,
        chapter_list = {
            { time = 0, title = 'Intro' },
            { time = 50, title = 'Main' },
        },
    })
    local owner = mount(WidgetsApp({
        child = PlayerScope({ store = store, child = Main() }),
    }))
    local canvas = AssCanvas()
    owner:paint(canvas)
    F.contains(canvas:text(), 'Intro', 'chapter metadata is rendered')
    F.ok(not canvas:text():find('chapter title=0', 1, true),
        'numeric chapter index is not used as the title')
end)

F.test('idle player state removes controls and presents the empty state', function()
    local store = PlayerStore({ idle_active = true })
    local owner, binding = mount(WidgetsApp({
        display = DisplaySnapshot({ width = 1280, height = 720, initialized = true }),
        child = PlayerScope({ store = store, child = Main() }),
    }))
    local canvas = AssCanvas()
    owner:paint(canvas)
    F.contains(canvas:text(), 'No media loaded', 'idle state presents an empty message')
    F.ok(find_widget_element(binding.root_element, ProgressBar) == nil,
        'idle state does not mount the seekbar')
    local has_down = false
    for _, region in ipairs(owner:pointer_regions()) do
        if region.down then
            has_down = true
            break
        end
    end
    F.ok(not has_down, 'idle state does not retain player controls')
end)

F.test('description preview opens an in-tree panel and keeps the full text', function()
    local description = 'A full description with enough detail to open the player-owned panel.'
    local store = PlayerStore({
        description = description,
        time_pos = 10,
        duration = 100,
        percent_pos = 10,
    })
    local owner, binding = mount(WidgetsApp({
        display = DisplaySnapshot({ width = 1280, height = 720, initialized = true }),
        child = PlayerScope({ store = store, child = Main() }),
    }))
    owner:dispatch_pointer('down', geometry.Offset(40, 590), 'left')
    owner:dispatch_pointer('up', geometry.Offset(40, 590), 'left')
    binding:flush_build()
    owner:layout()
    local canvas = AssCanvas()
    owner:paint(canvas)
    F.contains(canvas:text(), description, 'description panel keeps the full text')
end)

F.test('description panel selects and opens links through HostActions', function()
    local opened
    local description = 'Open https://example.test/one or https://example.test/two.'
    local store = PlayerStore({ description = description })
    local actions = HostActions({
        open_url = function(url)
            opened = url
        end,
    })
    local owner, binding = mount(WidgetsApp({
        actions = actions,
        display = DisplaySnapshot({ width = 1280, height = 720, initialized = true }),
        child = PlayerScope({ store = store, child = Main() }),
    }))
    local layer = find_widget_element(binding.root_element, PlayerDescriptionLayer)
    F.ok(layer ~= nil, 'description layer mounts')
    if layer == nil then
        return
    end
    owner:dispatch_pointer('down', geometry.Offset(40, 590), 'left')
    owner:dispatch_pointer('up', geometry.Offset(40, 590), 'left')
    binding:flush_build()
    owner:layout()
    F.ok(layer.state.open, 'description panel opens')
    layer.state:handle_key({ key = 'TAB', type = 'press' })
    layer.state:handle_key({ key = 'ENTER', type = 'press' })
    F.eq(opened, 'https://example.test/two', 'selected link opens through the action')
    F.ok(layer.state:handle_key({ key = 'ESC', type = 'press' }), 'ESC closes description panel')
    F.ok(not layer.state.open, 'description panel is closed')
end)

F.test('disabled player controls retain a hover tooltip without claiming clicks', function()
    local store = PlayerStore({ time_pos = 10, duration = 100, percent_pos = 10 })
    local owner, binding = mount(WidgetsApp({
        display = DisplaySnapshot({ width = 1280, height = 720, initialized = true }),
        child = PlayerScope({ store = store, child = Main() }),
    }))
    local tooltip = find_widget_element(binding.root_element, PlayerTooltip)
    F.ok(tooltip ~= nil, 'player controls are wrapped with PlayerTooltip')
    owner:dispatch_pointer('move', geometry.Offset(37, 680))
    binding:flush_build()
    owner:layout()
    local canvas = AssCanvas()
    owner:paint(canvas)
    F.contains(canvas:text(), 'No audio available', 'disabled audio tooltip is visible')
    local audio_click_region = false
    for _, region in ipairs(owner:pointer_regions()) do
        if region.down and region.rect:contains(geometry.Offset(37, 680)) then
            audio_click_region = true
        end
    end
    F.ok(not audio_click_region, 'disabled tooltip does not add a click region')
end)

F.test('seekbar hover shows a formatted time and chapter fallback tooltip', function()
    local store = PlayerStore({
        time_pos = 25,
        duration = 100,
        percent_pos = 25,
        chapter = 0,
        chapter_list = {
            { time = 0, title = 'Intro' },
            { time = 50, title = 'Main' },
        },
    })
    local owner, binding = mount(WidgetsApp({
        display = DisplaySnapshot({ width = 1280, height = 720, initialized = true }),
        child = PlayerScope({ store = store, child = Main() }),
    }))
    local progress = find_widget_element(binding.root_element, ProgressBar)
    F.ok(progress ~= nil, 'seekbar mounts for tooltip test')
    if progress == nil then
        return
    end
    local offset = progress.render_object.parent_data.offset
    owner:dispatch_pointer('move', geometry.Offset(offset.x + 615, offset.y + 8))
    binding:flush_build()
    owner:layout()
    local canvas = AssCanvas()
    owner:paint(canvas)
    F.contains(canvas:text(), '00:50', 'seek tooltip formats the hovered time')
    F.contains(canvas:text(), 'Intro', 'seek tooltip includes chapter fallback text')
end)

F.test('an injected right control preserves pin/fullscreen spacing and moves later controls', function()
    local base = player_layout_mod.geometry_for('original', 1280, 720, { info_button = true })
    local extra = player_layout_mod.geometry_for('original', 1280, 720, {
        info_button = true, extra_right_control = true,
    })
    F.eq(extra.right.fullscreen, base.right.fullscreen, 'fullscreen position is preserved')
    F.eq(extra.right.ontop, base.right.ontop, 'pin position is preserved')
    F.eq(extra.right.extra_right_control.right, extra.right.ontop.right - 45,
        'extra control occupies the next left button grid')
    F.eq(extra.right.info.right, base.right.info.right - 45, 'later controls shift by one grid')
end)

F.test('text hover paints a full-strength glow without relayout', function()
    local owner = mount(WidgetsApp({
        display = DisplaySnapshot({ width = 1280, height = 720, initialized = true }),
        child = PlayerScope({
            store = PlayerStore({ time_pos = 12, duration = 100 }),
            child = Main(),
        }),
    }))
    owner:dispatch_pointer('move', geometry.Offset(35, 636))
    local canvas = RecordCanvas()
    owner:paint(canvas)
    local text_ops = {}
    for _, op in ipairs(canvas.ops) do
        if op.name == 'draw_text' and op[1].text == '00:12' then
            text_ops[#text_ops + 1] = op
        end
    end
    F.eq(#text_ops, 2, 'time hover paints a separate glow glyph')
    F.eq(text_ops[2][1].style.color.a, 1, 'text glow uses full opacity')
    F.eq(text_ops[1][2], text_ops[2][2], 'glow shares the normal text position')
    F.ok(not owner:needs_layout(), 'hover remains paint-only')
end)

F.test('volume hover shows the current value with a fixed round handle', function()
    local store = PlayerStore({
        duration = 100,
        percent_pos = 25,
        volume = 72,
        volume_max = 100,
        track_list = { { type = 'audio', id = 1, selected = true } },
    })
    local owner, binding = mount(WidgetsApp({
        actions = HostActions({
            set_volume = function() end,
            toggle_mute = function() end,
            seek_to = function() end,
        }),
        display = DisplaySnapshot({ width = 1280, height = 720, initialized = true }),
        child = PlayerScope({ store = store, child = Main() }),
    }))
    owner:dispatch_pointer('move', geometry.Offset(195, 680))
    binding:flush_build()
    owner:layout()
    local canvas = AssCanvas()
    owner:paint(canvas)
    F.contains(canvas:text(), '50%', 'volume tooltip reports the hovered value')
    local render_progress_class = require('render.progress_bar').RenderProgressBar
    ---@type RenderProgressBar?
    local fixed_handle
    for _, progress in ipairs(owner:pointer_regions()) do
        if std.isinstance(progress.node, render_progress_class)
            and progress.rect:contains(geometry.Offset(195, 680)) then
            fixed_handle = progress.node
        end
    end
    F.ok(fixed_handle ~= nil, 'volume slider has an interactive render node')
    F.eq(fixed_handle.handle_size, 0.8, 'normal volume handle is visible')
    F.eq(fixed_handle.hover_handle_size, fixed_handle.handle_size, 'hover keeps the same handle size')
    local record = RecordCanvas()
    fixed_handle:mark_needs_paint()
    owner:paint(record)
    local circles = 0
    for _, op in ipairs(record.ops) do
        if op.name == 'draw_rrect' and math.abs(op[1]:width() - op[1]:height()) < 0.00001
            and op[1]:width() > 0 and op[1]:width() < 16 then
            circles = circles + 1
        end
    end
    F.ok(circles > 0, 'paint emits the small round slider handle')
end)

F.test('scaled seek tooltip stays below thumbfast and shares its clamped center', function()
    local request
    local owner = mount(WidgetsApp({
        actions = HostActions({
            seek_to = function() end,
            thumbfast_request = function(seconds, x, y)
                request = { seconds = seconds, x = x, y = y }
            end,
        }),
        display = DisplaySnapshot({ width = 1280, height = 720, initialized = true }),
        child = PlayerScope({
            store = PlayerStore({
                duration = 100,
                capabilities = { thumbfast = { status = 'available', detail = '320x180' } },
            }),
            child = Main({ scale = 1.5 }),
        }),
    }))
    owner:dispatch_pointer('move', geometry.Offset(50, 570))
    local canvas = RecordCanvas()
    owner:paint(canvas)
    local draw
    for _, op in ipairs(canvas.ops) do
        if op.name == 'draw_text' and op[3].anchor == 'bottom_center' then
            draw = op
        end
    end
    F.ok(draw ~= nil and request ~= nil, 'scaled hover paints a time label and requests a preview')
    F.close(draw[2].x * 1.5, request.x + 160, 'scaled edge-clamped tooltip and thumbnail share the center')
    F.eq(draw[2].y * 1.5, 558, 'scaled tooltip remains at the seekbar upper edge')
    F.ok(draw[2].y * 1.5 - 27 > request.y + 180, 'scaled nominal text box clears the thumbnail')
    local frame = {}
    for _, op in ipairs(canvas.ops) do
        if op.name == 'draw_rrect' and op[1]:height() > 100 then
            frame[#frame + 1] = op
        end
    end
    F.eq(#frame, 2, 'thumbnail has an outline and border')
    local image = Rect.from_ltwh(request.x / 1.5, request.y / 1.5, 320 / 1.5, 180 / 1.5)
    F.eq(frame[1][1], image:inflate(2 / 1.5), 'outline surrounds the exact scaled external image')
    F.eq(frame[2][1], image:inflate(1 / 1.5), 'border surrounds the exact scaled external image')
    F.close(frame[2][2], 1 / 1.5, 'radius is capped to the physical border padding')
    F.eq(frame[1][3].color, require('foundation.color').Color.rgba255(0, 0, 0), 'black outline')
    F.eq(frame[2][3].color, require('foundation.color').Color.rgba255(255, 255, 255), 'white border')
end)

F.test('thumbnail frame can be disabled without changing the preview request', function()
    local requests = 0
    local owner = mount(WidgetsApp({
        player_theme = PlayerThemeData({ thumbnail_border = 0 }),
        actions = HostActions({ thumbfast_request = function() requests = requests + 1 end }),
        display = DisplaySnapshot({ width = 1280, height = 720, initialized = true }),
        child = PlayerScope({
            store = PlayerStore({
                duration = 100,
                capabilities = { thumbfast = { status = 'available', detail = '320x180' } },
            }),
            child = Main(),
        }),
    }))
    owner:dispatch_pointer('move', geometry.Offset(100, 620))
    local canvas = RecordCanvas()
    owner:paint(canvas)
    F.eq(requests, 1, 'preview is still requested')
    local frames = 0
    for _, op in ipairs(canvas.ops) do
        if op.name == 'draw_rrect' and op[1]:height() > 100 then
            frames = frames + 1
        end
    end
    F.eq(frames, 0, 'zero border emits no thumbnail frame')
end)

F.test('AutoHide clears a retained thumbnail at fade start and suppresses fading requests', function()
    local visibility = require('widget.visibility')
    local controller = visibility.AutoHideController()
    local cleared, requested = 0, 0
    local store = PlayerStore({
        duration = 100,
        capabilities = { thumbfast = { status = 'available', detail = '320x180' } },
    })
    local owner, binding = mount(WidgetsApp({
        actions = HostActions({
            thumbfast_request = function() requested = requested + 1 end,
            thumbfast_clear = function() cleared = cleared + 1 end,
        }),
        display = DisplaySnapshot({ width = 1280, height = 720, initialized = true }),
        child = PlayerScope({ store = store, child = visibility.AutoHide({
            controller = controller, timeout = 0, fade_duration = 0, child = Main(),
        }) }),
    }))
    owner:dispatch_pointer('move', geometry.Offset(100, 620))
    local tooltip = find_widget_element(binding.root_element, PlayerTooltip)
    F.eq(requested, 1, 'hover opens the external preview')
    controller:hide()
    F.eq(cleared, 1, 'hiding clears the preview without a mouse leave')
    F.ok(not tooltip.state.hovered, 'retained tooltip drops its hover data')
    F.ok(tooltip.state:is_mounted(), 'Main state remains mounted')
    controller:hide()
    F.eq(cleared, 1, 'duplicate hide does not repeat clear')
    owner:dispatch_pointer('move', geometry.Offset(101, 620))
    F.eq(requested, 1, 'hidden Main does not request another preview')
    controller:show()
    binding:flush_build()
    owner:layout()
    owner:dispatch_pointer('move', geometry.Offset(102, 620))
    F.eq(requested, 2, 'the next real move after showing opens a new preview')
    store:replace(store:get():copy({ capabilities = { thumbfast = { status = 'unavailable' } } }))
    binding:flush_build()
    owner:layout()
    F.eq(cleared, 2, 'capability loss clears the old preview during rebuild')
    binding:dispose()
    F.eq(cleared, 2, 'disposing an already cleared tooltip is idempotent')
    F.eq(next(controller._listeners), nil, 'tooltip and AutoHide listeners are released')
end)

F.test('persistent progress uses seekable cache ranges instead of a continuous buffer', function()
    local store = PlayerStore({
        duration = 100,
        percent_pos = 25,
        cache_state = {
            ['seekable-ranges'] = {
                { start = 10, ['end'] = 40 },
            },
        },
    })
    local owner, binding = mount(WidgetsApp({
        player_theme = PlayerThemeData({
            persistent_progress = true,
            persistent_buffer = true,
        }),
        display = DisplaySnapshot({ width = 1280, height = 720, initialized = true }),
        child = PlayerScope({ store = store, child = Main() }),
    }))
    local bars = find_widget_elements(binding.root_element, ProgressBar)
    local persistent
    for _, element in ipairs(bars) do
        if element.widget.height == 17 then
            persistent = element.widget
            break
        end
    end
    F.ok(persistent ~= nil, 'persistent progress bar mounts')
    if persistent == nil then
        return
    end
    F.eq(persistent.buffered, 0, 'persistent cache does not use a continuous fill')
    F.close(persistent.ranges[1].start, 0.1, 'persistent cache range start')
    F.close(persistent.ranges[1]['end'], 0.4, 'persistent cache range end')
    owner:paint(AssCanvas())
end)

F.test('available thumbfast requests previews and keeps the time fallback path separate', function()
    local requests = {}
    local cleared = 0
    local actions = HostActions({
        seek_to = function() end,
        thumbfast_request = function(seconds, x, y)
            requests[#requests + 1] = { seconds, x, y }
        end,
        thumbfast_clear = function()
            cleared = cleared + 1
        end,
    })
    local store = PlayerStore({
        duration = 100,
        percent_pos = 25,
        chapter_list = {
            { time = 0, title = 'Intro' },
            { time = 50, title = 'Main' },
        },
        capabilities = { thumbfast = { status = 'available', detail = '320x180' } },
    })
    local owner, binding = mount(WidgetsApp({
        actions = actions,
        display = DisplaySnapshot({ width = 1280, height = 720, initialized = true }),
        child = PlayerScope({ store = store, child = Main() }),
    }))
    local progress = find_widget_element(binding.root_element, ProgressBar)
    F.ok(progress ~= nil, 'seekbar mounts for thumbfast')
    if progress == nil then
        return
    end
    local offset = progress.render_object.parent_data.offset
    owner:dispatch_pointer('move', geometry.Offset(offset.x + 615, offset.y + 8))
    F.eq(#requests, 1, 'thumbfast receives one hover request')
    F.close(requests[1][1], 50, 'thumbfast receives hovered seconds')
    local hover_canvas = RecordCanvas()
    owner:paint(hover_canvas)
    local time_draw
    for _, op in ipairs(hover_canvas.ops) do
        if op.name == 'draw_text' and op[1].text == '00:50' then
            time_draw = op
        end
    end
    F.ok(time_draw ~= nil, 'thumbnail keeps a time label')
    F.eq(time_draw[3].anchor, 'bottom_center', 'time label uses the ModernX bottom anchor')
    F.eq(time_draw[2].x, requests[1][2] + 160, 'time label is centered on thumbfast')
    F.ok(time_draw[2].y - 18 > requests[1][3] + 180,
        'nominal time glyph remains below the thumbnail')
    owner:dispatch_pointer('move', geometry.Offset(35, 615))
    local edge_canvas = RecordCanvas()
    owner:paint(edge_canvas)
    local edge_time
    for _, op in ipairs(edge_canvas.ops) do
        if op.name == 'draw_text' and op[3].anchor == 'bottom_center' then
            edge_time = op
        end
    end
    F.eq(edge_time[2].x, requests[2][2] + 160, 'edge-clamped time and thumbnail share their center')
    local ass = AssCanvas()
    for _, op in ipairs(edge_canvas.ops) do
        if op.name == 'draw_rrect' and op[1]:height() > 100 then
            ass:draw_rrect(op[1], op[2], op[3])
        end
    end
    local frame_events = 0
    for line in ass:text():gmatch('[^\n]+') do
        if line:find('\\p', 1, true) and line:find(' b ', 1, true)
            and (line:find('\\1c&HFFFFFF&', 1, true) or line:find('\\1c&H000000&', 1, true)) then
            frame_events = frame_events + 1
        end
    end
    F.eq(frame_events, 2, 'ASS contains both rounded thumbnail frame layers')
    owner:dispatch_pointer('move', geometry.Offset(0, 0))
    F.eq(cleared, 1, 'leaving the seekbar clears thumbfast')
    local after_leave = RecordCanvas()
    owner:paint(after_leave)
    local remaining_frames = 0
    for _, op in ipairs(after_leave.ops) do
        if op.name == 'draw_rrect' and op[1]:height() > 100 then
            remaining_frames = remaining_frames + 1
        end
    end
    F.eq(remaining_frames, 0, 'leaving removes the in-tree thumbnail frame')
end)

F.test('time displays use click-local toggles for milliseconds', function()
    local store = PlayerStore({ time_pos = 12.25, duration = 100, percent_pos = 12.25 })
    local owner, binding = mount(WidgetsApp({
        display = DisplaySnapshot({ width = 1280, height = 720, initialized = true }),
        child = PlayerScope({ store = store, child = Main() }),
    }))
    local ass = AssCanvas()
    owner:paint(ass)
    F.ok(not ass:text():find('12%.250', 1, false), 'milliseconds are initially hidden')
    F.contains(ass:text(), '01:40', 'right time defaults to total duration')
    F.ok(not ass:text():find('-01:40', 1, true), 'total duration has no remaining prefix')
    owner:dispatch_pointer('down', geometry.Offset(40, 636), 'left')
    owner:dispatch_pointer('up', geometry.Offset(40, 636), 'left')
    binding:flush_build()
    owner:layout()
    ass:reset()
    owner:paint(ass)
    F.contains(ass:text(), '12.250', 'left time toggles milliseconds')
end)

F.test('WidgetsApp PlayerTheme selects the reduced layout without changing its contract', function()
    local store = PlayerStore({
        media_title = 'Reduced',
        time_pos = 10,
        duration = 100,
        percent_pos = 10,
    })
    local owner, binding = mount(WidgetsApp({
        player_theme = PlayerThemeData({
            layout_option = 'reduced',
            window_title = false,
            window_controls = false,
        }),
        display = DisplaySnapshot({ width = 1280, height = 720, initialized = true }),
        actions = HostActions({ seek_to = function() end }),
        child = PlayerScope({ store = store, child = Main() }),
    }))
    local progress = find_widget_element(binding.root_element, ProgressBar)
    F.ok(progress ~= nil, 'reduced layout mounts the seekbar')
    if progress == nil then
        return
    end
    F.eq(progress.render_object.parent_data.offset, geometry.Offset(100, 637),
        'reduced layout uses its independent root-relative seekbar origin')
    F.eq(progress.render_object.size, Size(1080, 16), 'reduced seekbar has W-200 width')
    F.ok(owner.root ~= nil, 'reduced layout remains one logical render root')
end)
