-- Host-independent theme ambient for the application composition layer.

local std = require 'elxlibs.std'
local color_mod = require 'foundation.color'
local widget_mod = require 'widget.widget'
local provider_mod = require 'widget.provider'

local raise = std.raise
local Color = color_mod.Color
local InheritedWidget = widget_mod.InheritedWidget
local Provider = provider_mod.Provider

local M = {}

---@class _ThemeDataOptions
---@field colors table<string, Color>?

---@class ThemeData : std.object
---@field colors table<string, Color>
---@overload fun(options?: _ThemeDataOptions): self
local ThemeData = std.class.new('ThemeData', {})

function ThemeData:__init(options)
    options = options or {}
    if type(options) ~= 'table' then
        raise(std.TypeError('ThemeData expects an options table'))
    end
    if options.colors ~= nil and type(options.colors) ~= 'table' then
        raise(std.TypeError('ThemeData.colors must be a table'))
    end
    self.colors = {}
    for name, color in pairs(options.colors or {}) do
        if type(name) ~= 'string' or name == '' then
            raise(std.TypeError('ThemeData color names must be non-empty strings'))
        end
        if not std.isinstance(color, Color) then
            raise(std.TypeError('ThemeData colors must be Color values'))
        end
        self.colors[name] = color
    end
end

---@return ThemeData
function ThemeData:copy()
    local colors = {}
    for name, color in pairs(self.colors) do
        colors[name] = color
    end
    return ThemeData({
        colors = colors,
    })
end

---@class _ThemeOptions
---@field data ThemeData
---@field child Widget?
---@field key any?

---@class Theme : InheritedWidget
---@field data ThemeData
---@field child Widget?
---@overload fun(options: _ThemeOptions): self
local Theme = std.class.new('Theme', { InheritedWidget })

function Theme:__init(options)
    if type(options) ~= 'table' then
        raise(std.TypeError('Theme expects an options table'))
    end
    if not std.isinstance(options.data, ThemeData) then
        raise(std.TypeError('Theme.data must be a ThemeData'))
    end
    self.key = options.key
    self.data = options.data
    self.child = options.child
end

---@param context BuildContext
---@return Theme
function Theme.of(context)
    return Provider.of(context, Theme --[[@as std.Class]]) --[[@as Theme]]
end

---@param context BuildContext
---@return Theme?
function Theme.maybe_of(context)
    return Provider.maybe_of(context, Theme --[[@as std.Class]]) --[[@as Theme?]]
end

---@param context BuildContext
---@return Theme
function Theme.read(context)
    return Provider.read(context, Theme --[[@as std.Class]]) --[[@as Theme]]
end

---@param context BuildContext
---@return Theme?
function Theme.maybe_read(context)
    return Provider.maybe_read(context, Theme --[[@as std.Class]]) --[[@as Theme?]]
end

---@param context BuildContext
---@return ThemeData
function Theme.data_of(context)
    return Theme.of(context).data
end

---@param old_widget InheritedWidget
---@return boolean
function Theme:update_should_notify(old_widget)
    return self.data ~= old_widget.data
end

M.ThemeData = ThemeData
M.Theme = Theme

return M
