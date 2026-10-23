-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- Glue between the widget tree and a `PipelineOwner` (a trimmed
-- `WidgetsBinding` without any host dependency).
--
-- Once per frame the host calls `flush_build()` before layout/paint; `on_dirty`
-- is the hook the host wires to its frame clock, exactly like
-- `PipelineOwner.on_dirty`.

local std = require 'elxlibs.std'
local binding_base = require 'foundation.binding_base'
local build_owner_mod = require 'widget.build_owner'
local widget_mod = require 'widget.widget'
-- Loading the element module also installs `Widget:create_element` (see the
-- wiring section at the bottom of widget/element.lua).
require 'widget.element'

local BuildOwner = build_owner_mod.BuildOwner
local can_update = widget_mod.can_update
local BindingBase = binding_base.BindingBase

local M = {}

---@class WidgetsBinding : std.object
---@field render_owner RenderOwner
---@field build_owner BuildOwner
---@field root_element Element?
---@field on_dirty fun()?
---@field _disposed boolean
---@overload fun(root_widget: Widget, render_owner: RenderOwner, binds: BindRegistry?, scheduler: Scheduler?): self
local WidgetBinding = std.class.new('WidgetsBinding', { BindingBase })

function WidgetBinding:__init(root_widget, render_owner, binds, scheduler)
    ---@diagnostic disable-next-line: param-type-mismatch, generic-constraint-mismatch
    std.super(WidgetBinding, self, BindingBase).__init(self)
    self.render_owner = render_owner
    self.build_owner = BuildOwner(render_owner, scheduler)
    self.root_element = nil
    self.on_dirty = nil
    self._disposed = false
    self.build_owner.on_dirty = function()
        if self.on_dirty then
            self.on_dirty()
        end
    end
    if binds then
        binds:apply(root_widget)
    end
    self:_mount(root_widget)
end

--- Replace the root widget (the old tree is discarded).
---@param widget Widget
function WidgetBinding:set_root_widget(widget)
    if self._disposed then
        return
    end
    local element = self.root_element
    if element and can_update(element.widget, widget) then
        element:update(widget)
    else
        if element then
            element:unmount()
        end
        element = widget:create_element()
        element:mount(nil, self.build_owner)
        self.root_element = element
        element:rebuild()
    end
    self:_sync_root()
    if self.on_dirty then
        self.on_dirty()
    end
end

---@param widget Widget
function WidgetBinding:_mount(widget)
    local element = widget:create_element()
    element:mount(nil, self.build_owner)
    self.root_element = element
    element:rebuild()
    self:_sync_root()
end

function WidgetBinding:_sync_root()
    local render_object = self.root_element and self.root_element:first_render_object()
    if render_object and self.render_owner.root ~= render_object then
        self.render_owner:set_root(render_object)
    end
end

--- Run the pending rebuilds and re-point the render tree if the root changed.
function WidgetBinding:flush_build()
    if self._disposed then
        return
    end
    self.build_owner:rebuild_dirty()
    self.build_owner:finalize_tree()
    self:_sync_root()
end

--- Unmount the tree and detach its render root.
function WidgetBinding:dispose()
    if self._disposed then
        return false
    end
    BindingBase.dispose(self)
    self.on_dirty = nil
    self.build_owner:clear_dirty()
    local element = self.root_element
    if element then
        element:unmount()
        self.root_element = nil
    end
    self.render_owner:set_root(nil, false)
    return true
end

M.WidgetBinding = WidgetBinding
M.WidgetsBinding = WidgetBinding

return M
