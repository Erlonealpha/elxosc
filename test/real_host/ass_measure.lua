-- Isolated tool driver. No App, frame loop or production input is started.
local mp = require 'mp'
local utils = require 'mp.utils'
local scripts = mp.command_native({ 'expand-path', '~~/scripts' })
package.path = package.path .. ';' .. scripts .. '/?.lua;' .. scripts .. '/?/init.lua'
    .. ';' .. scripts .. '/elxosc/?.lua;' .. scripts .. '/elxosc/?/init.lua'
package.loaded.elxlib = assert(loadfile(scripts .. '/elxlib/init.lua'))('elxlib')

local measure_mod = require 'host.ass_measure'
local AssMeasure = measure_mod.AssMeasure
local samples_mod = require 'tools.ass_measure_samples'
local report_mod = require 'tools.ass_measure_report'

mp.register_script_message('elxosc-ass-measure', function(path, repeats)
    local report = { schema_version = 1 }
    local services = {}
    local ok, err = pcall(function()
        local bundle
        if path == '' then
            bundle = samples_mod.build()
        else
            local file = assert(io.open(path, 'rb'))
            local contents = file:read('*a')
            file:close()
            bundle = assert(utils.parse_json(contents))
        end
        report.scene, report.scene_version = bundle.scene, bundle.scene_version
        report.samples = {}
        for _, input in ipairs(bundle.samples) do
            local key = input.res_x .. 'x' .. input.res_y
            local service = services[key]
            if not service then
                service = AssMeasure({ res_x = input.res_x, res_y = input.res_y })
                services[key] = service
            end
            local sample = { request = input, results = {} }
            for _ = 1, assert(tonumber(repeats)) do
                sample.results[#sample.results + 1] = report_mod.result(input, service:measure(input.data))
            end
            report.samples[#report.samples + 1] = sample
        end
    end)
    if not ok then
        report.error = tostring(err)
    end
    report.lifecycle = { instances = 0, removed = 0 }
    for key, service in pairs(services) do
        report.lifecycle.instances = report.lifecycle.instances + 1
        local removed, cleanup_error = service:dispose()
        if removed then
            report.lifecycle.removed = report.lifecycle.removed + 1
        end
        if cleanup_error then
            report.error = 'measurement cleanup failed: ' .. cleanup_error
            for _, sample in ipairs(report.samples or {}) do
                if sample.request.res_x .. 'x' .. sample.request.res_y == key then
                    for _, result in ipairs(sample.results) do
                        result.status = 'error'
                        result.cleanup_error = cleanup_error
                    end
                end
            end
        end
    end
    report.environment = { mpv_version = mp.get_property('mpv-version'),
        ffmpeg_version = mp.get_property('ffmpeg-version'), lua_version = _VERSION,
        luajit_version = jit and jit.version or nil,
        osd_dimensions = mp.get_property_native('osd-dimensions') }
    mp.set_property('user-data/elxosc-ass-measure-report', utils.format_json(report))
end)
mp.set_property('user-data/elxosc-ass-measure-ready', 'yes')
