-- Isolated package adapter. Real rendering is retained; native input/observers are isolated.
local mp = require 'mp'
local scripts = mp.command_native({ 'expand-path', '~~/scripts' })
package.path = package.path .. ';' .. scripts .. '/?.lua;' .. scripts .. '/?/init.lua'
    .. ';' .. scripts .. '/elxosc/?.lua;' .. scripts .. '/elxosc/?/init.lua'
assert(loadfile(scripts .. '/elxosc/lib/module_loader.lua'))().install(scripts .. '/elxosc')
package.loaded.elxlib = assert(loadfile(scripts .. '/elxlib/init.lua'))('elxlib')
local driver = require 'tools.hover_driver'
mp.register_script_message('elxosc-hover-driver', function(name, frames, path, fail_at)
    local options = tonumber(fail_at) and { fail_at = tonumber(fail_at) } or nil
    local ok, report = pcall(driver.run, mp, name, tonumber(frames) --[[@as integer]], true, options)
    if ok then
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
mp.set_property('user-data/elxosc-hover-driver-ready', 'yes')
