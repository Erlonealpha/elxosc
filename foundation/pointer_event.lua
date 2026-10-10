-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- Backend-independent pointer input value.  The owner still accepts the
-- historical (event, point, data) arguments; this value gives hosts a place to
-- add fields without growing that positional interface.

local std = require 'elxlibs.std'

---@class elxfoundationpointerevent
local M = {}

---@class PointerEvent : std.object
---@field type string
---@field point Offset?
---@field data any?
---@overload fun(type: string, point: Offset?, data: any?, extra: table?): PointerEvent
---@overload fun(fields: table): PointerEvent
local PointerEvent = std.class.new('PointerEvent')

function PointerEvent:__init(type, point, data, extra)
    if _G.type(type) == 'table' then
        for key, value in pairs(type) do
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
