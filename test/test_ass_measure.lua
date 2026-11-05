-- Resource ownership and raw host results; actual libass values use real-host.
---@diagnostic disable: undefined-field, inject-field, need-check-nil, generic-constraint-mismatch
local F = require 'framework'
local mp_stub = require 'mp_stub'
local mp = mp_stub.install()
local measure_mod = require 'host.ass_measure'
local report_mod = require 'tools.ass_measure_report'
local AssMeasure = measure_mod.AssMeasure

F.section('reusable host ASS measurement')

local function with_host(update, cleanup, body)
    local old_create, old_command = mp.create_osd_overlay, mp.command_native
    local allocations, calls = {}, {}
    mp.create_osd_overlay = function()
        local overlay = { id = 100 + #allocations }
        allocations[#allocations + 1] = overlay
        return overlay
    end
    mp.command_native = function(command)
        calls[#calls + 1] = { id = command.id, format = command.format, data = command.data,
            res_x = command.res_x, res_y = command.res_y, hidden = command.hidden,
            compute_bounds = command.compute_bounds, identity = command }
        if command.format == 'none' then
            if cleanup then
                return cleanup(command)
            end
            return {}
        end
        return update(command)
    end
    local ok, err = pcall(body, allocations, calls)
    mp.create_osd_overlay, mp.command_native = old_create, old_command
    if not ok then
        error(err, 0)
    end
end

F.test('fixed resolution and one overlay survive different payloads until dispose', function()
    local raw = { x0 = 50, y0 = 53, x1 = 126, y1 = 86 }
    with_host(function(command)
        return command.data == '' and {} or raw
    end, nil, function(allocations, calls)
        local options = { res_x = 640.8, res_y = 360.9 }
        local service = AssMeasure(options)
        F.eq(service:measure('first'), raw, 'host table returned unchanged')
        local empty = service:measure('')
        F.eq(next(assert(empty)), nil, 'empty host table stays empty')
        F.eq(service:measure('last'), raw, 'nonempty after empty')
        F.eq(#allocations, 1, 'single allocation')
        F.eq(#calls, 3, 'no per-measure removal')
        F.eq(calls[1].identity, calls[3].identity, 'native command table reused')
        F.eq(calls[1].data, 'first', 'first payload')
        F.eq(calls[2].data, '', 'empty update clears previous payload')
        F.eq(calls[3].data, 'last', 'latest payload')
        F.eq(calls[1].res_x, 640, 'resolution floored once')
        F.eq(calls[1].res_y, 360, 'height floored once')
        F.eq(options.res_x, 640.8, 'caller options untouched')
        F.ok(calls[1].hidden and calls[1].compute_bounds, 'hidden bounds mode')
        F.eq(service:dispose(), true, 'first dispose removes')
        F.eq(service:dispose(), false, 'second dispose is idempotent')
        F.eq(#calls, 4, 'three updates plus one removal')
        F.eq(calls[4].id, allocations[1].id, 'only own ID removed')
        F.eq(calls[4].format, 'none', 'remove command')
        F.eq(calls[4].data, '', 'required removal payload')
        F.eq(calls[1].identity.data, '', 'held payload reference released')
        local result, err, kind = service:measure('closed')
        F.eq(result, nil, 'disposed has no bounds')
        F.contains(err, 'disposed', 'closed reason')
        F.eq(kind, 'error', 'closed classification')
        F.eq(#calls, 4, 'disposed does not issue new commands')
    end)
end)

F.test('failure and unsupported output do not conflate an empty table', function()
    for _, case in ipairs({
        { update = function() error('host failure') end, kind = 'error' },
        { update = function() return nil, 'command rejected' end, kind = 'error' },
        { update = function() return nil end, kind = 'unavailable' },
        { update = function() return 7 end, kind = 'error' },
    }) do
        with_host(case.update, nil, function(_, calls)
            local service = AssMeasure({ res_x = 640, res_y = 360 })
            local raw, err, kind = service:measure('text')
            F.eq(raw, nil, 'failure has no fabricated bounds')
            F.ok(err ~= nil, 'failure reason retained')
            F.eq(kind, case.kind, 'error kind')
            F.eq(#calls, 1, 'instance remains owned until dispose')
            F.eq(service:dispose(), true, 'failed instance removed')
        end)
    end
end)

F.test('failed cleanup closes measurement and permits explicit cleanup retry', function()
    local attempts = 0
    with_host(function() return {} end, function()
        attempts = attempts + 1
        if attempts == 1 then
            return nil, 'remove rejected'
        end
        return {}
    end, function(_, calls)
        local service = AssMeasure({ res_x = 640, res_y = 360 })
        service:measure('payload')
        local removed, err = service:dispose()
        F.eq(removed, false, 'failed removal')
        F.eq(err, 'remove rejected', 'cleanup error retained')
        F.eq(service:measure('again'), nil, 'cleanup failure still closes')
        F.eq(#calls, 2, 'closed measure makes no command')
        F.eq(service:dispose(), true, 'explicit retry removes same resource')
        F.eq(service:dispose(), false, 'removed remains idempotent')
        F.eq(calls[2].id, calls[3].id, 'retry owns same ID')
    end)
end)

F.test('configuration is validated once and missing host is explicit', function()
    with_host(function() return {} end, nil, function(allocations)
        for _, invalid in ipairs({ 0, -1, 0.9, math.huge, -math.huge, 0 / 0, '640' }) do
            F.raises(function() AssMeasure({ res_x = invalid, res_y = 360 }) end,
                'AssMeasure.res_x', 'invalid initialization')
        end
        F.eq(#allocations, 0, 'invalid config does not allocate')
        local service = AssMeasure({ res_x = 640, res_y = 360 })
        F.raises(function()
            -- Deliberate invalid API input.
            ---@diagnostic disable-next-line: param-type-mismatch
            service:measure({})
        end, 'AssMeasure.data', 'payload type boundary')
        service:dispose()
    end)
    local old_create = mp.create_osd_overlay
    mp.create_osd_overlay = nil
    local service = AssMeasure({ res_x = 640, res_y = 360 })
    mp.create_osd_overlay = old_create
    local raw, err, kind = service:measure('')
    F.eq(raw, nil, 'missing API no bounds')
    F.contains(err, 'lacks', 'missing reason')
    F.eq(kind, 'unavailable', 'missing API classification')
    F.eq(service:dispose(), false, 'missing API owns no resource')
    mp.create_osd_overlay = function()
        error('allocation failed')
    end
    local old_command = mp.command_native
    mp.command_native = function()
    end
    service = AssMeasure({ res_x = 640, res_y = 360 })
    mp.create_osd_overlay, mp.command_native = old_create, old_command
    raw, err, kind = service:measure('')
    F.eq(raw, nil, 'allocation failure no bounds')
    F.contains(err, 'allocation failed', 'allocation failure reason')
    F.eq(kind, 'error', 'allocation classification')
    F.eq(service:dispose(), false, 'failed allocation owns no resource')
end)

F.test('diagnostic auditing is outside the raw measurement core', function()
    local request = { name = 'text', data = '', res_x = 640, res_y = 360 }
    F.eq(report_mod.result(request, {}).status, 'empty', 'empty diagnostic status')
    F.eq(report_mod.result(request, {}).bounds, nil, 'no fabricated diagnostic rectangle')
    F.eq(report_mod.result(request, nil, 'unsupported', 'unavailable').status,
        'unavailable', 'unsupported diagnostic status')
    for _, raw in ipairs({ { x0 = 0, y0 = 0, x1 = math.huge, y1 = 1 },
        { x0 = 2, y0 = 0, x1 = 1, y1 = 10 } }) do
        F.eq(report_mod.result(request, raw).status, 'error', 'diagnostic rejects invalid bounds')
    end
    local result = report_mod.result(request, { x0 = 50, y0 = 53, x1 = 126, y1 = 86 })
    F.eq(result.status, 'ok', 'valid diagnostic result')
    F.eq(result.bounds.width, 76, 'report width computed on demand')
    F.eq(result.bounds.height, 33, 'report height')
end)
