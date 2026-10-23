-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- The element tree (Flutter's `Element`).
--
-- Elements are the mutable half of the framework: they survive rebuilds, hold
-- `State`, own a `RenderObject`, and are reused across rebuilds when the widget
-- class and key match. This is what keeps render state (offsets, animation
-- progress) alive when a `set_state` rebuilds a subtree.
--
-- Child render objects are collected from the *element* tree
-- (`Element:first_render_object`), which lets composite widgets (stateless /
-- stateful) sit between two render objects without extra bookkeeping.

local std = require 'elxlibs.std'
local widget_mod = require 'widget.widget'
local key_mod = require 'widget.key'
local foundation_key = require 'foundation.key'

local raise = std.raise
local can_update = widget_mod.can_update
local StatelessWidget = widget_mod.StatelessWidget
local StatefulWidget = widget_mod.StatefulWidget
local ProxyWidget = widget_mod.ProxyWidget
local ParentDataWidget = widget_mod.ParentDataWidget
local InheritedWidget = widget_mod.InheritedWidget
local LeafRenderObjectWidget = widget_mod.LeafRenderObjectWidget
local SingleChildRenderObjectWidget = widget_mod.SingleChildRenderObjectWidget
local MultiChildRenderObjectWidget = widget_mod.MultiChildRenderObjectWidget
local GlobalKey = key_mod.GlobalKey
local LocalKey = foundation_key.LocalKey

local M = {}

--== base =================================================================

---@class Element : std.object
---@field widget Widget
---@field parent Element?
---@field owner BuildOwner?
---@field depth int
---@field mounted boolean
---@field active boolean
---@field dirty boolean
---@field build_scope BuildScope?
---@field _inherited_dependencies table<InheritedElement, true>
---@field _lifecycle_phase string
---@overload fun(widget: Widget):self
local Element = std.class.new('Element', {})

--- `BuildContext` is Flutter's name for "the handle a build gets"; here the
--- handle *is* the element itself.
---@alias BuildContext Element

function Element:__init(widget)
    self.widget = widget
    self.parent = nil
    self.owner = nil
    self.depth = 0
    self.mounted = false
    self.active = false
    self.dirty = false
    self.build_scope = nil
    self._inherited_dependencies = {}
    self._lifecycle_phase = 'idle'
end

---@param parent Element?
---@param owner BuildOwner
function Element:mount(parent, owner)
    self.parent = parent
    self.owner = owner
    self.depth = parent and (parent.depth + 1) or 0
    self.mounted = true
    self.active = true
    self.build_scope = parent and parent.build_scope or owner.root_scope
    local key = self.widget.key
    if key and std.isinstance(key, GlobalKey) then
        local ok, err = pcall(owner.register_global_key, owner, key, self)
        if not ok then
            self.mounted = false
            self.active = false
            self.parent = nil
            self.owner = nil
            error(err, 0)
        end
    end
    self._lifecycle_phase = 'idle'
end

function Element:unmount()
    if not self.mounted then
        return
    end
    self.mounted = false
    self.active = false
    self.dirty = false
    self._lifecycle_phase = 'dispose'
    self:_clear_inherited_dependencies()
    local key = self.widget.key
    if key and std.isinstance(key, GlobalKey) and self.owner then
        self.owner:unregister_global_key(key, self)
    end
    for _, child in ipairs(self:element_children()) do
        child:unmount()
    end
    self.parent = nil
    self.owner = nil
    self.build_scope = nil
    self._lifecycle_phase = 'unmounted'
end

--- Temporarily remove this subtree from the active tree. The BuildOwner keeps
--- it alive until the current build frame is finalized.
function Element:deactivate()
    if not self.mounted or not self.active then
        return false
    end
    self.active = false
    self.dirty = false
    for _, child in ipairs(self:element_children()) do
        child:deactivate()
    end
    if self.owner then
        self.owner:add_inactive(self)
    end
    return true
end

---@param parent Element?
function Element:activate(parent)
    if not self.mounted or self.active then
        return false
    end
    self.parent = parent
    self.depth = parent and (parent.depth + 1) or 0
    self.active = true
    self.build_scope = parent and parent.build_scope
        or (self.owner and self.owner.root_scope or nil)
    if self.owner then
        self.owner:remove_inactive(self)
    end
    for _, child in ipairs(self:element_children()) do
        child:activate(self)
    end
    return true
end

---@return boolean
function Element:is_active()
    return self.mounted and self.active
end

---@param phase string
---@param callback fun(): any
---@return any
function Element:_run_in_phase(phase, callback)
    local previous = self._lifecycle_phase
    self._lifecycle_phase = phase
    local ok, result = pcall(callback)
    self._lifecycle_phase = previous
    if not ok then
        error(result, 0)
    end
    return result
end

function Element:_assert_can_depend()
    if not self.mounted then
        raise(std.RuntimeError('listening Provider lookup requires a mounted BuildContext'))
    end
    if self._lifecycle_phase ~= 'build' and self._lifecycle_phase ~= 'dependencies' then
        raise(std.RuntimeError(
            'listening Provider lookup is only valid during build or did_change_dependencies'))
    end
end

function Element:_assert_can_read()
    if not self.mounted or self._lifecycle_phase == 'dispose'
        or self._lifecycle_phase == 'unmounted' then
        raise(std.RuntimeError('non-listening Provider lookup requires a mounted BuildContext'))
    end
end

---@param new_widget Widget
function Element:update(new_widget)
    self.widget = new_widget
end

--- Direct child elements, in render order.
---@return Element[]
function Element:element_children()
    return {}
end

--- The topmost render object this element contributes to its nearest
--- render-object ancestor.
---@return RenderObject?
function Element:first_render_object()
    return nil
end

---@return boolean
function Element:is_inherited_element()
    return false
end

---@return boolean
function Element:is_render_object_element()
    return false
end

--- A composite element changed its subtree shape, so the nearest
--- render-object ancestor must re-collect its render children. Render-object
--- elements sync themselves at the end of their own rebuild.
function Element:_sync_render_children_upwards()
    if self:is_render_object_element() then
        return
    end
    local element = self.parent
    while element do
        if element:is_render_object_element() then
            local render_object_element = element --[[@as RenderObjectElement]]
            render_object_element:sync_render_children()
            return
        end
        element = element.parent
    end
end

--- Walk up to the nearest ancestor with the exact runtime class
--- `widget_class` and register this element as a dependent, so it is rebuilt
--- when that provider changes.
---@param widget_class std.Class
---@return InheritedWidget?
function Element:depend_on_inherited(widget_class)
    self:_assert_can_depend()
    local element = self:find_inherited_exact(widget_class)
    if not element then
        return nil
    end
    local inherited = element --[[@as InheritedElement]]
    inherited.dependents[self] = true
    self._inherited_dependencies[inherited] = true
    return inherited.widget --[[@as InheritedWidget]]
end

---@param widget_class std.Class
---@return InheritedWidget?
function Element:depend_on_inherited_widget_of_exact_type(widget_class)
    return self:depend_on_inherited(widget_class)
end

---@param widget_class std.Class
---@return InheritedWidget?
function Element:get_inherited_widget(widget_class)
    self:_assert_can_read()
    local element = self:find_inherited_exact(widget_class)
    if not element then
        return nil
    end
    local inherited = element --[[@as InheritedElement]]
    return inherited.widget --[[@as InheritedWidget]]
end

---@param widget_class std.Class
---@return InheritedWidget?
function Element:get_inherited_widget_of_exact_type(widget_class)
    return self:get_inherited_widget(widget_class)
end

function Element:_clear_inherited_dependencies()
    for inherited in pairs(self._inherited_dependencies) do
        inherited.dependents[self] = nil
    end
    self._inherited_dependencies = {}
end

---@param widget_class std.Class
---@return Element?
function Element:find_inherited(widget_class)
    return self:find_inherited_exact(widget_class)
end

---@param widget_class std.Class
---@return Element?
function Element:find_inherited_exact(widget_class)
    local element = self.parent
    while element do
        if element:is_inherited_element() and element.widget.__class == widget_class then
            return element
        end
        element = element.parent
    end
    return nil
end

function Element:dependency_changed()
    self:mark_dirty()
end

---@return boolean
function Element:mark_dirty()
    if not self.mounted or not self.active or self.owner == nil then
        return false
    end
    self.dirty = true
    self.owner:schedule_build_for(self)
    return true
end

function Element:rebuild()
    self.dirty = false
end

--- Reconcile `previous` against `widget`, reusing or recreating as needed.
---@param previous Element?
---@param widget Widget?
---@return Element?
function Element:update_child(previous, widget)
    if widget == nil then
        if previous then
            previous:unmount()
        end
        return nil
    end
    -- Widgets are immutable descriptions. Reusing the exact same instance is
    -- stronger than can_update(): the subtree is already the desired result,
    -- so no Element update/build is necessary (Flutter's identity fast path).
    if previous and previous.widget == widget then
        return previous
    end
    if previous and can_update(previous.widget, widget) then
        previous:update(widget)
        return previous
    end
    if previous then
        previous:unmount()
    end
    local child = widget:create_element()
    child:mount(self, self.owner --[[@as BuildOwner]])
    child:rebuild()
    return child
end

--== composite ============================================================

---@class StatelessElement : Element
---@field child Element?
---@overload fun(widget:Widget):self
local StatelessElement = std.class.new('StatelessElement', { Element })

function StatelessElement:__init(widget)
    std.super(StatelessElement, self, Element).__init(self, widget)
    self.child = nil
end

function StatelessElement:element_children()
    return self.child and { self.child } or {}
end

function StatelessElement:first_render_object()
    return self.child and self.child:first_render_object() or nil
end

function StatelessElement:rebuild()
    self:_clear_inherited_dependencies()
    self.dirty = false
    local child = self:_run_in_phase('build', function()
        return self.widget:build(self)
    end)
    self.child = self:update_child(self.child, child)
    self:_sync_render_children_upwards()
end

function StatelessElement:update(new_widget)
    self.widget = new_widget
    self:rebuild()
end

---@class StatefulElement : Element
---@field child Element?
---@field state State
---@field _dependencies_changed boolean
---@overload fun(widget: Widget):self
local StatefulElement = std.class.new('StatefulElement', { Element })

function StatefulElement:__init(widget)
    std.super(StatefulElement, self, Element).__init(self, widget)
    self.child = nil
    self._dependencies_changed = false
    self.state = widget:create_state()
    self.state.widget = widget
    self.state.context = self
end

function StatefulElement:mount(parent, owner)
    std.super(StatefulElement, self, Element).mount(self, parent, owner)
    self:_run_in_phase('init_state', function()
        self.state:init_state()
    end)
    self._dependencies_changed = true
end

function StatefulElement:update(new_widget)
    local old_widget = self.widget
    self.widget = new_widget
    self.state.widget = new_widget
    self.state:did_update_widget(old_widget)
    self:rebuild()
end

function StatefulElement:unmount()
    if self.mounted then
        self:_run_in_phase('dispose', function()
            self.state:dispose()
        end)
        self.state:_dispose_resources()
        self.state.context = nil
    end
    std.super(StatefulElement, self, Element).unmount(self)
end

function StatefulElement:element_children()
    return self.child and { self.child } or {}
end

function StatefulElement:first_render_object()
    return self.child and self.child:first_render_object() or nil
end

function StatefulElement:rebuild()
    self:_clear_inherited_dependencies()
    self.dirty = false
    if self._dependencies_changed then
        self._dependencies_changed = false
        self:_run_in_phase('dependencies', function()
            self.state:did_change_dependencies()
        end)
    end
    local child = self:_run_in_phase('build', function()
        return self.state:build(self)
    end)
    self.child = self:update_child(self.child, child)
    self:_sync_render_children_upwards()
end

---@param initial boolean?
function StatefulElement:dependency_changed(initial)
    if not self.mounted then
        return
    end
    self._dependencies_changed = true
    if not initial then
        self:mark_dirty()
    end
end

---@class ProxyElement : Element
---@field child Element?
---@overload fun(widget: Widget):self
local ProxyElement = std.class.new('ProxyElement', { Element })

function ProxyElement:__init(widget)
    std.super(ProxyElement, self, Element).__init(self, widget)
    self.child = nil
end

function ProxyElement:element_children()
    return self.child and { self.child } or {}
end

function ProxyElement:first_render_object()
    return self.child and self.child:first_render_object() or nil
end

function ProxyElement:rebuild()
    self.dirty = false
    self.child = self:update_child(self.child, self.widget.child)
    self:_sync_render_children_upwards()
end

function ProxyElement:update(new_widget)
    self.widget = new_widget
    self:rebuild()
end

---@class ParentDataElement : ProxyElement
---@overload fun(widget: Widget):self
local ParentDataElement = std.class.new('ParentDataElement', { ProxyElement })

function ParentDataElement:rebuild()
    ProxyElement.rebuild(self)
    local render_object = self.child and self.child:first_render_object()
    if render_object then
        self.widget:apply_parent_data(render_object)
    end
end

function ParentDataElement:update(new_widget)
    self.widget = new_widget
    self:rebuild()
end

---@class InheritedElement : ProxyElement
---@field dependents table<Element, true>
---@overload fun(widget: InheritedWidget): self
local InheritedElement = std.class.new('InheritedElement', { ProxyElement })

function InheritedElement:__init(widget)
    std.super(InheritedElement, self, ProxyElement).__init(self, widget)
    self.dependents = {}
end

function InheritedElement:is_inherited_element()
    return true
end

function InheritedElement:update(new_widget)
    local old_widget = self.widget
    local dependents = {}
    for dependent in pairs(self.dependents) do
        dependents[#dependents + 1] = dependent
    end
    self.widget = new_widget
    if new_widget:update_should_notify(old_widget) then
        self:notify_dependents(dependents)
    end
    self:rebuild()
end

--- Rebuild every element that looked this provider up.
---@param dependents Element[]?
function InheritedElement:notify_dependents(dependents)
    if dependents == nil then
        dependents = {}
        for dependent in pairs(self.dependents) do
            dependents[#dependents + 1] = dependent
        end
    end
    for _, dependent in ipairs(dependents) do
        if dependent.mounted then
            dependent:dependency_changed()
        else
            self.dependents[dependent] = nil
        end
    end
end

--== render object elements ===============================================

---@class RenderObjectElement : Element
---@field render_object RenderObject
---@overload fun(widget: Widget):self
local RenderObjectElement = std.class.new('RenderObjectElement', { Element })

function RenderObjectElement:__init(widget)
    std.super(RenderObjectElement, self, Element).__init(self, widget)
    self.render_object = nil
end

function RenderObjectElement:mount(parent, owner)
    std.super(RenderObjectElement, self, Element).mount(self, parent, owner)
    self.render_object = self.widget:create_render_object()
    if owner and owner.render_owner then
        self.render_object:_set_owner(owner.render_owner)
    end
end

function RenderObjectElement:update(new_widget)
    self.widget = new_widget
    new_widget:update_render_object(self.render_object)
end

function RenderObjectElement:first_render_object()
    return self.render_object
end

function RenderObjectElement:is_render_object_element()
    return true
end

---@return RenderObject[]
function RenderObjectElement:render_children()
    return {}
end

function RenderObjectElement:sync_render_children()
    self.render_object:set_children(self:render_children())
end

function RenderObjectElement:rebuild()
    self.dirty = false
    self:sync_render_children()
end

---@class LeafRenderObjectElement : RenderObjectElement
---@overload fun(widget: Widget):self
local LeafRenderObjectElement = std.class.new('LeafRenderObjectElement', { RenderObjectElement })

---@class SingleChildRenderObjectElement : RenderObjectElement
---@field child Element?
---@overload fun(widget: Widget):self
local SingleChildRenderObjectElement =
    std.class.new('SingleChildRenderObjectElement', { RenderObjectElement })

function SingleChildRenderObjectElement:__init(widget)
    std.super(SingleChildRenderObjectElement, self, RenderObjectElement).__init(self, widget)
    self.child = nil
end

function SingleChildRenderObjectElement:element_children()
    return self.child and { self.child } or {}
end

function SingleChildRenderObjectElement:render_children()
    local render_object = self.child and self.child:first_render_object()
    return render_object and { render_object } or {}
end

function SingleChildRenderObjectElement:rebuild()
    self.dirty = false
    self.child = self:update_child(self.child, self.widget.child)
    self:sync_render_children()
end

function SingleChildRenderObjectElement:update(new_widget)
    RenderObjectElement.update(self, new_widget)
    self:rebuild()
end

---@class MultiChildRenderObjectElement : RenderObjectElement
---@field children Element[]
---@overload fun(widget: Widget):self
local MultiChildRenderObjectElement =
    std.class.new('MultiChildRenderObjectElement', { RenderObjectElement })

function MultiChildRenderObjectElement:__init(widget)
    std.super(MultiChildRenderObjectElement, self, RenderObjectElement).__init(self, widget)
    self.children = {}
end

function MultiChildRenderObjectElement:element_children()
    return self.children
end

function MultiChildRenderObjectElement:render_children()
    local out = {}
    for _, child in ipairs(self.children) do
        local render_object = child:first_render_object()
        if render_object then
            out[#out + 1] = render_object
        end
    end
    return out
end

function MultiChildRenderObjectElement:rebuild()
    self.dirty = false
    local previous = self.children
    local widgets = self.widget.children or {}
    local children = {}

    local seen_local_keys = {}
    for _, child_widget in ipairs(widgets) do
        local key = child_widget.key
        if key and std.isinstance(key --[[@as std.object]], LocalKey) then
            for _, seen in ipairs(seen_local_keys) do
                if seen == key then
                    if self.owner then
                        self.owner:diagnose('duplicate LocalKey among siblings', key)
                    end
                    break
                end
            end
            seen_local_keys[#seen_local_keys + 1] = key
        end
    end

    -- Match keyed children by identity rather than by array position. This is
    -- intentionally small, but preserves the important Flutter guarantee that
    -- a keyed Element (and its State/RenderObject) follows its logical item
    -- when siblings are inserted, removed, or reordered.
    local used = {}
    local function find_keyed(key)
        for i, old_child in ipairs(previous) do
            if not used[old_child] and old_child.widget.key ~= nil
                and old_child.widget.key == key then
                return old_child, i
            end
        end
        return nil, nil
    end

    for i, widget in ipairs(widgets) do
        local candidate = nil
        if widget.key ~= nil then
            candidate = find_keyed(widget.key)
        elseif previous[i] and previous[i].widget.key == nil
            and not used[previous[i]] then
            candidate = previous[i]
        end
        children[i] = self:update_child(candidate, widget)
        if candidate then
            used[candidate] = true
        end
    end
    for _, old_child in ipairs(previous) do
        if not used[old_child] then
            old_child:unmount()
        end
    end
    self.children = children
    self:sync_render_children()
end

function MultiChildRenderObjectElement:update(new_widget)
    RenderObjectElement.update(self, new_widget)
    self:rebuild()
end

--== widget <-> element wiring =============================================
-- `widget/widget.lua` cannot reference the element classes (Lua's `require`
-- has no cycles), so the mapping is installed here, once.

function StatelessWidget:create_element()
    return StatelessElement(self)
end

function StatefulWidget:create_element()
    return StatefulElement(self)
end

function ProxyWidget:create_element()
    return ProxyElement(self)
end

function ParentDataWidget:create_element()
    return ParentDataElement(self)
end

function InheritedWidget:create_element()
    return InheritedElement(self)
end

function LeafRenderObjectWidget:create_element()
    return LeafRenderObjectElement(self)
end

function SingleChildRenderObjectWidget:create_element()
    return SingleChildRenderObjectElement(self)
end

function MultiChildRenderObjectWidget:create_element()
    return MultiChildRenderObjectElement(self)
end

M.Element = Element
M.StatelessElement = StatelessElement
M.StatefulElement = StatefulElement
M.ProxyElement = ProxyElement
M.ParentDataElement = ParentDataElement
M.InheritedElement = InheritedElement
M.RenderObjectElement = RenderObjectElement
M.LeafRenderObjectElement = LeafRenderObjectElement
M.SingleChildRenderObjectElement = SingleChildRenderObjectElement
M.MultiChildRenderObjectElement = MultiChildRenderObjectElement

return M
