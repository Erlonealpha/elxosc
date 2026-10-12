-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- Identity for element reuse (Flutter's `ValueKey`).
--
-- Two widgets of the same class with equal keys are considered "the same" when
-- the tree is rebuilt, so their element (and therefore their render object,
-- state, animation progress, ...) is reused instead of recreated.

local std = require 'elxlibs.std'

local M = {}

---@class Key : std.object
---@field value any
---@overload fun(value: any): self
local Key = std.class.new('Key', {})

function Key:__init(value)
    self.value = value
end

function Key:__tostring()
    return string.format('Key(%s)', tostring(self.value))
end

---@param other Key
---@return boolean
function Key:__eq(other)
    return self.value == other.value
end

M.Key = Key

return M
