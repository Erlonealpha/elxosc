-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- Generic display and text ambients; design themes are owned by Material.
--
-- These values are immutable descriptions.  Runtime changes replace the
-- inherited widget, which lets listening descendants rebuild through the
-- existing InheritedWidget dependency mechanism.

---@namespace elxosc
---@using elxosc

local std = require 'elxlibs.std'
local text_style_mod = require 'src.text.text_style'
local widget_mod = require 'src.widgets.framework'
local text_layout_mod = require 'src.text.text_layout'

local math = math
local rawequal = rawequal
local type = type

local raise = std.raise
local TextStyle = text_style_mod.TextStyle
local InheritedWidget = widget_mod.InheritedWidget

---@class mod.src.widgets.ambient
local M = {}

---@param value number
---@return boolean
local function is_finite(value)
    return type(value) == 'number' and value == value and value ~= math.huge and value ~= -math.huge
end

---@param context Element
---@param name    string
local function require_context(context, name)
    if context == nil or type(context.depend_on_inherited_widget_of_exact_type) ~= 'function' then
        raise(std.TypeError(name .. ' lookup expects a BuildContext'))
    end
end

-- == Display ================================================================

---@class _DisplaySnapshotOptions
---@field width       number
---@field height      number
---@field initialized boolean?

---@class DisplaySnapshot: std.object
---@field width       number
---@field height      number
---@field initialized boolean
---@overload fun(options: _DisplaySnapshotOptions): self
local DisplaySnapshot = std.class.new('DisplaySnapshot')

---@param options _DisplaySnapshotOptions
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
        initialized = self.initialized
    })
end

---@class _DisplayScopeOptions
---@field snapshot DisplaySnapshot
---@field child    Widget?
---@field key      any?

---@class DisplayScope: InheritedWidget
---@field snapshot DisplaySnapshot
---@field child    Widget?
---@overload fun(options: _DisplayScopeOptions): self
local DisplayScope = std.class.new('DisplayScope', InheritedWidget)
local DisplayScopeClass = DisplayScope --[[@as std.class]]

---@param options _DisplayScopeOptions
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

---@param old_widget DisplayScope
---@return boolean
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

-- == text ===================================================================

---@class _DefaultTextStyleOptions
---@field style TextStyle
---@field child Widget?
---@field key   any?

---@class DefaultTextStyle: InheritedWidget
---@field style TextStyle
---@field child Widget?
---@overload fun(options: _DefaultTextStyleOptions): self
local DefaultTextStyle = std.class.new('DefaultTextStyle', InheritedWidget)
local DefaultTextStyleClass = DefaultTextStyle --[[@as std.class]]

---@param options _DefaultTextStyleOptions
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

---@param old_widget DefaultTextStyle
---@return boolean
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

---@class _TextLayoutScopeOptions
---@field layout     TextLayout
---@field generation integer?   non-negative; default zero
---@field child      Widget?
---@field key        any?

---@class TextLayoutScope: InheritedWidget
---@field layout     TextLayout
---@field generation integer
---@field child      Widget?
---@overload fun(options: _TextLayoutScopeOptions): self
local TextLayoutScope = std.class.new('TextLayoutScope', InheritedWidget)
local TextLayoutScopeClass = TextLayoutScope --[[@as std.class]]

---@param options _TextLayoutScopeOptions
function TextLayoutScope:__init(options)
    self.key = options.key
    self.child = options.child
    self.layout = options.layout
    self.generation = options.generation or 0
    if not std.isinstance(self.layout, text_layout_mod.TextLayout) then
        raise(std.TypeError('TextLayoutScope.layout must be a TextLayout'))
    end
    if not is_finite(self.generation) or self.generation < 0 or self.generation ~= math.floor(self.generation) then
        raise(std.ValueError('TextLayoutScope.generation must be a non-negative integer'))
    end
end

---@param old_widget TextLayoutScope
---@return boolean
function TextLayoutScope:update_should_notify(old_widget)
    return not rawequal(self.layout, old_widget.layout) or self.generation ~= old_widget.generation
end

---@param context BuildContext
---@return TextLayoutScope?
function TextLayoutScope.maybe_of(context)
    require_context(context, 'TextLayoutScope')
    return context:depend_on_inherited_widget_of_exact_type(TextLayoutScopeClass) --[[@as TextLayoutScope?]]
end

---@param context BuildContext
---@return TextLayoutScope
function TextLayoutScope.of(context)
    local scope = TextLayoutScope.maybe_of(context)
    if scope == nil then
        raise(std.RuntimeError('no TextLayoutScope ancestor was found'))
    end
    return scope
end

M.TextLayoutScope = TextLayoutScope

return M
