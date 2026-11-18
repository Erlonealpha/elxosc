-- Bounded sustained work, environment replacement and owned resource accounting.
---@namespace test.realTextCacheEndurance
---@using elxosc
---@using elxosc.host
local mp = require 'mp'
local utils = require 'mp.utils'
local scripts = mp.command_native({ 'expand-path', '~~/scripts' })
package.path = package.path .. ';' .. scripts .. '/?.lua;' .. scripts .. '/?/init.lua'
    .. ';' .. scripts .. '/elxosc/?.lua;' .. scripts .. '/elxosc/?/init.lua'
assert(loadfile(scripts .. '/elxosc/lib/module_loader.lua'))().install(scripts .. '/elxosc')
package.loaded.elxlib = assert(loadfile(scripts .. '/elxlib/init.lua'))('elxlib')

local ids, removals = {}, {}
local allocate = mp.create_osd_overlay
mp.create_osd_overlay = function(format)
    local overlay = allocate(format)
    ids[#ids + 1] = overlay.id
    return overlay
end
local command = mp.command_native
mp.command_native = function(request)
    if request._name == 'osd-overlay' and request.format == 'none' then
        local id = tostring(request.id)
        removals[id] = (removals[id] or 0) + 1
    end
    return command(request)
end

local app_mod = require 'host.mpv_app'
local widgets = require 'widgets'
local TextStyle = require('src.text.text_style').TextStyle
local default_mod = require 'src.text.text_layout'
local families = { 'Arial', 'Courier New', 'Segoe UI' }
local app = app_mod.start(function()
    return widgets.Text('cache endurance', { style = TextStyle({ wrap = false }) })
end)
local other = app_mod.start(function()
    return widgets.Text('other App', { style = TextStyle({ wrap = false }) })
end)
local old_layouts = setmetatable({}, { __mode = 'v' })
---@type {kill: fun(self: table)}?
local timer

mp.register_script_message('elxosc-cache-endurance', function(seconds, rate)
    mp.set_property('user-data/elxosc-cache-endurance-report', '')
    local duration, target_rate = assert(tonumber(seconds)), assert(tonumber(rate))
    assert(duration >= 10 and duration <= 600 and target_rate > 0 and target_rate <= 1000)
    app:render()
    other:render()
    local start = mp.get_time()
    local count, next_sample, generation_index = 0, 0, 0
    local samples, replacements = {}, {}
    local styles = {}
    for index, family in ipairs(families) do
        styles[index] = TextStyle({ font_family = family, font_size = 18, wrap = false })
    end
    local function sample(elapsed)
        collectgarbage('collect')
        collectgarbage('collect')
        samples[#samples + 1] = { seconds = elapsed, work = count, generation = app.text_layout_generation,
            stats = app.text_layout:cache_stats(), lua_kib = collectgarbage('count') }
    end
    local function finish()
        assert(timer):kill()
        sample(mp.get_time() - start)
        app:shutdown()
        other:render()
        local width, source = other.text_layout:measure_line('other App after shutdown', styles[1])
        local isolated = other.text_layout ~= app.text_layout and default_mod.get_default() ~= other.text_layout
        other:shutdown()
        collectgarbage('collect')
        collectgarbage('collect')
        local retained = 0
        for _ in pairs(old_layouts) do
            retained = retained + 1
        end
        local report = { duration = mp.get_time() - start, target_hz = target_rate, work = count,
            actual_work_hz = count / (mp.get_time() - start), samples = samples, replacements = replacements,
            ids = ids, removals = removals, old_layouts_retained = retained,
            other = { width = width, source = source, isolated = isolated },
            final_lua_kib = collectgarbage('count'),
            environment = { mpv = mp.get_property('mpv-version'), luajit = jit.version,
                elxlib = require 'elxlib.version', osd = mp.get_property_native('osd-dimensions') } }
        mp.set_property('user-data/elxosc-cache-endurance-report', utils.format_json(report))
    end
    timer = mp.add_periodic_timer(0.01, function()
        local ok, err = pcall(function()
            local elapsed = mp.get_time() - start
            local phase = elapsed < duration / 2 and 'entries' or 'bytes'
            local next_generation = math.floor(elapsed / (duration / 4))
            if next_generation > generation_index and next_generation < 4 then
                sample(elapsed)
                old_layouts[generation_index + 1] = app.text_layout
                app:refresh_text_layout()
                app:render()
                generation_index = next_generation
                replacements[#replacements + 1] = { seconds = elapsed, generation = app.text_layout_generation,
                    stats = app.text_layout:cache_stats() }
            end
            local target = math.floor(math.min(elapsed, duration) * target_rate)
            local batch_end = math.min(target, count + 64)
            while count < batch_end do
                count = count + 1
                local label = phase == 'entries' and string.format('unique %08d AV fi', count)
                    or string.format('long %08d ', count) .. string.rep('AV fi ', 140)
                app.text_layout:measure_line(label, styles[count % #styles + 1])
            end
            if elapsed >= next_sample then
                sample(elapsed)
                next_sample = next_sample + 5
            end
            if elapsed >= duration then
                finish()
            end
        end)
        if not ok then
            assert(timer):kill()
            app:shutdown()
            other:shutdown()
            mp.set_property('user-data/elxosc-cache-endurance-report', utils.format_json({ error = tostring(err) }))
        end
    end)
end)
mp.set_property('user-data/elxosc-cache-endurance-report', '')
mp.set_property('user-data/elxosc-cache-endurance-ready', 'yes')
