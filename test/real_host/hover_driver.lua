-- Isolated package adapter. Real rendering is retained; native input/observers are isolated.
local mp = require 'mp'
local scripts = mp.command_native({ 'expand-path', '~~/scripts' })
package.path = package.path .. ';' .. scripts .. '/?.lua;' .. scripts .. '/?/init.lua'
    .. ';' .. scripts .. '/elxosc/?.lua;' .. scripts .. '/elxosc/?/init.lua'
assert(loadfile(scripts .. '/elxosc/lib/module_loader.lua'))().install(scripts .. '/elxosc')
package.loaded.elxlib = assert(loadfile(scripts .. '/elxlib/init.lua'))('elxlib')
local schedule = mp.add_timeout
mp.register_script_message('elxosc-hover-driver', function(name, frames, path, fail_at, config)
    local options = tonumber(fail_at) and { fail_at = tonumber(fail_at) } or {}
    if config and config ~= '' then
        local file = assert(io.open(config, 'rb'))
        options = require('elxlibs.json').loads(file:read('*a'))
        file:close()
    end
    local checkpoints = {}
    if options.paced then
        options.checkpoint = function(data, width, height, seq, original)
            local overlay = original.create_osd_overlay('ass-events')
            local ok, raw, err = pcall(original.command_native, { _name = 'osd-overlay',
                id = overlay.id, format = 'ass-events', data = data, res_x = width, res_y = height,
                hidden = true, compute_bounds = true })
            overlay:remove()
            assert(ok and raw and not err, err or 'paced raster checkpoint failed')
            checkpoints[#checkpoints + 1] = { seq = seq, bounds = raw }
        end
    end
    local task = coroutine.create(function()
    if options.mode == 'table-sites' then
        options.sites = require('tools.hover_profiler').install_sites(scripts .. '/elxosc')
    end
    local driver = require 'tools.hover_driver'
    local ok, report = pcall(driver.run, mp, name, tonumber(frames) --[[@as integer]], true, options)
    if ok then
        report.paced_checkpoints = checkpoints
        -- The boundary has been restored before the independent raster check.
        local AssMeasure = require('host.ass_measure').AssMeasure
        local data = report.frames[#report.frames]
        local viewport = data and data.viewport or { 1280, 720 }
        local measure
        local checked, check_error = pcall(function()
            measure = AssMeasure({ res_x = viewport[1], res_y = viewport[2] })
            local raw, err = measure:measure(data and data.ass or '')
            assert(raw, err or 'raster measurement unavailable')
            report.native_raster = raw
            report.host_version = mp.get_property('mpv-version')
            local actual_width, actual_height = mp.get_osd_size()
            report.actual_osd = { actual_width, actual_height }
        end)
        local removed, remove_error
        if measure then
            removed, remove_error = measure:dispose()
        end
        if checked and removed and not remove_error then
            local written, write_error = pcall(driver.write, path, report)
            ok = written
            if not written then
                report = write_error
            end
        else
            ok = false
            report = check_error or remove_error or 'raster measurement cleanup failed'
        end
    end
    mp.set_property('user-data/elxosc-hover-driver-result', ok and 'ok' or tostring(report))
    end)
    local function resume()
        options.executing = true
        local ok, err = coroutine.resume(task)
        options.executing = false
        if not ok then
            mp.set_property('user-data/elxosc-hover-driver-result', tostring(err))
        elseif coroutine.status(task) ~= 'dead' then
            schedule(options.pace_seconds or 1 / 60, resume)
        end
    end
    resume()
end)
mp.set_property('user-data/elxosc-hover-driver-ready', 'yes')
