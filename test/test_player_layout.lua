-- ModernX original/reduced root-relative player geometry and theme profiles.

---@diagnostic disable: undefined-field, inject-field, need-check-nil, generic-constraint-mismatch, preferred-local-alias, unused

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
local RecordCanvas = record_mod.RecordCanvas
local AssCanvas = ass_mod.AssCanvas

local FixedLayout = std.class.new('test.playerlayout.FixedLayout', { text_layout.TextLayout })
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

F.section('player layout: theme and geometry')

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
    F.eq(theme.controller_border_width, 100, 'ModernX controller edge width')
    F.eq(theme.window_border_width, 100, 'ModernX window edge width')
    F.eq(theme.controller_blur_radius, 75, 'ModernX controller blur strength')
    F.eq(theme.window_blur_radius, 75, 'ModernX window blur strength')
    F.eq(theme.hover_scale, 1.15, 'hover scale')
    F.ok(theme.compact_mode, 'compact mode follows the ModernX default')
    F.ok(not theme.info_button and not theme.loop_button, 'optional controls start disabled')
    F.raises(function()
        ---@diagnostic disable-next-line: param-type-mismatch
        PlayerThemeData({ layout_option = 'wide' })
    end, 'layout_option', 'invalid layout option')
    F.raises(function()
        PlayerThemeData({ controller_height = 0 })
    end, 'controller_height', 'invalid controller height')
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
        toggle_maximized = function() end,
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
    F.contains(ass:text(), 'maximize', 'maximize glyph is present')
    F.contains(ass:text(), 'close', 'close glyph is present')
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
    owner:dispatch_pointer('move', geometry.Offset(0, 0))
    F.eq(cleared, 1, 'leaving the seekbar clears thumbfast')
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
