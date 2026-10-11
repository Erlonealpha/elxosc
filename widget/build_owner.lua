-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- Owns the dirty element queue (Flutter's `BuildOwner`).
--
-- `set_state` only marks elements dirty; the actual rebuild happens once per
-- frame in depth order, so a parent rebuild that updates its children clears
-- their dirty flags and they are not built twice.

local std = require 'elxlibs.std'

local M = {}

---@class BuildOwner : std.object
---@field render_owner RenderOwner?
---@field scheduler Scheduler?
---@field on_dirty fun()?
---@overload fun(render_owner: RenderOwner?, scheduler: Scheduler?): BuildOwner
local BuildOwner = std.class.new('BuildOwner')

function BuildOwner:__init(render_owner, scheduler)
    self.render_owner = render_owner
    self.scheduler = scheduler
    self.on_dirty = nil
    self._dirty = {}
    self._dirty_set = {}
end

---@param element Element
function BuildOwner:schedule_build_for(element)
    if not self._dirty_set[element] then
        self._dirty_set[element] = true
        self._dirty[#self._dirty + 1] = element
    end
    if self.on_dirty then
        self.on_dirty()
    end
end

---@return boolean
function BuildOwner:has_dirty()
    return #self._dirty > 0
end

--- Rebuild every dirty element that was not already refreshed by an ancestor.
function BuildOwner:rebuild_dirty()
    if #self._dirty == 0 then
        return
    end
    local dirty = self._dirty
    self._dirty = {}
    self._dirty_set = {}
    table.sort(dirty, function(a, b)
        return a.depth < b.depth
    end)
    for _, element in ipairs(dirty) do
        if element.mounted and element.dirty then
            element:rebuild()
        end
    end
end

M.BuildOwner = BuildOwner

return M
