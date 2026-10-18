-- Default inherited text style for the application composition layer.

local std = require 'elxlibs.std'
local text_style_mod = require 'text.text_style'
local widget_mod = require 'widget.widget'
local provider_mod = require 'widget.provider'

local raise = std.raise
local TextStyle = text_style_mod.TextStyle
local InheritedWidget = widget_mod.InheritedWidget
local Provider = provider_mod.Provider

local M = {}

---@class _DefaultTextStyleOptions
---@field style TextStyle
---@field child Widget?
---@field key any?

---@class DefaultTextStyle : InheritedWidget
---@field style TextStyle
---@field child Widget?
---@overload fun(options: _DefaultTextStyleOptions): self
local DefaultTextStyle = std.class.new('DefaultTextStyle', { InheritedWidget })

function DefaultTextStyle:__init(options)
    if type(options) ~= 'table' then
        raise(std.TypeError('DefaultTextStyle expects an options table'))
    end
    if not std.isinstance(options.style, TextStyle) then
        raise(std.TypeError('DefaultTextStyle.style must be a TextStyle'))
    end
    self.key = options.key
    self.style = options.style
    self.child = options.child
end

---@param context BuildContext
---@return DefaultTextStyle
function DefaultTextStyle.of(context)
    return Provider.of(context, DefaultTextStyle --[[@as std.Class]]) --[[@as DefaultTextStyle]]
end

---@param context BuildContext
---@return DefaultTextStyle?
function DefaultTextStyle.maybe_of(context)
    return Provider.maybe_of(context, DefaultTextStyle --[[@as std.Class]]) --[[@as DefaultTextStyle?]]
end

---@param context BuildContext
---@return DefaultTextStyle
function DefaultTextStyle.read(context)
    return Provider.read(context, DefaultTextStyle --[[@as std.Class]]) --[[@as DefaultTextStyle]]
end

---@param context BuildContext
---@return DefaultTextStyle?
function DefaultTextStyle.maybe_read(context)
    return Provider.maybe_read(context, DefaultTextStyle --[[@as std.Class]]) --[[@as DefaultTextStyle?]]
end

---@param context BuildContext
---@return TextStyle
function DefaultTextStyle.style_of(context)
    return DefaultTextStyle.of(context).style
end

---@param old_widget InheritedWidget
---@return boolean
function DefaultTextStyle:update_should_notify(old_widget)
    return self.style ~= old_widget.style
end

M.DefaultTextStyle = DefaultTextStyle

return M
