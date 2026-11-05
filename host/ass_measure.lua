-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- Explicit host utility; the application frame loop does not load this module.
local mp = require 'mp'
local std = require 'elxlibs.std'

local M = {}
local floor = math.floor

---@alias AssMeasureErrorKind
---| 'unavailable'
---| 'error'

---@class _AssMeasureOptions
---@field res_x number fixed ASS coordinate resolution, floored once
---@field res_y number

---@class AssMeasureBounds
---@field x0 number
---@field y0 number
---@field x1 number
---@field y1 number

---@alias AssMeasureRawBounds AssMeasureBounds | table<never, never>

---@class AssMeasureCommand
---@field _name string
---@field id integer
---@field format string
---@field data string
---@field res_x integer
---@field res_y integer
---@field hidden boolean
---@field compute_bounds boolean

---@param value number
---@param name string
---@return integer
local function resolution(value, name)
    if type(value) ~= 'number' or value ~= value or value == math.huge or value < 1 then
        std.raise(std.ValueError('AssMeasure.' .. name .. ' must be finite and at least 1'))
    end
    return floor(value)
end

---@class AssMeasure : std.object
---@field res_x integer
---@field res_y integer
---@field private _command AssMeasureCommand?
---@field private _command_native fun(command: table): table?, string?
---@field private _closed boolean
---@field private _error string?
---@field private _error_kind AssMeasureErrorKind?
---@overload fun(options: _AssMeasureOptions): self
local AssMeasure = std.class.new('AssMeasure', {})

function AssMeasure:__init(options)
    self.res_x = resolution(options.res_x, 'res_x')
    self.res_y = resolution(options.res_y, 'res_y')
    self._closed = false
    self._command = nil
    self._error = nil
    self._error_kind = nil
    self._command_native = mp.command_native
    if type(mp.create_osd_overlay) ~= 'function' or type(self._command_native) ~= 'function' then
        self._error = 'host lacks osd-overlay measurement API'
        self._error_kind = 'unavailable'
        return
    end
    local ok, overlay = pcall(mp.create_osd_overlay, 'ass-events')
    if not ok or type(overlay) ~= 'table' then
        self._error = tostring(overlay)
        self._error_kind = 'error'
        return
    end
    -- Use mpv's allocator, then reuse a command table instead of update's
    -- per-call field copy and resolution rounding. No fixed or borrowed ID.
    self._command = {
        _name = 'osd-overlay', id = overlay.id, format = 'ass-events', data = '',
        res_x = self.res_x, res_y = self.res_y, hidden = true, compute_bounds = true,
    }
end

--- Returns the host table unchanged, including {} for an empty image.
--- Trusted ASS comes from a generator; external input validation belongs upstream.
---@param data string
---@return AssMeasureRawBounds? bounds
---@return string? error
---@return AssMeasureErrorKind? kind
function AssMeasure:measure(data)
    if self._closed then
        return nil, 'AssMeasure is disposed', 'error'
    end
    local command = self._command
    if not command then
        return nil, self._error, self._error_kind
    end
    if type(data) ~= 'string' then
        std.raise(std.TypeError('AssMeasure.data must be a string'))
    end
    command.data = data
    local ok, raw, err = pcall(self._command_native, command)
    if not ok or err ~= nil then
        return nil, tostring(ok and err or raw), 'error'
    end
    if raw == nil then
        return nil, 'host did not return compute_bounds', 'unavailable'
    end
    if type(raw) ~= 'table' then
        return nil, 'host returned invalid compute_bounds', 'error'
    end
    return raw
end

--- Closes immediately. A failed removal retains the ID for a later dispose retry.
---@return boolean removed
---@return string? error
function AssMeasure:dispose()
    self._closed = true
    local command = self._command
    if not command then
        return false
    end
    command.data = ''
    local ok, raw, err = pcall(self._command_native, {
        _name = 'osd-overlay', id = command.id, format = 'none', data = '',
    })
    if not ok or err ~= nil then
        return false, tostring(ok and err or raw)
    end
    self._command = nil
    return true
end

M.AssMeasure = AssMeasure
return M
