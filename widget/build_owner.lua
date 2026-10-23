-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- Owns the dirty element queue (Flutter's `BuildOwner`).
--
-- `set_state` only marks elements dirty; the actual rebuild happens once per
-- frame in depth order, so a parent rebuild that updates its children clears
-- their dirty flags and they are not built twice.

local std = require 'elxlibs.std'
local build_scope_mod = require 'widget.build_scope'
local key_mod = require 'widget.key'

local M = {}
local BuildScope = build_scope_mod.BuildScope
local GlobalKey = key_mod.GlobalKey

---@class BuildOwner : std.object
---@field render_owner RenderOwner?
---@field scheduler Scheduler?
---@field on_dirty fun()?
---@field on_diagnostic fun(message: string, value: any?)?
---@field root_scope BuildScope
---@field global_key_registry table<GlobalKey, Element>
---@field diagnostics string[]
---@field _scopes table<BuildScope, true>
---@field _dirty_scopes table<BuildScope, true>
---@field _dirty_scope_order BuildScope[]
---@overload fun(render_owner: RenderOwner?, scheduler: Scheduler?): self
local BuildOwner = std.class.new('BuildOwner', {})

function BuildOwner:__init(render_owner, scheduler)
    self.render_owner = render_owner
    self.scheduler = scheduler
    self.on_dirty = nil
    self.on_diagnostic = nil
    self._scopes = {}
    self._dirty_scopes = {}
    self._dirty_scope_order = {}
    self.root_scope = self:create_build_scope()
    self.global_key_registry = {}
    self.diagnostics = {}
    self._inactive = {}
    self._building = false
end

---@param scope BuildScope
function BuildOwner:_scope_dirtied(scope)
    if self._dirty_scopes[scope] then
        return
    end
    self._dirty_scopes[scope] = true
    self._dirty_scope_order[#self._dirty_scope_order + 1] = scope
    if self.on_dirty then
        self.on_dirty()
    end
end

---@param schedule_rebuild fun()?
---@return BuildScope
function BuildOwner:create_build_scope(schedule_rebuild)
    ---@type BuildScope?
    local scope
    scope = BuildScope(function()
        self:_scope_dirtied(scope --[[@as BuildScope]])
        if schedule_rebuild then
            schedule_rebuild()
        end
    end)
    self._scopes[scope] = true
    return scope
end

---@return boolean
function BuildOwner:is_building()
    return self._building
end

---@param message string
---@param value any?
function BuildOwner:diagnose(message, value)
    self.diagnostics[#self.diagnostics + 1] = message
    if self.on_diagnostic then
        self.on_diagnostic(message, value)
    end
end

---@param key GlobalKey
---@param element Element
function BuildOwner:register_global_key(key, element)
    local current = self.global_key_registry[key]
    if current and current ~= element then
        error(string.format('GlobalKey %s is already registered in this BuildOwner', key), 2)
    end
    self.global_key_registry[key] = element
    key:_register(self, element)
end

---@param key GlobalKey
---@param element Element
function BuildOwner:unregister_global_key(key, element)
    if self.global_key_registry[key] == element then
        self.global_key_registry[key] = nil
    end
    key:_unregister(self, element)
end

---@param element Element
function BuildOwner:add_inactive(element)
    self._inactive[element] = true
end

---@param element Element
function BuildOwner:remove_inactive(element)
    self._inactive[element] = nil
end

function BuildOwner:finalize_tree()
    local inactive = self._inactive
    self._inactive = {}
    for element in pairs(inactive) do
        if element.mounted and not element.active then
            element:unmount()
        end
    end
end

---@param element Element
function BuildOwner:schedule_build_for(element)
    if element.build_scope == nil then
        element.build_scope = self.root_scope
    end
    local scope = element.build_scope
    if not self._scopes[scope] then
        self._scopes[scope] = true
    end
    scope:add_dirty(element)
end

---@return boolean
function BuildOwner:has_dirty()
    for scope in pairs(self._dirty_scopes) do
        if scope:has_dirty_elements() then
            return true
        end
    end
    return false
end

function BuildOwner:clear_dirty()
    for scope in pairs(self._scopes) do
        scope:clear_dirty()
    end
    self._dirty_scopes = {}
    self._dirty_scope_order = {}
end

---@param scope BuildScope
function BuildOwner:_rebuild_scope(scope)
    while scope:has_dirty_elements() do
        local dirty = scope:take_dirty()
        table.sort(dirty, function(a, b)
            return a.depth < b.depth
        end)
        for _, element in ipairs(dirty) do
            if element.mounted and element.active and element.dirty
                and element.build_scope == scope then
                element:rebuild()
            end
        end
    end
    scope:clear_dirty()
end

---@return BuildScope?
function BuildOwner:_take_dirty_scope()
    while #self._dirty_scope_order > 0 do
        local scope = table.remove(self._dirty_scope_order, 1)
        if self._dirty_scopes[scope] then
            self._dirty_scopes[scope] = nil
            return scope
        end
    end
    return nil
end

--- Rebuild every dirty element that was not already refreshed by an ancestor.
---@param scope BuildScope?
function BuildOwner:rebuild_dirty(scope)
    if self._building then
        error('BuildOwner.rebuild_dirty() is not reentrant', 2)
    end
    self._building = true
    local ok, err = pcall(function()
        if scope then
            self._dirty_scopes[scope] = nil
            self:_rebuild_scope(scope)
        else
            while true do
                local dirty_scope = self:_take_dirty_scope()
                if not dirty_scope then
                    break
                end
                self:_rebuild_scope(dirty_scope)
            end
        end
    end)
    self._building = false
    if not ok then
        error(err, 0)
    end
end

M.BuildOwner = BuildOwner

return M
