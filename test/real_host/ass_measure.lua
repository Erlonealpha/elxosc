-- Isolated tool driver. No App, frame loop or production input is started.
local mp = require 'mp'
local utils = require 'mp.utils'
local scripts = mp.command_native({ 'expand-path', '~~/scripts' })
package.path = package.path .. ';' .. scripts .. '/?.lua;' .. scripts .. '/?/init.lua'
    .. ';' .. scripts .. '/elxosc/?.lua;' .. scripts .. '/elxosc/?/init.lua'
package.loaded.elxlib = assert(loadfile(scripts .. '/elxlib/init.lua'))('elxlib')

local AssMeasure = require('host.ass_measure').AssMeasure
local samples_mod = require 'tools.ass_measure_samples'
local measure = AssMeasure()

mp.register_script_message('elxosc-ass-measure', function(path, repeats)
    local report = { schema_version = 1 }
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
            local sample = { request = input, results = {} }
            for _ = 1, assert(tonumber(repeats)) do
                sample.results[#sample.results + 1] = measure:measure(input)
            end
            report.samples[#report.samples + 1] = sample
        end
    end)
    if not ok then
        report.error = tostring(err)
    end
    report.environment = { mpv_version = mp.get_property('mpv-version'),
        ffmpeg_version = mp.get_property('ffmpeg-version'), lua_version = _VERSION,
        luajit_version = jit and jit.version or nil,
        osd_dimensions = mp.get_property_native('osd-dimensions') }
    mp.set_property('user-data/elxosc-ass-measure-report', utils.format_json(report))
end)
mp.set_property('user-data/elxosc-ass-measure-ready', 'yes')
