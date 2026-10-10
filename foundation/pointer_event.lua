-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- Backend-independent pointer input value.  The owner still accepts the
-- historical (event, point, data) arguments; this value gives hosts a place to
-- add fields without growing that positional interface.

local std = require 'elxlibs.std'

local M = {}

---@alias PointerEvents
--- | 'down'
--- | 'up'
--- | 'cancel'
--- | 'move'
--- | 'enter'
--- | 'leave'
--- | 'wheel'
--- | string

---@class _PointerEventFields
---@field type string
---@field point Offset?
---@field data any?

---@class PointerEvent : std.object
---@field type string
---@field point Offset?
---@field data any?
---@overload fun(type: string, point: Offset?, data: any?, extra: table?): PointerEvent
---@overload fun(fields: _PointerEventFields): PointerEvent
local PointerEvent = std.class.new('PointerEvent')

---@param type string|_PointerEventFields
---@param point Offset?
---@param data any?
---@param extra table?
---@return nil
function PointerEvent:__init(type, point, data, extra)
    if _G.type(type) == 'table' then
        local fields = type --[[@as _PointerEventFields]]
        for key, value in pairs(fields) do
            self[key] = value
        end
        return
    end
    self.type = type
    self.point = point
    self.data = data
    if extra then
        for key, value in pairs(extra) do
            self[key] = value
        end
    end
end

M.PointerEvent = PointerEvent

return M
