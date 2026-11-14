-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- Generic display and text ambients; design themes are owned by Material.
--
-- These values are immutable descriptions.  Runtime changes replace the
-- inherited widget, which lets listening descendants rebuild through the
-- existing InheritedWidget dependency mechanism.

local std = require 'elxlibs.std'
local text_style_mod = require 'src.text.text_style'
local widget_mod = require 'src.widgets.framework'

local raise = std.raise
local TextStyle = text_style_mod.TextStyle
local InheritedWidget = widget_mod.InheritedWidget

---@class elxosc.mod.src.widgets.ambient
local M = {}

local function is_finite(value)
    return type(value) == 'number'
        and value == value
        and value ~= math.huge
        and value ~= -math.huge
end

local function require_context(context, name)
    if context == nil or type(context.depend_on_inherited_widget_of_exact_type) ~= 'function' then
        raise(std.TypeError(name .. ' lookup expects a BuildContext'))
    end
end

--== Display ================================================================

---@class _DisplaySnapshotOptions
---@field width number
---@field height number
---@field initialized boolean?

---@class DisplaySnapshot : std.object
---@field width number
---@field height number
---@field initialized boolean
---@overload fun(options: _DisplaySnapshotOptions): self
local DisplaySnapshot = std.class.new('DisplaySnapshot')

function DisplaySnapshot:__init(options)
    if type(options) ~= 'table' then
        raise(std.TypeError('DisplaySnapshot expects an options table'))
    end
    local width, height = options.width, options.height
    if not is_finite(width) or width < 0 or not is_finite(height) or height < 0 then
        raise(std.ValueError('DisplaySnapshot dimensions must be finite non-negative numbers'))
    end
    if options.initialized ~= nil and type(options.initialized) ~= 'boolean' then
        raise(std.TypeError('DisplaySnapshot.initialized must be a boolean'))
    end
    self.width = width
    self.height = height
    self.initialized = options.initialized == true
end

---@return DisplaySnapshot
function DisplaySnapshot:copy()
    return DisplaySnapshot({
        width = self.width,
        height = self.height,
        initialized = self.initialized,
    })
end

---@class _DisplayScopeOptions
---@field snapshot DisplaySnapshot
---@field child Widget?
---@field key any?

---@class DisplayScope : InheritedWidget
---@field snapshot DisplaySnapshot
---@field child Widget?
---@overload fun(options: _DisplayScopeOptions): self
local DisplayScope = std.class.new('DisplayScope', InheritedWidget)
local DisplayScopeClass = DisplayScope --[[@as std.class]]

function DisplayScope:__init(options)
    if type(options) ~= 'table' then
        raise(std.TypeError('DisplayScope expects an options table'))
    end
    self.key = options.key
    self.snapshot = options.snapshot or DisplaySnapshot({ width = 0, height = 0 })
    self.child = options.child
    if not std.isinstance(self.snapshot, DisplaySnapshot) then
        raise(std.TypeError('DisplayScope.snapshot must be a DisplaySnapshot'))
    end
end

function DisplayScope:update_should_notify(old_widget)
    return self.snapshot ~= old_widget.snapshot
end

---@param context BuildContext
---@return DisplayScope
function DisplayScope.of(context)
    require_context(context, 'DisplayScope')
    local value = context:depend_on_inherited_widget_of_exact_type(DisplayScopeClass)
    if value == nil then
        raise(std.RuntimeError('no DisplayScope ancestor was found'))
    end
    return value --[[@as DisplayScope]]
end

---@param context BuildContext
---@return DisplayScope?
function DisplayScope.maybe_of(context)
    require_context(context, 'DisplayScope')
    return context:depend_on_inherited_widget_of_exact_type(DisplayScopeClass) --[[@as DisplayScope?]]
end

--== text ===================================================================

---@class _DefaultTextStyleOptions
---@field style TextStyle
---@field child Widget?
---@field key any?

---@class DefaultTextStyle : InheritedWidget
---@field style TextStyle
---@field child Widget?
---@overload fun(options: _DefaultTextStyleOptions): self
local DefaultTextStyle = std.class.new('DefaultTextStyle', InheritedWidget)
local DefaultTextStyleClass = DefaultTextStyle --[[@as std.class]]

function DefaultTextStyle:__init(options)
    if type(options) ~= 'table' then
        raise(std.TypeError('DefaultTextStyle expects an options table'))
    end
    self.key = options.key
    self.style = options.style or TextStyle()
    self.child = options.child
    if not std.isinstance(self.style, TextStyle) then
        raise(std.TypeError('DefaultTextStyle.style must be a TextStyle'))
    end
end

function DefaultTextStyle:update_should_notify(old_widget)
    return self.style ~= old_widget.style
end

---@param context BuildContext
---@return DefaultTextStyle
function DefaultTextStyle.of(context)
    require_context(context, 'DefaultTextStyle')
    local value = context:depend_on_inherited_widget_of_exact_type(DefaultTextStyleClass)
    if value == nil then
        raise(std.RuntimeError('no DefaultTextStyle ancestor was found'))
    end
    return value --[[@as DefaultTextStyle]]
end

---@param context BuildContext
---@return DefaultTextStyle?
function DefaultTextStyle.maybe_of(context)
    require_context(context, 'DefaultTextStyle')
    return context:depend_on_inherited_widget_of_exact_type(DefaultTextStyleClass) --[[@as DefaultTextStyle?]]
end

M.DisplaySnapshot = DisplaySnapshot
M.DisplayScope = DisplayScope
M.DefaultTextStyle = DefaultTextStyle

return M
