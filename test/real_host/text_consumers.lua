-- Real player layout/input with inspectable text targets and frame stage counters.
---@namespace test.realTextConsumers
---@using elxosc
---@using elxosc.player
local mp = require 'mp'
local utils = require 'mp.utils'
local scripts = mp.command_native({ 'expand-path', '~~/scripts' })
package.path = package.path .. ';' .. scripts .. '/?.lua;' .. scripts .. '/?/init.lua'
    .. ';' .. scripts .. '/elxosc/?.lua;' .. scripts .. '/elxosc/?/init.lua'
assert(loadfile(scripts .. '/elxosc/lib/module_loader.lua'))().install(scripts .. '/elxosc')
package.loaded.elxlib = assert(loadfile(scripts .. '/elxlib/init.lua'))('elxlib')

local std = require 'elxlibs.std'
local app_mod = require 'host.mpv_player_app'
local player = require 'player'
local geometry = require 'src.foundation.geometry'
local Offset = geometry.Offset
local text_mod = require 'src.render.text'
local store = player.PlayerStore({ time_pos = 12.25, duration = 3600, percent_pos = 12.25 / 36,
    file_size = 2048, media_title = 'short title', pause = true })
local source = player.DefaultApp({ main = player.Main({ scale = 1 }), auto_hide_enabled = false })
local app = app_mod.start(function()
    return source
end, { player_store = store, actions = player.HostActions({ seek_to = function() end }) })
local paint_depth = 0
local painted_measurements = 0
local preparation_count = 0
local layouts = 0
local measure = app.text_layout.measure_line
-- This layout instance is only used by the isolated test driver.
-- Dynamic test instrumentation preserves method signatures and identity.
do
    local instrumented_layout = app.text_layout --[[@as table<string, any>]]
    instrumented_layout.measure_line = function(self, ...)
        if paint_depth > 0 then
            painted_measurements = painted_measurements + 1
        end
        return measure(self, ...)
    end
end
local paint = app.owner.paint
do
    local instrumented_owner = app.owner --[[@as table<string, any>]]
    instrumented_owner.paint = function(self, ...)
        paint_depth = paint_depth + 1
        local result = paint(self, ...)
        paint_depth = paint_depth - 1
        return result
    end
end

local function visit(element, class, list)
    list = list or {}
    if element.widget.__class == class then
        list[#list + 1] = element
    end
    for _, child in ipairs(element:element_children()) do
        visit(child, class, list)
    end
    return list
end

local function has_descendant(root, target)
    if root == target then
        return true
    end
    for _, child in ipairs(root:children()) do
        if has_descendant(child, target) then
            return true
        end
    end
    return false
end

local function rect_of(element)
    local root = assert(element:first_render_object())
    for _, region in ipairs(app.owner:pointer_regions()) do
        if region.down and has_descendant(root, region.node) then
            local rect = region.rect
            return { left = rect.left, top = rect.top, right = rect.right, bottom = rect.bottom }
        end
    end
end

local function labels(node, out)
    if std.isinstance(node, text_mod.RenderText) and node.paragraph then
        out[#out + 1] = { text = node.paragraph.text, width = node.paragraph.size.width,
            box_width = node.size.width, clipped = node.clip }
    end
    for _, child in ipairs(node:children()) do
        labels(child, out)
    end
end

local function report()
    app:render()
    local root = assert(app.binding.root_element)
    local times = visit(root, player.PlayerTimeDisplay)
    local description = visit(root, player.PlayerDescriptionLayer)[1]
    local output = {}
    labels(assert(app.owner.root), output)
    return { left = rect_of(times[1]), right = rect_of(times[2]),
        description = description and rect_of(description),
        description_bounds = description and { left = description.widget.bounds.left,
            right = description.widget.bounds.right, top = description.widget.bounds.top,
            bottom = description.widget.bounds.bottom },
        panel_open = description and description.state.open, labels = output,
        left_ms = times[1].state.show_milliseconds, remaining = times[2].state.show_remaining,
        cache = app.text_layout:cache_stats(), painted_measurements = painted_measurements,
        preparation_count = preparation_count, layouts = layouts }
end

local function install_counters()
    local root = assert(app.binding.root_element)
    for _, element in ipairs(visit(root, player.PlayerTooltip)) do
        local state = element.state
        local prepare = state._prepare_text
        state._prepare_text = function(self)
            preparation_count = preparation_count + 1
            return prepare(self)
        end
    end
    local measured_root = assert(app.owner.root) --[[@as table<string, any>]]
    local root_layout = measured_root.__perform_layout
    measured_root.__perform_layout = function(self, constraints)
        layouts = layouts + 1
        return root_layout(self, constraints)
    end
end

local instrumented = false
mp.register_script_message('elxosc-consumers', function(operation, value)
    local ok, result = pcall(function()
        app:render()
        if not instrumented then
            install_counters()
            instrumented = true
        end
        if operation == 'batch' then
            local before = report()
            local timeline = visit(assert(app.binding.root_element), player.Timeline)[1]
            local rect = assert(rect_of(timeline))
            local y = (rect.top + rect.bottom) / 2
            for index = 1, 10 do
                app.owner:dispatch_pointer('move', Offset(rect.left + (rect.right - rect.left) * index / 20, y))
            end
            local dispatched = app.text_layout:cache_stats().native_calls
            local after = report()
            local prepared = after.preparation_count - before.preparation_count
            app.owner:dispatch_pointer('move', Offset((rect.left + rect.right) / 2, y + 1))
            local repeated = report()
            return { prepared = prepared, dispatch_native = dispatched - before.cache.native_calls,
                layout_delta = after.layouts - before.layouts, paint_native = after.painted_measurements,
                repeat_native = repeated.cache.native_calls - after.cache.native_calls,
                repeat_prepare = repeated.preparation_count - after.preparation_count,
                after = after }
        elseif operation == 'position' then
            local position = assert(tonumber(value))
            store:replace(store:get():copy({ time_pos = position, percent_pos = position / 36 }))
        end
        return report()
    end)
    if not ok then
        result = { error = tostring(result) }
    end
    mp.set_property('user-data/elxosc-consumers-report', utils.format_json(result))
end)
mp.set_property('user-data/elxosc-consumers-ready', 'yes')
