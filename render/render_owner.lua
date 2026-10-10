-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- Tree owner: the viewport, the dirty flag and the layout/paint entry points
-- (a trimmed `PipelineOwner` + `RendererBinding`).
--
-- `on_dirty` is the hook the host backend wires to its frame clock, so a dirty
-- node schedules a frame -- and an idle tree schedules nothing.

local std = require 'elxlibs.std'
local geometry = require 'foundation.geometry'
local constraints_mod = require 'layout.constraints'

local Offset = geometry.Offset
local Constraints = constraints_mod.Constraints

local M = {}

---@class RenderOwner : std.object
---@field root RenderObject?
---@field viewport Constraints
---@field on_dirty fun()?
---@overload fun(root: RenderObject?): RenderOwner
local RenderOwner = std.class.new('RenderOwner')

function RenderOwner:__init(root)
    self.root = nil
    -- A host that never calls `set_viewport` gets an unbounded box (Flutter's
    -- default `BoxConstraints()`), not a tightly infinite one.
    self.viewport = Constraints.unbounded()
    self.on_dirty = nil
    self._needs_layout = false
    self._needs_paint = false
    ---@type table<RenderObject, true>
    self._hovered = {}
    ---@type RenderObject?
    ---@type RenderObject?
    self._capture = nil
    if root then
        self:set_root(root)
    end
end

---@param root RenderObject
function RenderOwner:set_root(root)
    self:cancel_pointer()
    if self.root then
        self.root:_set_owner(nil)
    end
    self.root = root
    root:_set_owner(self)
    self:mark_needs_layout()
end

---@param constraints Constraints
function RenderOwner:set_viewport(constraints)
    self.viewport = constraints
    self:mark_needs_layout()
end

function RenderOwner:mark_needs_layout()
    self._needs_layout = true
    self._needs_paint = true
    if self.on_dirty then
        self.on_dirty()
    end
end

function RenderOwner:mark_needs_paint()
    self._needs_paint = true
    if self.on_dirty then
        self.on_dirty()
    end
end

---@return boolean
function RenderOwner:needs_layout()
    return self._needs_layout
end

---@return boolean
function RenderOwner:needs_paint()
    return self._needs_paint
end

--- Lay the tree out when the viewport changed or anything was marked dirty.
function RenderOwner:layout()
    local root = self.root
    if root == nil then
        return
    end
    if not self._needs_layout and root.constraints == self.viewport then
        return
    end
    self._needs_layout = false
    self._needs_paint = true
    root:layout(self.viewport)
end

---@param canvas Canvas
function RenderOwner:paint(canvas)
    if self.root and self._needs_paint then
        self.root:paint(canvas, Offset.zero())
        self._needs_paint = false
    end
end

--== pointer routing ======================================================

---@param point Offset
---@return {node: RenderObject, point: Offset}[]
function RenderOwner:pointer_path(point)
    if not self.root then
        return {}
    end
    return self.root:pointer_path(point)
end

---@param event string
---@param point Offset
---@return boolean
function RenderOwner:wants_pointer(event, point)
    for _, entry in ipairs(self:pointer_path(point)) do
        if entry.node:wants_pointer(event) then
            return true
        end
    end
    return false
end

--- Route a pointer event down the tree. `move` bubbles and drives hover
--- tracking (`enter`/`leave`); every other event stops at the first node that
--- handles it.
---@param event string
---@param point Offset
---@param data any?
---@return boolean handled
---@overload fun(event: PointerEvent): boolean
function RenderOwner:dispatch_pointer(event, point, data)
    if type(event) == 'table' then
        local pointer = event
        event, point, data = pointer.type, pointer.point, pointer.data
    end
    local path = self:pointer_path(point)
    if event == 'move' then
        self:_update_hover(path)
        if self._capture then
            for _, entry in ipairs(path) do
                if entry.node == self._capture then
                    self._capture:on_pointer('move', entry.point, data)
                    return true
                end
            end
            self._capture:on_pointer('move', nil, data)
            return true
        end
        for _, entry in ipairs(path) do
            entry.node:on_pointer('move', entry.point, data)
        end
        return #path > 0
    end
    if event == 'down' then
        self:cancel_pointer()
    elseif event == 'up' or event == 'cancel' then
        local captured = self._capture
        self._capture = nil
        if captured then
            local local_point
            for _, entry in ipairs(path) do
                if entry.node == captured then
                    local_point = entry.point
                    break
                end
            end
            captured:on_pointer(event, local_point, data)
            return true
        end
    end
    for _, entry in ipairs(path) do
        if entry.node:on_pointer(event, entry.point, data) then
            if event == 'down' then
                self._capture = entry.node
            end
            return true
        end
    end
    return false
end

--- Cancel a pending press when the host loses the pointer or the root changes.
function RenderOwner:cancel_pointer()
    if self._capture then
        self._capture:on_pointer('cancel', nil)
        self._capture = nil
    end
end

--- Mark every currently hovered node as left (pointer left the window).
function RenderOwner:clear_hover()
    self:cancel_pointer()
    for node in pairs(self._hovered) do
        node:on_pointer('leave', nil)
    end
    self._hovered = {}
end

---@param path {node: RenderObject, point: Offset}[]
function RenderOwner:_update_hover(path)
    local current = {}
    for _, entry in ipairs(path) do
        current[entry.node] = true
    end
    for node in pairs(self._hovered) do
        if not current[node] then
            node:on_pointer('leave', nil)
        end
    end
    for _, entry in ipairs(path) do
        if not self._hovered[entry.node] then
            entry.node:on_pointer('enter', entry.point)
        end
    end
    self._hovered = current
end

M.RenderOwner = RenderOwner

return M
