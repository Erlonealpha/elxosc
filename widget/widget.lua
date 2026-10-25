-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- Immutable widget descriptions (Flutter's `Widget` hierarchy).
--
-- A widget is a lightweight, immutable configuration: it never lays out and
-- never paints. `create_element` turns it into a long lived `Element` (see
-- `widget/element.lua`), which in turn owns the `RenderObject`.
--
-- Note: `create_element` is bound to the element classes in
-- `widget/element.lua` (Lua's `require` has no cycles), so this file only
-- declares the widget side.

local std = require 'elxlibs.std'

local raise = std.raise

local M = {}

---@class Widget : std.object
---@field key any?
---@field __class std.Class
---@overload fun(key: any?): self
local Widget = std.class.new('Widget', {})

function Widget:__init(key)
    self.key = key
end

---@return Element
function Widget:create_element()
    raise(std.NotImplementedError(
        string.format('%s must implement create_element', tostring(self))))
end

--- Declared child widgets, in order. Used by `bind` to walk the tree while it
--- is still being assembled. Composite widgets that build their own subtree
--- expose nothing.
---@return Widget[]
function Widget:child_widgets()
    return {}
end

--- Reuse rule: same widget class and equal key (Flutter's `Widget.canUpdate`).
---@param old Widget
---@param new Widget
---@return boolean
function M.can_update(old, new)
    return old ~= nil and new ~= nil
        and old.__class == new.__class
        and old.key == new.key
end

--== composite widgets ====================================================

--- A widget that describes its subtree with `build` (Flutter's
--- `StatelessWidget`). The returned widget may be any widget, including nil for
--- "nothing".
---@class StatelessWidget : Widget
---@overload fun(key: any?): self
local StatelessWidget = std.class.new('StatelessWidget', { Widget })

---@param context BuildContext
---@return Widget?
function StatelessWidget:build(context)
    raise(std.NotImplementedError(
        string.format('%s must implement build', tostring(self))))
end

--- A widget that owns a `State` (Flutter's `StatefulWidget`).
---@class StatefulWidget : Widget
---@overload fun(key: any?): self
local StatefulWidget = std.class.new('StatefulWidget', { Widget })

---@return State
function StatefulWidget:create_state()
    raise(std.NotImplementedError(
        string.format('%s must implement create_state', tostring(self))))
end

--- A widget that may hold a single child without owning a render object
--- (Flutter's `ProxyWidget`).
---@class ProxyWidget : Widget
---@field child Widget?
---@overload fun(child: Widget?, key: any?): self
local ProxyWidget = std.class.new('ProxyWidget', { Widget })

function ProxyWidget:child_widgets()
    return self.child and { self.child } or {}
end

--- A proxy that only contributes parent data to its child's render object
--- (Flutter's `ParentDataWidget`, e.g. `Flexible`).
---@class ParentDataWidget : ProxyWidget
---@overload fun(child: Widget?, key: any?): self
local ParentDataWidget = std.class.new('ParentDataWidget', { ProxyWidget })

---@param render_object RenderObject
function ParentDataWidget:apply_parent_data(render_object)
    raise(std.NotImplementedError(
        string.format('%s must implement apply_parent_data', tostring(self))))
end

--- A proxy that makes a value reachable by descendants (Flutter's
--- `InheritedWidget`, e.g. `Theme`, `MediaQuery`).
---
--- Descendants look it up with `Element:depend_on_inherited`, which also
--- registers them so they rebuild when the value changes.
---@class InheritedWidget : ProxyWidget
---@overload fun(child: Widget?, key: any?): self
local InheritedWidget = std.class.new('InheritedWidget', { ProxyWidget })

--- Whether dependents must rebuild after this widget is replaced.
---@param old_widget InheritedWidget
---@return boolean
function InheritedWidget:update_should_notify(old_widget)
    return true
end

--== render object widgets ================================================

--- A widget that creates and configures a `RenderObject` (Flutter's
--- `RenderObjectWidget`).
---@class RenderObjectWidget : Widget
---@overload fun(key: any?): self
local RenderObjectWidget = std.class.new('RenderObjectWidget', { Widget })

---@return RenderObject
function RenderObjectWidget:create_render_object()
    raise(std.NotImplementedError(
        string.format('%s must implement create_render_object', tostring(self))))
end

---@param render_object RenderObject
function RenderObjectWidget:update_render_object(render_object) end

---@class LeafRenderObjectWidget : RenderObjectWidget
---@overload fun(key: any?): self
local LeafRenderObjectWidget = std.class.new('LeafRenderObjectWidget', { RenderObjectWidget })

---@class SingleChildRenderObjectWidget : RenderObjectWidget
---@field child Widget?
---@overload fun(key: any?): self
local SingleChildRenderObjectWidget =
    std.class.new('SingleChildRenderObjectWidget', { RenderObjectWidget })

function SingleChildRenderObjectWidget:child_widgets()
    return self.child and { self.child } or {}
end

---@class MultiChildRenderObjectWidget : RenderObjectWidget
---@field children Widget[]
---@overload fun(key: any?): self
local MultiChildRenderObjectWidget =
    std.class.new('MultiChildRenderObjectWidget', { RenderObjectWidget })

function MultiChildRenderObjectWidget:child_widgets()
    return self.children or {}
end

M.Widget = Widget
M.StatelessWidget = StatelessWidget
M.StatefulWidget = StatefulWidget
M.ProxyWidget = ProxyWidget
M.ParentDataWidget = ParentDataWidget
M.InheritedWidget = InheritedWidget
M.RenderObjectWidget = RenderObjectWidget
M.LeafRenderObjectWidget = LeafRenderObjectWidget
M.SingleChildRenderObjectWidget = SingleChildRenderObjectWidget
M.MultiChildRenderObjectWidget = MultiChildRenderObjectWidget

return M
