-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- Explicit offline measurement; never loaded by the application frame loop.
local mp = require 'mp'
local std = require 'elxlibs.std'

local M = {}
local raise = std.raise

---@alias AssMeasureStatus
---| 'ok'
---| 'empty'
---| 'unavailable'
---| 'error'

---@class AssMeasureRequest
---@field name string
---@field data string static ass-events payload; empty is allowed
---@field res_x integer
---@field res_y integer

---@class AssMeasureBounds
---@field left number
---@field top number
---@field right number
---@field bottom number
---@field width number
---@field height number

---@class AssMeasureResult
---@field name string
---@field status AssMeasureStatus
---@field res_x integer
---@field res_y integer
---@field bounds AssMeasureBounds?
---@field error string?
---@field cleanup_error string?

---@class AssMeasureOverlay
---@field id integer
---@field data string
---@field res_x integer
---@field res_y integer
---@field hidden boolean
---@field compute_bounds boolean
---@field update fun(self: AssMeasureOverlay): table?, string?

---@param value any
---@return boolean
local function finite(value)
    return type(value) == 'number' and value == value
        and value ~= math.huge and value ~= -math.huge
end

---@param request AssMeasureRequest
local function validate(request)
    if type(request) ~= 'table' then
        raise(std.TypeError('AssMeasure request must be a table'))
    end
    if type(request.name) ~= 'string' or request.name == '' then
        raise(std.ValueError('AssMeasure.name must be a non-empty string'))
    end
    if type(request.data) ~= 'string' or request.data:find('\0', 1, true) then
        raise(std.ValueError('AssMeasure.data must be a NUL-free string'))
    end
    for _, name in ipairs({ 'res_x', 'res_y' }) do
        local value = request[name]
        if not finite(value) or value <= 0 or value ~= math.floor(value) then
            raise(std.ValueError('AssMeasure.' .. name .. ' must be a positive integer'))
        end
    end
end

---@class AssMeasure : std.object
---@overload fun(): self
local AssMeasure = std.class.new('AssMeasure', {})

---@param request AssMeasureRequest
---@return AssMeasureResult
function AssMeasure:measure(request)
    validate(request)
    ---@type AssMeasureResult
    local result = { name = request.name, res_x = request.res_x, res_y = request.res_y,
        status = 'unavailable' }
    if type(mp.create_osd_overlay) ~= 'function' or type(mp.command_native) ~= 'function' then
        result.error = 'host lacks osd-overlay measurement API'
        return result
    end
    local created, overlay = pcall(mp.create_osd_overlay, 'ass-events')
    if not created or type(overlay) ~= 'table' then
        result.status = 'error'
        result.error = tostring(overlay)
        return result
    end
    local target = overlay --[[@as AssMeasureOverlay]]
    target.data, target.res_x, target.res_y = request.data, request.res_x, request.res_y
    target.hidden, target.compute_bounds = true, true
    local ok, raw, err = pcall(target.update, target)
    -- The allocator chooses our ID. Use command_native directly because mpv's
    -- overlay:remove wrapper discards the command's error return on some hosts.
    local cleaned, cleanup_result, cleanup_error = pcall(mp.command_native, {
        _name = 'osd-overlay', id = target.id, format = 'none', data = '',
    })
    if not cleaned or cleanup_error ~= nil then
        result.status = 'error'
        result.cleanup_error = tostring(cleaned and cleanup_error or cleanup_result)
    end
    if not ok or err ~= nil then
        result.status = 'error'
        result.error = tostring(ok and err or raw)
        return result
    end
    if raw == nil then
        result.error = 'host did not return compute_bounds'
        return result
    end
    if type(raw) == 'table' and next(raw) == nil then
        if result.cleanup_error == nil then
            result.status = 'empty'
        end
        return result
    end
    if type(raw) ~= 'table' or not finite(raw.x0) or not finite(raw.y0)
        or not finite(raw.x1) or not finite(raw.y1) then
        result.status = 'error'
        result.error = 'host returned invalid compute_bounds'
        return result
    end
    if raw.x1 < raw.x0 or raw.y1 < raw.y0 then
        result.status = 'error'
        result.error = 'host returned inverted compute_bounds'
        return result
    end
    result.bounds = { left = raw.x0, top = raw.y0, right = raw.x1, bottom = raw.y1,
        width = raw.x1 - raw.x0, height = raw.y1 - raw.y0 }
    if result.cleanup_error == nil then
        if result.bounds.width == 0 or result.bounds.height == 0 then
            result.status = 'empty'
        else
            result.status = 'ok'
        end
    end
    return result
end

M.AssMeasure = AssMeasure
return M
