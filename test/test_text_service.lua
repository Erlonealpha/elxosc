-- Service injection, bounded caches and host-owned text sessions.
---@namespace test.textService
---@using elxosc
-- Mutable fake-host hooks and inspected internal nodes use the suite's class limitation.
---@diagnostic disable: undefined-field, inject-field, need-check-nil
local F = require 'framework'
local std = require 'elxlibs.std'
local ass_mod = require 'src.backends.ass_text_layout'
local canvas_mod = require 'src.backends.ass_canvas'
local text_mod = require 'src.text.text_layout'
local style_mod = require 'src.text.text_style'
local ambient_mod = require 'src.widgets.ambient'
local widget_mod = require 'src.widgets.framework'
local widgets = require 'widgets'
local constraints_mod = require 'src.layout.constraints'
local binding_mod = require 'src.widgets.widgets_binding'
local mp_stub = require 'mp_stub'
local mp = mp_stub.install()
local app_mod = require 'host.mpv_app'

local AssTextLayout = ass_mod.AssTextLayout
local TextStyle = style_mod.TextStyle
local TextLayoutScope = ambient_mod.TextLayoutScope
local Constraints = constraints_mod.Constraints
local style = TextStyle({ font_size = 20, wrap = false })

---@param data string
---@return AssTextBounds
local function native(data)
    local x, y = data:match('\\pos%((%d+),(%d+)%)')
    local anchor = tonumber(data:match('\\an(%d)'))
    local text = assert(data:match('}(.*)$'))
    local width = #text:gsub('\\h', ' ') * 10
    local left = assert(tonumber(x)) + 2 - (anchor == 6 and width or 0)
    return { x0 = left, x1 = left + width + 4, y0 = tonumber(y) - 8, y1 = tonumber(y) + 8 }
end

local function layout(options)
    options = options or {}
    options.measure_ass = options.measure_ass or native
    options.res_x = options.res_x or 640
    options.res_y = options.res_y or 360
    return AssTextLayout(options)
end

F.section('text service: native line spans and cache')

F.test('measures whole lines and reuses equivalent shape values', function()
    local service = layout()
    local width, source = service:measure_line('AV', style)
    F.eq(width, 20, 'span excludes image padding')
    F.eq(source, 'native', 'observable source')
    F.eq(service:cache_stats().native_calls, 2, 'one complete left/right pair')
    local same = TextStyle({ font_size = 20, wrap = true, align = 'right', line_height = 3,
        color = require('src.foundation.color').Color(1, 0, 0), blur_radius = 5 })
    F.eq(service:line_width('AV', same), width, 'paint and paragraph settings excluded from key')
    F.eq(service:cache_stats().native_calls, 2, 'equivalent fresh style hits')
    service:line_width('AV', style:copy_with({ bold = true }))
    service:line_width('AV', style:copy_with({ font_family = 'Arial' }))
    service:line_width('AV', style:copy_with({ letter_spacing = 0.000000001 }))
    F.eq(service:cache_stats().native_calls, 8, 'shape fields distinguish cache entries')
    local snapshot = service:cache_stats()
    snapshot.entries = 99
    F.eq(service:cache_stats().entries, 4, 'stats are a copy')
end)

F.test('entry and byte limits evict least recently used values', function()
    local service = layout({ cache_entries = 2, cache_bytes = 80 })
    service:line_width('a', style)
    service:line_width('b', style)
    service:line_width('a', style)
    service:line_width('c', style)
    F.eq(service:cache_stats().entries, 2, 'entry bound')
    local calls = service:cache_stats().native_calls
    service:line_width('a', style)
    F.eq(service:cache_stats().native_calls, calls, 'recently touched entry survives')
    service:line_width('b', style)
    F.eq(service:cache_stats().native_calls, calls + 2, 'oldest entry was evicted')
    for index = 1, 100 do
        service:line_width('value-' .. index, style)
    end
    F.ok(service:cache_stats().bytes <= 80, 'byte bound after pressure')
    F.ok(service:cache_stats().entries <= 2, 'entry bound after pressure')
    local before = service:cache_stats().entries
    service:line_width(string.rep('a', 100), style)
    F.eq(service:cache_stats().entries, before, 'oversized key not retained')
    F.ok(service:cache_stats().evictions > 0, 'eviction recorded')
    local bytes_only = layout({ cache_entries = 100, cache_bytes = 65 })
    for index = 1, 20 do
        bytes_only:line_width('item ' .. index, style)
    end
    F.ok(bytes_only:cache_stats().entries < 20, 'byte limit evicts independently of entry limit')
    F.ok(bytes_only:cache_stats().bytes <= 65, 'independent byte limit holds')
    local disabled = layout({ cache_entries = 0 })
    disabled:line_width('x', style)
    disabled:line_width('x', style)
    F.eq(disabled:cache_stats().native_calls, 4, 'cache can be bypassed')
end)

F.test('empty, zero font and exact-count blank strings have distinct behavior', function()
    local service = layout()
    local width, source = service:measure_line('', style)
    F.eq(width, 0, 'empty width')
    F.eq(source, 'empty', 'empty source')
    F.eq(service:line_width('x', style:copy_with({ font_size = 0 })), 0, 'zero font width')
    F.eq(service:cache_stats().native_calls, 0, 'no fs0 native call')
    F.eq(service:line_width('   ', style), 30, 'blank count measured with marker')
    F.eq(service:cache_stats().native_calls, 4, 'blank pair and marker pair')
    F.eq(service:line_width(' ', style), 10, 'separate blank count')
    F.eq(service:cache_stats().native_calls, 6, 'marker result reused')
    local canvas = canvas_mod.AssCanvas()
    canvas:draw_text(service:layout('x', style:copy_with({ font_size = 0 })),
        require('src.foundation.geometry').Offset.zero())
    F.eq(canvas:text(), '', 'fs0 does not restore a host default font')
end)

F.test('measurement and painting share shape and boundary escaping', function()
    local payloads = {}
    local service = layout({ default_font_family = 'Arial', measure_ass = function(data)
        payloads[#payloads + 1] = data
        return native(data)
    end })
    local text = ' {literal}\\N '
    service:line_width(text, style)
    local canvas = canvas_mod.AssCanvas()
    canvas.default_font_family = 'Arial'
    canvas:draw_text(service:layout(text, style), require('src.foundation.geometry').Offset.zero())
    F.eq(payloads[1]:match('}(.*)$'), canvas:text():match('}(.*)$'), 'literal text is identical')
    F.contains(canvas:text(), '\\q2', 'only the layout engine selects lines')
    F.contains(canvas:text(), '\\fnArial', 'host default resolved explicitly')
    F.contains(canvas:text(), '}\\h', 'leading space preserved')
    F.contains(payloads[1], '\\blur0', 'normalized measure excludes paint effects')
end)

F.test('native faults latch while unreliable text retains a bounded fallback', function()
    local service = layout({ measure_ass = function()
        return nil, 'host failed', 'error'
    end })
    local width, source, reason = service:measure_line('a', style)
    F.eq(width, 10, 'estimate remains usable')
    F.eq(source, 'estimate', 'failure is not native success')
    F.eq(reason, 'error', 'failure classified')
    service:line_width('b', style)
    F.eq(service:cache_stats().native_calls, 1, 'new labels do not retry a failed session')
    F.eq(layout():measure_line('a', style), 10, 'fresh environment recovers')
    for _, case in ipairs({
        { callback = function() error('native exception') end, reason = 'error' },
        { callback = function() return nil, 'missing API', 'unavailable' end, reason = 'unavailable' },
        { callback = function() return 7 end, reason = 'error' },
    }) do
        local failed = layout({ measure_ass = case.callback })
        local _, _, actual = failed:measure_line('a', style)
        F.eq(actual, case.reason, 'native boundary failure classified')
        failed:measure_line('b', style)
        F.eq(failed:cache_stats().native_calls, 1, 'native boundary failure stops retries')
    end
    for _, callback in ipairs({
        function() return {} end,
        function() return { x0 = 0, y0 = 2, x1 = 10, y1 = 10 } end,
        function() return { x0 = 2, y0 = 2, x1 = 0 / 0, y1 = 10 } end,
    }) do
        local unreliable = layout({ measure_ass = callback })
        local _, actual_source, actual_reason = unreliable:measure_line('x', style)
        F.eq(actual_source, 'estimate', 'invalid/empty image is not zero layout width')
        F.eq(actual_reason, 'unreliable', 'unreliable classification')
        unreliable:line_width('x', style)
        F.eq(unreliable:cache_stats().native_calls, 1, 'same unreliable text uses bounded fallback')
    end
    local unsupported = layout()
    local _, _, unsupported_reason = unsupported:measure_line('a\tb', style)
    F.eq(unsupported_reason, 'unsupported', 'tab awaits its own layout contract')
    F.eq(unsupported:cache_stats().native_calls, 0, 'unsupported whitespace not submitted')
    F.raises(function() layout({ cache_entries = -1 }) end, 'non-negative integer', 'invalid cache bound')
    F.raises(function() layout({ res_y = math.huge }) end, 'positive finite resolution', 'invalid resolution')
    F.raises(function() layout({ res_x = 0.5 }) end, 'positive finite resolution', 'resolution below one')
    F.raises(function() layout({ default_font_family = 'bad\\font' }) end, 'literal font name', 'invalid font')
    local disagreement = layout({ measure_ass = function(data)
        local raw = native(data)
        if data:find('\\an6', 1, true) then
            raw.x1 = raw.x1 + 3
        end
        return raw
    end })
    local _, disagreement_source = disagreement:measure_line('AV', style)
    F.eq(disagreement_source, 'estimate', 'inconsistent image shifts cannot become native widths')
end)

F.test('constructors snapshot their configuration without changing caller tables', function()
    local options = { measure_ass = native, res_x = 640, res_y = 360, cache_entries = 2 }
    local service = AssTextLayout(options)
    F.eq(options.cache_bytes, nil, 'constructor does not fill caller defaults')
    options.cache_entries = 0
    service:line_width('a', style)
    F.eq(service:cache_stats().entries, 1, 'caller mutation does not change capacity')
    local scope_options = { layout = service, child = widgets.Text('a') }
    local scope = TextLayoutScope(scope_options)
    F.eq(scope_options.generation, nil, 'scope constructor does not fill caller generation')
    F.eq(scope.generation, 0, 'scope default generation')
    F.raises(function() TextLayoutScope({ layout = service, generation = -1 }) end,
        'non-negative integer', 'invalid scope generation')
end)

F.section('text service: tree scope')

F.test('scope replacement updates retained Text nodes and respects explicit layouts', function()
    local first = layout()
    local second = layout({ measure_ass = function(data)
        local raw = native(data)
        if data:find('\\an6', 1, true) then
            raw.x0 = raw.x0 - 15
            raw.x1 = raw.x1 - 15
        end
        return raw
    end })
    local child = widgets.Text('abc', { style = style })
    local binding = binding_mod.WidgetsBinding.ensure_initialized()
    local tree = binding:attach(TextLayoutScope({ layout = first, child = child }))
    tree.render_owner:set_viewport(Constraints.loose(640, 360))
    tree.render_owner:layout()
    local node = tree.render_owner.root
    F.eq(node.size.width, 30, 'first scoped width')
    tree:set_root_widget(TextLayoutScope({ layout = second, generation = 1, child = child }))
    tree:flush_build()
    tree.render_owner:layout()
    -- Owner methods replace runtime fields; analyzer alias hints cannot track these mutations.
    ---@diagnostic disable-next-line: preferred-local-alias
    F.ok(rawequal(node, tree.render_owner.root), 'RenderObject is reused')
    F.eq(node.size.width, 45, 'same text remeasured on environment replacement')
    local explicit = widgets.Text('abc', { style = style, text_layout = first })
    tree:set_root_widget(TextLayoutScope({ layout = second, child = explicit }))
    tree:flush_build()
    tree.render_owner:layout()
    F.eq(node.size.width, 30, 'explicit layout has priority')
    tree:dispose()
    F.eq(require('material').TextLayoutScope, TextLayoutScope, 'Material collector identity')
    F.eq(widgets.TextLayoutScope, TextLayoutScope, 'widget collector identity')
end)

F.test('generation changes notify Tooltip and preserve explicit Text dependencies', function()
    local first = layout()
    local child = widgets.Tooltip({ text = 'tip', child = widgets.Text('body', { style = style }) })
    local tree = binding_mod.WidgetsBinding.ensure_initialized():attach(
        TextLayoutScope({ layout = first, child = child }))
    tree.render_owner:set_viewport(Constraints.loose(640, 360))
    tree.render_owner:layout()
    local function find(element)
        if element.widget.__class == widgets.Tooltip then
            return element.state
        end
        for _, next_element in ipairs(element:element_children()) do
            local found = find(next_element)
            if found then
                return found
            end
        end
    end
    local tooltip = assert(find(tree.root_element))
    tooltip._paragraph = first:layout('tip', style)
    tree:set_root_widget(TextLayoutScope({ layout = first, generation = 1, child = child }))
    tree:flush_build()
    F.eq(tooltip._paragraph, nil, 'generation alone invalidates Tooltip result')
    F.eq(tooltip._text_generation, 1, 'dependency generation observed')
    tree:dispose()
end)

F.section('text service: host lifecycle')

local function with_host(body)
    mp_stub.reset()
    -- install() returns fresh mp tables; previously loaded host modules retain
    -- their own table. Patch those captured tables without reloading classes.
    local host_tables = {}
    for _, method in ipairs({ require('host.ass_measure').AssMeasure.__init, app_mod.App._observe }) do
        local index = 1
        while true do
            local name, value = debug.getupvalue(method, index)
            if not name then
                break
            end
            if name == 'mp' then
                host_tables[value] = { create = value.create_osd_overlay, command = value.command_native }
            end
            index = index + 1
        end
    end
    local sessions, removed = {}, {}
    for host, previous in pairs(host_tables) do
        host.create_osd_overlay = function(format)
            local overlay = previous.create(format)
            overlay.id = #sessions + 1
            sessions[#sessions + 1] = overlay
            return overlay
        end
        host.command_native = function(command)
            if command.format == 'none' then
                removed[command.id] = (removed[command.id] or 0) + 1
                return {}
            end
            return native(command.data)
        end
    end
    local ok, err = pcall(body, sessions, removed)
    for host, previous in pairs(host_tables) do
        host.create_osd_overlay = previous.create
        host.command_native = previous.command
    end
    if not ok then
        error(err, 0)
    end
end

F.test('App owns isolated sessions across refresh, resize and shutdown', function()
    with_host(function(sessions, removed)
        local default = AssTextLayout()
        text_mod.set_default(default)
        local child = widgets.Text('abc', { style = style })
        local first = app_mod.App(child)
        local second = app_mod.App(child)
        first:render()
        second:render()
        F.eq(first.owner.root.size.width, 1280, 'viewport remains tight')
        F.eq(first.owner.root.paragraph.size.width, 30, 'production Text uses native scope')
        F.ok(not rawequal(first.text_layout, second.text_layout), 'independent layouts')
        F.eq(text_mod.get_default(), default, 'App does not overwrite module default')
        local old_layout = first.text_layout
        local old_generation = first.text_layout_generation
        first:refresh_text_layout()
        first:render()
        -- refresh_text_layout replaces these runtime fields through a method boundary.
        ---@diagnostic disable-next-line: preferred-local-alias
        F.ok(not rawequal(old_layout, first.text_layout), 'explicit refresh replaces service')
        ---@diagnostic disable-next-line: preferred-local-alias
        F.eq(old_generation + 1, first.text_layout_generation, 'generation advances')
        F.eq(removed[2], 1, 'first owned session removed')
        F.eq(removed[4], nil, 'second App session untouched')
        mp_stub.fake.osd_width = 640
        first:_update_display()
        first:render()
        ---@diagnostic disable-next-line: preferred-local-alias
        F.eq(640, first.text_layout.res_x, 'new fixed-resolution session after resize')
        first:shutdown()
        second:render()
        F.eq(second.owner.root.paragraph.size.width, 30, 'remaining App still usable')
        second:shutdown()
        F.eq(removed[4], 1, 'second App cleans its own session')
        F.eq(#first._text_sessions, 0, 'all first App sessions released')
        F.eq(#second._text_sessions, 0, 'all second App sessions released')
    end)
end)

F.test('partial mount and failed session removal retain cleanup guarantees', function()
    with_host(function(_, removed)
        local app = app_mod.App(widgets.Text('a', { style = style }))
        local session = assert(app._text_sessions[1])
        local dispose = session.dispose
        local attempts = 0
        session.dispose = function()
            attempts = attempts + 1
            if attempts == 1 then
                return false, 'remove rejected'
            end
            return dispose(session)
        end
        F.raises(function() app:shutdown() end, 'remove rejected', 'cleanup failure reported')
        F.eq(#app._text_sessions, 1, 'failed ID retains ownership')
        F.eq(app:shutdown(), false, 'explicit shutdown retries cleanup only')
        F.eq(#app._text_sessions, 0, 'retry releases ID')
        F.eq(attempts, 2, 'bounded explicit retry')

        local initialize_input = require('host.mpv_input').MpInput.__init
        require('host.mpv_input').MpInput.__init = function()
            error('input install failed')
        end
        local ok, err = pcall(function()
            return app_mod.App(widgets.Text('a'))
        end)
        require('host.mpv_input').MpInput.__init = initialize_input
        F.ok(not ok, 'partial initialization fails')
        F.contains(tostring(err), 'input install failed', 'original failure preserved')
        F.eq(removed[4], 1, 'partial App releases acquired session')
    end)
end)

F.test('invalid initial OSD, native recovery and cleanup faults have bounded ownership', function()
    with_host(function(sessions)
        mp_stub.fake.osd_width = 0
        mp_stub.fake.osd_height = 0
        local app = app_mod.App(widgets.Text('a', { style = style }))
        F.eq(#app._text_sessions, 0, 'no session before valid dimensions')
        local _, _, reason = app.text_layout:measure_line('a', style)
        F.eq(reason, 'offline', 'initial fallback identified')
        mp_stub.fake.osd_width = 640
        mp_stub.fake.osd_height = 360
        app:_update_display()
        app:render()
        F.eq(app.owner.root.paragraph.size.width, 10, 'first valid viewport replaces fallback')
        local session = assert(app._text_sessions[1])
        local original = session.dispose
        session.dispose = function()
            return false, 'persistent removal failure'
        end
        local count = #sessions
        for _ = 1, 3 do
            app:refresh_text_layout()
        end
        F.eq(#sessions, count, 'failed cleanup does not allocate new IDs repeatedly')
        F.eq(#app._text_sessions, 1, 'failed ownership stays bounded')
        local _, source, failure = app.text_layout:measure_line('b', style)
        F.eq(source, 'estimate', 'cleanup fault falls back')
        F.eq(failure, 'error', 'cleanup fault classified')
        session.dispose = original
        app:refresh_text_layout()
        app:render()
        local _, recovered = app.text_layout:measure_line('b', style)
        F.eq(recovered, 'native', 'explicit refresh recovers after removal succeeds')
        app:shutdown()
    end)
end)
