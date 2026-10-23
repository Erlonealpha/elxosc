-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- Widget identity exports.  Foundation owns the local key hierarchy; widget
-- keys add ObjectKey and GlobalKey because those keys observe widget-tree
-- ownership.
--
-- Two widgets of the same class with equal keys are considered "the same" when
-- the tree is rebuilt, so their element (and therefore their render object,
-- state, animation progress, ...) is reused instead of recreated.

local std = require 'elxlibs.std'
local foundation_key = require 'foundation.key'

local M = {}
local kindof = std.kindof

local LocalKey = foundation_key.LocalKey
local Key = foundation_key.Key

local ObjectKey = std.class.new('ObjectKey', { LocalKey })

function ObjectKey:__init(value)
    self.value = value
end

---@param other any
---@return boolean
function ObjectKey:__eq(other)
    return kindof(other, 'object')
        and other.__class == self.__class
        and rawequal(self.value, other.value)
end

function ObjectKey:__tostring()
    return string.format('ObjectKey(%s)', tostring(self.value))
end

local GlobalKey = std.class.new('GlobalKey', { Key })

function GlobalKey:__init(debug_label)
    self.value = nil
    self.debug_label = debug_label
    self._registrations = {}
end

---@param other any
---@return boolean
function GlobalKey:__eq(other)
    return rawequal(self, other)
end

function GlobalKey:__tostring()
    if self.debug_label then
        return string.format('GlobalKey(%s)', self.debug_label)
    end
    return 'GlobalKey'
end

---@param owner BuildOwner
---@param element Element
function GlobalKey:_register(owner, element)
    local current = self._registrations[owner]
    if current and current ~= element then
        error(string.format('GlobalKey %s is already registered in this BuildOwner', self), 2)
    end
    self._registrations[owner] = element
end

---@param owner BuildOwner
---@param element Element
function GlobalKey:_unregister(owner, element)
    if self._registrations[owner] == element then
        self._registrations[owner] = nil
    end
end

---@return Element?
function GlobalKey:current_element()
    for _, element in pairs(self._registrations) do
        if element:is_active() then
            return element
        end
    end
    return nil
end

---@return Widget?
function GlobalKey:current_widget()
    local element = self:current_element()
    return element and element.widget or nil
end

---@return State?
function GlobalKey:current_state()
    local element = self:current_element()
    return element and element.state or nil
end

---@return BuildContext?
function GlobalKey:current_context()
    return self:current_element()
end

for name, value in pairs(foundation_key) do
    M[name] = value
end
M.ObjectKey = ObjectKey
M.GlobalKey = GlobalKey

return M
