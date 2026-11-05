-- Isolated real-host supplement. Batches are timed in Lua, not over IPC.
local mp = require 'mp'
local utils = require 'mp.utils'
local scripts = mp.command_native({ 'expand-path', '~~/scripts' })
package.path = package.path .. ';' .. scripts .. '/?.lua;' .. scripts .. '/?/init.lua'
    .. ';' .. scripts .. '/elxosc/?.lua;' .. scripts .. '/elxosc/?/init.lua'
package.loaded.elxlib = assert(loadfile(scripts .. '/elxlib/init.lua'))('elxlib')
local stats_mod = require 'tools.benchmark_support'
local samples_mod = require 'tools.ass_measure_samples'
local measure_mod = require 'host.ass_measure'
local now = stats_mod.now

---@param raw table
---@return table
local function coordinates(raw)
    if raw.bounds then
        local bounds = raw.bounds
        return { bounds.left, bounds.top, bounds.right, bounds.bottom }
    end
    return { raw.x0, raw.y0, raw.x1, raw.y1 }
end

mp.register_script_message('elxosc-ass-benchmark', function(legacy_path, iterations_text, warmup_text, rounds_text,
        selected_name, selected_mode)
    local report = { schema_version = 1, kind = 'ass-measure-host', scenarios = {} }
    local owned = {}
    local ok, err = pcall(function()
        local legacy_mod = assert(loadfile(legacy_path))()
        local iterations = assert(tonumber(iterations_text))
        local warmup = assert(tonumber(warmup_text))
        local rounds = assert(tonumber(rounds_text))
        report.iterations, report.warmup, report.rounds = iterations, warmup, rounds
        local bundle = samples_mod.build()
        bundle.samples[#bundle.samples + 1] = { name = 'empty', data = '', res_x = 640, res_y = 360 }
        for _, input in ipairs(bundle.samples) do
            for _, mode in ipairs({ 'same', 'changed' }) do
                if (selected_name == nil or selected_name == input.name)
                    and (selected_mode == nil or selected_mode == mode) then
                    ---@type string[]
                    local payloads = { input.data }
                    if mode == 'changed' then
                        for index = 2, 16 do
                            local changed = input.data:gsub('\\pos%(%d+,%d+%)',
                                '\\pos(' .. (50 + index) .. ',50)')
                            -- Change glyph rasterization too, rather than only placement.
                            payloads[index] = changed:gsub('\\fs[%d%.]+', '\\fs' .. (20 + index))
                        end
                    end
                    local result = { name = input.name, mode = mode, payloads = payloads, variants = {},
                        resolution = { res_x = input.res_x, res_y = input.res_y } }
                    local expected = {}
                    for round = 1, rounds do
                        -- Rotate order to reduce systematic first/last strategy bias.
                        local strategies = { 'legacy', 'overlay_update', 'native_reuse' }
                        for position = 1, #strategies do
                            local strategy = strategies[(position + round - 2) % #strategies + 1]
                            collectgarbage('collect')
                            local initial = now()
                            local service, overlay, call, dispose
                            if strategy == 'legacy' then
                                service = legacy_mod.AssMeasure()
                                local request = { name = input.name, res_x = input.res_x, res_y = input.res_y }
                                call = function(data)
                                    request.data = data
                                    local measured = service:measure(request)
                                    assert(measured.status == 'ok' or measured.status == 'empty', measured.error)
                                    return measured
                                end
                                dispose = function()
                                end
                            elseif strategy == 'overlay_update' then
                                overlay = mp.create_osd_overlay('ass-events')
                                overlay.res_x, overlay.res_y = input.res_x, input.res_y
                                overlay.hidden, overlay.compute_bounds = true, true
                                dispose = function()
                                    local _, remove_error = mp.command_native({ _name = 'osd-overlay',
                                        id = overlay.id, format = 'none', data = '' })
                                    assert(not remove_error, remove_error)
                                end
                                call = function(data)
                                    overlay.data = data
                                    local raw, command_error = overlay:update()
                                    assert(not command_error, command_error)
                                    return assert(raw)
                                end
                            else
                                service = measure_mod.AssMeasure({ res_x = input.res_x, res_y = input.res_y })
                                dispose = function()
                                    local removed, remove_error = service:dispose()
                                    assert(removed, remove_error)
                                end
                                call = function(data)
                                    return assert(service:measure(data))
                                end
                            end
                            owned[dispose] = true
                            local init_seconds = now() - initial
                            -- Measure cold request separately; its validation is outside timing.
                            local cold_start = now()
                            local cold = call(assert(payloads[1]))
                            local cold_seconds = now() - cold_start
                            for index, data in ipairs(payloads) do
                                local raw = call(data)
                                local encoded = utils.format_json(coordinates(assert(raw)))
                                expected[index] = expected[index] or encoded
                                assert(expected[index] == encoded, 'bounds mismatch: ' .. input.name .. '/' .. strategy)
                            end
                            local cold_encoded = utils.format_json(coordinates(assert(cold)))
                            assert(cold_encoded == expected[1], 'cold bounds mismatch')
                            for index = 1, warmup do
                                call(payloads[(index - 1) % #payloads + 1])
                            end
                            local samples = {}
                            local memory_before = collectgarbage('count')
                            local total_start = now()
                            for index = 1, iterations do
                                local data = payloads[(index - 1) % #payloads + 1]
                                local start = now()
                                call(data)
                                samples[index] = now() - start
                            end
                            local batch_seconds = now() - total_start
                            local memory_after = collectgarbage('count')
                            local dispose_start = now()
                            dispose()
                            owned[dispose] = nil
                            local dispose_seconds = now() - dispose_start
                            local variant = result.variants[strategy] or { rounds = {} }
                            result.variants[strategy] = variant
                            variant.rounds[#variant.rounds + 1] = { distribution = stats_mod.distribution(samples),
                                init_ms = init_seconds * 1000, cold_ms = cold_seconds * 1000,
                                dispose_ms = dispose_seconds * 1000, batch_ms = batch_seconds * 1000,
                                heap_delta_kib = memory_after - memory_before,
                                timed_native_calls = iterations * (strategy == 'legacy' and 2 or 1) }
                        end
                    end
                    result.expected_bounds = expected
                    result.output_equivalent = true
                    report.scenarios[#report.scenarios + 1] = result
                end
            end
        end
    end)
    for cleanup in pairs(owned) do
        local cleaned, cleanup_error = pcall(cleanup)
        if not cleaned then
            report.cleanup_error = tostring(cleanup_error)
        end
    end
    report.status = ok and not report.cleanup_error and 'ok' or 'error'
    if not ok then
        report.error = tostring(err)
    end
    report.environment = stats_mod.environment()
    report.environment.mpv_version = mp.get_property('mpv-version')
    report.environment.osd_dimensions = mp.get_property_native('osd-dimensions')
    mp.set_property('user-data/elxosc-ass-benchmark-report', utils.format_json(report))
end)
mp.set_property('user-data/elxosc-ass-benchmark-ready', 'yes')
