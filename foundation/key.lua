-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- Widget identity primitives shared by the framework.  Keys are deliberately
-- host-free: BuildOwner owns the scope in which a key is registered, while
-- the key only describes identity.

local std = require 'elxlibs.std'

local M = {}
local rawequal = rawequal
local kindof = std.kindof

---@class Key : std.object
---@field value any?
---@overload fun(value: any?): self
local Key = std.class.new('Key', {})

function Key:__init(value)
    self.value = value
end

---@param other any
---@return boolean
function Key:__eq(other)
    return kindof(other, 'object')
        and other.__class == self.__class
        and self.value == other.value
end

function Key:__tostring()
    local class = rawget(self --[[@as table]], '__class')
    local name = rawget(self --[[@as table]], '__name')
        or (class and rawget(class --[[@as table]], '__name')) or 'Key'
    return string.format('%s(%s)', name, tostring(self.value))
end

---@class LocalKey : Key
---@overload fun(value: any?): self
local LocalKey = std.class.new('LocalKey', { Key })

---@class ValueKey : LocalKey
---@overload fun(value: any): self
local ValueKey = std.class.new('ValueKey', { LocalKey })

function ValueKey:__init(value)
    self.value = value
end

---@param other any
---@return boolean
function ValueKey:__eq(other)
    return kindof(other, 'object')
        and other.__class == self.__class
        and self.value == other.value
end

function ValueKey:__tostring()
    return string.format('ValueKey(%s)', tostring(self.value))
end

---@class UniqueKey : LocalKey
---@overload fun(): self
local UniqueKey = std.class.new('UniqueKey', { LocalKey })

---@param other any
---@return boolean
function UniqueKey:__eq(other)
    return rawequal(self, other)
end

function UniqueKey:__tostring()
    return 'UniqueKey'
end

M.Key = Key
M.LocalKey = LocalKey
M.ValueKey = ValueKey
M.UniqueKey = UniqueKey

return M
