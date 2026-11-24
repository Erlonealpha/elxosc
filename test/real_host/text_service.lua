-- Production App text service, environment replacement and owned cleanup.
---@namespace test.realTextService
---@using elxosc
---@using elxosc.host
local mp = require 'mp'
local utils = require 'mp.utils'
local scripts = mp.command_native({ 'expand-path', '~~/scripts' })
package.path = package.path .. ';' .. scripts .. '/?.lua;' .. scripts .. '/?/init.lua'
    .. ';' .. scripts .. '/elxosc/?.lua;' .. scripts .. '/elxosc/?/init.lua'
assert(loadfile(scripts .. '/elxosc/lib/module_loader.lua'))().install(scripts .. '/elxosc')
package.loaded.elxlib = assert(loadfile(scripts .. '/elxlib/init.lua'))('elxlib')

local native_command = mp.command_native
local allocated = mp.create_osd_overlay
local ids = {}
local removals = {}
local requests = {}
local fail_native = false
mp.create_osd_overlay = function(format)
    local overlay = allocated(format)
    ids[#ids + 1] = overlay.id
    return overlay
end
mp.command_native = function(command)
    if command._name == 'osd-overlay' then
        if command.hidden and command.compute_bounds then
            requests[#requests + 1] = { id = command.id, data = command.data,
                res_x = command.res_x, res_y = command.res_y }
            if fail_native then
                return nil, 'injected measurement failure'
            end
        elseif command.format == 'none' then
            local key = tostring(command.id)
            removals[key] = (removals[key] or 0) + 1
        end
    end
    return native_command(command)
end

local app_mod = require 'host.mpv_app'
local widgets = require 'widgets'
local TextStyle = require('src.text.text_style').TextStyle
local AssTextLayout = require('src.backends.ass_text_layout').AssTextLayout
local TextLayout = require 'src.text.text_layout'
local Offset = require('src.foundation.geometry').Offset
local explicit = AssTextLayout()
local child = widgets.Column({ children = {
    widgets.Text('AV fi 01:23', { style = TextStyle({ font_size = 18, wrap = false }) }),
    widgets.Text('explicit', { style = TextStyle({ font_size = 18, wrap = false }), text_layout = explicit }),
    widgets.Tooltip({ text = 'tooltip', style = TextStyle({ font_size = 18, wrap = false }),
        child = widgets.Text('child') }),
} })
local app = app_mod.start(function()
    return child
end)
local second

---@param node RenderObject
---@param out table
local function collect_text(node, out)
    -- Traverse mixed RenderObjects; paragraph is an optional text capability.
    local paragraph = (node --[[@as { paragraph?: Paragraph }]]).paragraph
    if paragraph then
        out[paragraph.text] = paragraph.size.width
    end
    for _, next_node in ipairs(node:children()) do
        collect_text(next_node, out)
    end
end

---@param element Element
---@return StatefulElement?
local function find_tooltip(element)
    if element.widget.__class == widgets.Tooltip then
        return element --[[@as StatefulElement]]
    end
    for _, next_element in ipairs(element:element_children()) do
        local found = find_tooltip(next_element)
        if found then
            return found
        end
    end
end

---@return table
local function snapshot()
    app:render()
    local tooltip = assert(find_tooltip(assert(app.binding.root_element)))
    local render = assert(tooltip:first_render_object())
    local offset = Offset.zero()
    local node = render
    while node.parent do
        offset = (offset + node.parent_data.offset) --[[@as Offset]]
        node = node.parent
    end
    app.owner:dispatch_pointer('move',
        (offset + Offset(render.size.width / 2, render.size.height / 2)) --[[@as Offset]])
    app:render()
    local tooltip_state = tooltip.state --[[@as TooltipState]]
    local text = {}
    collect_text(assert(app.owner.root), text)
    return { generation = app.text_layout_generation, stats = app.text_layout:cache_stats(), text = text,
        font = app.canvas.default_font_family, res_x = app.text_layout.res_x, res_y = app.text_layout.res_y,
        tooltip_width = tooltip_state._paragraph and tooltip_state._paragraph.size.width,
        tooltip_generation = tooltip_state._text_generation,
        ids = ids, removals = removals, requests = #requests, events = app.canvas:text() }
end

mp.register_script_message('elxosc-text-service', function(operation, source)
    local ok, report = pcall(function()
        if operation == 'matrix' then
            local file = assert(io.open(source, 'rb'))
            local data = file:read('*a')
            file:close()
            local bundle = assert(utils.parse_json(data))
            local samples = {}
            for _, request in ipairs(bundle.samples) do
                local style = TextStyle(request.style)
                local before = app.text_layout:cache_stats().native_calls
                local width, kind, reason = app.text_layout:measure_line(request.text, style)
                local after = app.text_layout:cache_stats().native_calls
                local repeated = app.text_layout:measure_line(request.text, style:copy_with())
                samples[#samples + 1] = { name = request.name, width = width, source = kind, reason = reason,
                    repeated = repeated, calls = after - before,
                    repeat_calls = app.text_layout:cache_stats().native_calls - after }
            end
            return { samples = samples, state = snapshot(), native_requests = requests,
                mpv = mp.get_property('mpv-version'), luajit = jit.version, elxlib = require 'elxlib.version' }
        elseif operation == 'capture' then
            return snapshot()
        elseif operation == 'pressure' then
            local times = {}
            local style = TextStyle({ font_size = 18, font_family = 'Arial', wrap = false })
            for index = 1, 800 do
                local start = mp.get_time()
                app.text_layout:line_width('value ' .. index, style)
                times[#times + 1] = (mp.get_time() - start) * 1000
            end
            return { state = snapshot(), cold_ms = times }
        elseif operation == 'fault' then
            app:refresh_text_layout()
            fail_native = true
            app:render()
            local _, kind, reason = app.text_layout:measure_line('fault', TextStyle())
            local calls = #requests
            app.text_layout:measure_line('another label', TextStyle())
            app.text_layout:measure_line('yet another label', TextStyle())
            return { source = kind, reason = reason, stopped = #requests == calls, state = snapshot() }
        elseif operation == 'recover' then
            fail_native = false
            app:refresh_text_layout()
            return snapshot()
        elseif operation == 'second' then
            second = app_mod.start(function()
                return widgets.Text('other app', { style = TextStyle({ font_size = 18, wrap = false }) })
            end)
            second:render()
            local default_unchanged = TextLayout.get_default() ~= app.text_layout
                and TextLayout.get_default() ~= second.text_layout
            app:shutdown()
            local width, kind = second.text_layout:measure_line('after close', TextStyle({ font_size = 18 }))
            second:render()
            second:shutdown()
            return { width = width, source = kind, default_unchanged = default_unchanged,
                ids = ids, removals = removals, closed_requests = #requests }
        end
        error('unknown text service operation')
    end)
    if not ok then
        report = { error = tostring(report) }
    end
    local encoded, json = pcall(utils.format_json, report)
    if not encoded then
        json = utils.format_json({ error = tostring(json) })
    end
    mp.set_property('user-data/elxosc-text-service-report', json)
end)
mp.set_property('user-data/elxosc-text-service-ready', 'yes')
