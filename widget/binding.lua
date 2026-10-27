-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- Flutter-style binding composition and per-owner Widget tree handles.
--
-- `WidgetsBinding` is the one process-scoped framework binding.  A tree handle
-- owns the mutable BuildOwner/root Element pair for one Widget tree.  Multiple
-- trees therefore copy owners through `attach()` instead of constructing a
-- second binding.

local std = require 'elxlibs.std'
local binding_base = require 'foundation.binding_base'
local build_owner_mod = require 'widget.build_owner'
local widget_mod = require 'widget.widget'
-- Loading the element module also installs `Widget:create_element` (see the
-- wiring section at the bottom of widget/element.lua).
require 'widget.element'

local BindingBase = binding_base.BindingBase
local BuildOwner = build_owner_mod.BuildOwner
local can_update = widget_mod.can_update

local M = {}

---@class WidgetTree : std.object
---@field binding WidgetsBinding
---@field render_owner RenderOwner
---@field build_owner BuildOwner
---@field scheduler Scheduler?
---@field root_element Element?
---@field on_dirty fun()?
---@field _disposed boolean
---@field _owns_pipeline_owner boolean
---@overload fun(binding: WidgetsBinding, root_widget: Widget, render_owner: RenderOwner, scheduler: Scheduler?): self
local WidgetTree = std.class.new('WidgetTree', {})

function WidgetTree:__init(binding, root_widget, render_owner, scheduler)
    self.binding = binding
    self.render_owner = render_owner
    self.scheduler = scheduler
    self.build_owner = binding:create_build_owner(render_owner, scheduler)
    self.root_element = nil
    self.on_dirty = nil
    self._disposed = false
    self._owns_pipeline_owner = false
    self.build_owner.on_dirty = function()
        if self.on_dirty then
            self.on_dirty()
        end
    end
    local ok, err = pcall(self._mount, self, root_widget)
    if not ok then
        pcall(self.dispose, self)
        error(err, 0)
    end
end

--- Replace the root widget (the old tree is discarded).
---@param widget Widget
function WidgetTree:set_root_widget(widget)
    if self._disposed then
        return
    end
    self.build_owner:assert_can_build()
    local element = self.root_element
    if element and element:is_active() and can_update(element.widget, widget) then
        element:update(widget)
    else
        if element then
            element:unmount()
        end
        element = widget:create_element()
        self.root_element = element
        element:mount(nil, self.build_owner)
        element:rebuild()
    end
    self:_sync_root()
    if self.on_dirty then
        self.on_dirty()
    end
end

---@param widget Widget
function WidgetTree:_mount(widget)
    local element = widget:create_element()
    self.root_element = element
    element:mount(nil, self.build_owner)
    element:rebuild()
    self:_sync_root()
end

function WidgetTree:_sync_root()
    local element = self.root_element
    local render_object = element and element:is_active() and element:first_render_object() or nil
    if self.render_owner.root ~= render_object then
        self.render_owner:set_root(render_object)
    end
end

--- Run pending rebuilds and re-point the render tree if the root changed.
function WidgetTree:flush_build()
    if self._disposed then
        return
    end
    repeat
        self.build_owner:rebuild_dirty()
        self.build_owner:finalize_tree()
    until not self.build_owner:has_dirty()
    self:_sync_root()
end

--- Unmount the tree and detach its render root.
function WidgetTree:dispose()
    if self._disposed then
        return false
    end
    self._disposed = true
    self.on_dirty = nil
    self.build_owner:clear_dirty()
    local element = self.root_element
    local failure
    if element then
        local ok, err = pcall(element.unmount, element)
        if not ok then
            failure = err
        end
        self.root_element = nil
    end
    local ok, err = pcall(self.build_owner.finalize_tree, self.build_owner)
    if not ok then
        failure = failure or err
    end
    self.build_owner:clear_dirty()
    self.build_owner.on_dirty = nil
    self.render_owner:set_root(nil, false)
    if self._owns_pipeline_owner then
        self.render_owner:dispose()
    end
    if self.binding then
        self.binding:_detach(self)
    end
    self.binding = nil
    if failure then
        error(failure, 0)
    end
    return true
end

---@class WidgetsBinding : BindingBase
---@field _trees table<WidgetTree, true>
---@overload fun(): self
local WidgetsBinding = std.class.new('WidgetsBinding', { BindingBase })

function WidgetsBinding:__init()
    ---@diagnostic disable-next-line: param-type-mismatch, generic-constraint-mismatch
    std.super(WidgetsBinding, self, BindingBase).__init(self)
    self:claim_instance()
    self._trees = {}
end

---@return WidgetsBinding
function WidgetsBinding.ensure_initialized()
    return BindingBase.ensure_initialized(function()
        return WidgetsBinding()
    end) --[[@as WidgetsBinding]]
end

---@return WidgetsBinding?
function WidgetsBinding.instance()
    return BindingBase.current_instance() --[[@as WidgetsBinding?]]
end

---@return BuildOwner
function WidgetsBinding:create_build_owner(render_owner, scheduler)
    self:assert_alive()
    return BuildOwner(render_owner, scheduler)
end

---@param root RenderObject?
---@return RenderOwner
function WidgetsBinding:create_pipeline_owner(root)
    self:assert_alive()
    local pipeline_owner = require 'render.pipeline_owner'
    return pipeline_owner.PipelineOwner(root)
end

---@param root_widget Widget
---@param render_owner RenderOwner?
---@param scheduler Scheduler?
---@return WidgetTree
function WidgetsBinding:attach(root_widget, render_owner, scheduler)
    self:assert_alive()
    local owns_pipeline_owner = render_owner == nil
    render_owner = render_owner or self:create_pipeline_owner()
    local ok, tree = pcall(WidgetTree, self, root_widget, render_owner, scheduler)
    if not ok then
        if owns_pipeline_owner then
            render_owner:dispose()
        end
        error(tree, 0)
    end
    ---@cast tree WidgetTree
    tree._owns_pipeline_owner = owns_pipeline_owner
    self._trees[tree] = true
    return tree
end

---@param tree WidgetTree
function WidgetsBinding:_detach(tree)
    self._trees[tree] = nil
end

--- Flush every attached tree, or one selected tree when supplied.
---@param tree WidgetTree?
function WidgetsBinding:flush_build(tree)
    self:assert_alive()
    if tree then
        tree:flush_build()
        return
    end
    for attached in pairs(self._trees) do
        attached:flush_build()
    end
end

function WidgetsBinding:dispose()
    if self._disposed or self._disposing then
        return false
    end
    self._disposing = true
    local trees = {}
    for tree in pairs(self._trees) do
        trees[#trees + 1] = tree
    end
    local failure
    for _, tree in ipairs(trees) do
        local ok, err = pcall(tree.dispose, tree)
        if not ok then
            failure = failure or err
        end
    end
    BindingBase.dispose(self)
    self._disposing = false
    if failure then
        error(failure, 0)
    end
    return true
end

--- Explicit runtime teardown. Host Apps normally only dispose their own tree.
---@return boolean
function WidgetsBinding.shutdown()
    local binding = WidgetsBinding.instance()
    if not binding then
        return false
    end
    return binding:dispose()
end

-- The old name remains the same concrete binding class.  Existing callers
-- should migrate from `WidgetBinding(root, owner)` to
-- `WidgetsBinding.ensure_initialized():attach(root, owner)`.
M.WidgetsBinding = WidgetsBinding
M.WidgetBinding = WidgetsBinding
M.WidgetTree = WidgetTree

return M
