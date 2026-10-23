-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- A BuildScope groups dirty Elements that may be flushed by one BuildOwner pass.

local std = require 'elxlibs.std'

local M = {}

---@class BuildScope : std.object
---@field schedule_rebuild fun()?
---@field _dirty boolean
---@field _dirty_elements Element[]
---@field _dirty_set table<Element, true>
---@overload fun(schedule_rebuild: fun()?): self
local BuildScope = std.class.new('BuildScope', {})

function BuildScope:__init(schedule_rebuild)
    self.schedule_rebuild = schedule_rebuild
    self._dirty = false
    self._dirty_elements = {}
    self._dirty_set = {}
end

---@return boolean whether this was the first dirty notification
function BuildScope:mark_dirty()
    if self._dirty then
        return false
    end
    self._dirty = true
    if self.schedule_rebuild then
        self.schedule_rebuild()
    end
    return true
end

function BuildScope:clear_dirty()
    self._dirty = false
    self._dirty_elements = {}
    self._dirty_set = {}
end

---@return boolean
function BuildScope:is_dirty()
    return self._dirty
end

---@param element Element
---@return boolean whether this element was newly queued
function BuildScope:add_dirty(element)
    if self._dirty_set[element] then
        return false
    end
    self._dirty_set[element] = true
    self._dirty_elements[#self._dirty_elements + 1] = element
    self:mark_dirty()
    return true
end

---@return Element[]
function BuildScope:take_dirty()
    local dirty = self._dirty_elements
    self._dirty_elements = {}
    self._dirty_set = {}
    return dirty
end

---@return boolean
function BuildScope:has_dirty_elements()
    return #self._dirty_elements > 0
end

M.BuildScope = BuildScope

return M
