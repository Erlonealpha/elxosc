-- Host measurement failure and cleanup contract; libass values require real-host.
---@diagnostic disable: undefined-field, inject-field, need-check-nil, generic-constraint-mismatch
local F = require 'framework'
local mp_stub = require 'mp_stub'
local mp = mp_stub.install()
local AssMeasure = require('host.ass_measure').AssMeasure

F.section('host ASS measurement')

local function request()
    return { name = 'text', data = '{\\an7\\pos(50,50)}text', res_x = 640, res_y = 360 }
end

local function with_host(update, cleanup, body)
    local old_create, old_command = mp.create_osd_overlay, mp.command_native
    local overlays, removed = {}, {}
    mp.create_osd_overlay = function()
        local overlay = { id = 100 + #overlays, update = update }
        overlays[#overlays + 1] = overlay
        return overlay
    end
    mp.command_native = function(command)
        removed[#removed + 1] = command
        if cleanup then
            return cleanup(command)
        end
    end
    local ok, err = pcall(body, overlays, removed)
    mp.create_osd_overlay, mp.command_native = old_create, old_command
    if not ok then
        error(err, 0)
    end
end

F.test('measurement uses a hidden owned overlay and does not mutate input', function()
    with_host(function() return { x0 = 50, y0 = 53, x1 = 126, y1 = 86 } end, nil,
        function(overlays, removed)
            local input = request()
            local result = AssMeasure():measure(input)
            F.eq(result.status, 'ok', 'measurement status')
            F.eq(result.bounds.width, 76, 'host width')
            F.eq(result.bounds.height, 33, 'host height')
            F.eq(result.bounds.left, 50, 'host origin is retained')
            F.eq(overlays[1].data, input.data, 'payload is unchanged')
            F.ok(overlays[1].hidden and overlays[1].compute_bounds, 'invisible measurement')
            F.eq(overlays[1].res_x, 640, 'request resolution')
            F.eq(removed[1].id, overlays[1].id, 'only allocated overlay removed')
            F.eq(removed[1].format, 'none', 'remove protocol')
            F.eq(removed[1].data, '', 'remove command supplies required data')
            F.eq(input.hidden, nil, 'caller input remains untouched')
            AssMeasure():measure(input)
            F.eq(#overlays, 2, 'each request owns a separate allocation')
            F.eq(#removed, 2, 'every allocation is cleaned')
        end)
end)

F.test('empty and absent bounds stay distinct', function()
    with_host(function() return {} end, nil, function()
        local result = AssMeasure():measure(request())
        F.eq(result.status, 'empty', 'mpv empty-table result')
        F.eq(result.bounds, nil, 'empty table does not invent a zero rectangle')
    end)
    with_host(function() return { x0 = 0, y0 = 0, x1 = 0, y1 = 0 } end, nil, function()
        F.eq(AssMeasure():measure(request()).status, 'empty', 'valid empty bounds')
    end)
    with_host(function() return nil end, nil, function(_, removed)
        local result = AssMeasure():measure(request())
        F.eq(result.status, 'unavailable', 'unsupported compute_bounds')
        F.eq(result.bounds, nil, 'no invented rectangle')
        F.eq(#removed, 1, 'unsupported command is cleaned')
    end)
end)

F.test('command exceptions and returned errors are cleaned and reported', function()
    for _, update in ipairs({
        function() error('host failure') end,
        function() return nil, 'command rejected' end,
        function() return { x0 = 0, y0 = 0, x1 = math.huge, y1 = 10 } end,
        function() return { x0 = 2, y0 = 0, x1 = 1, y1 = 10 } end,
    }) do
        with_host(update, nil, function(_, removed)
            local result = AssMeasure():measure(request())
            F.eq(result.status, 'error', 'failure status')
            F.ok(result.error ~= nil, 'failure reason')
            F.eq(result.bounds, nil, 'failure has no bounds')
            F.eq(#removed, 1, 'failed measurement cleanup')
        end)
    end
end)

F.test('cleanup failure cannot be reported as success', function()
    with_host(function() return { x0 = 0, y0 = 0, x1 = 10, y1 = 10 } end,
        function() return nil, 'remove rejected' end, function()
            local result = AssMeasure():measure(request())
            F.eq(result.status, 'error', 'cleanup failure status')
            F.eq(result.cleanup_error, 'remove rejected', 'cleanup reason')
            F.eq(result.bounds.width, 10, 'observed bounds retained for diagnosis')
        end)
end)

F.test('missing host API and allocation failures have explicit results', function()
    local old_create = mp.create_osd_overlay
    mp.create_osd_overlay = nil
    local result = AssMeasure():measure(request())
    mp.create_osd_overlay = old_create
    F.eq(result.status, 'unavailable', 'host lacks measurement API')
    F.eq(result.bounds, nil, 'unavailable has no invented bounds')
    mp.create_osd_overlay = function() error('allocation failed') end
    local old_command = mp.command_native
    mp.command_native = function() end
    result = AssMeasure():measure(request())
    mp.create_osd_overlay, mp.command_native = old_create, old_command
    F.eq(result.status, 'error', 'allocation failure status')
    F.contains(result.error, 'allocation failed', 'allocation error retained')
end)

F.test('invalid input is rejected before allocating an overlay', function()
    with_host(function() end, nil, function(overlays)
        for _, pair in ipairs({ { 'name', '' }, { 'data', 'a\0b' }, { 'res_x', 0 },
            { 'res_y', 2.5 }, { 'res_x', math.huge } }) do
            local input = request()
            input[pair[1]] = pair[2]
            F.raises(function() AssMeasure():measure(input) end, 'AssMeasure.', 'invalid boundary')
        end
        F.eq(#overlays, 0, 'no host calls for invalid inputs')
    end)
end)
