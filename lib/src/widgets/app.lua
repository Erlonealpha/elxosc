-- Generic display and text ambients, independent of player and Material.
---@namespace elxosc
---@using elxosc

local std = require 'elxlibs.std'
local text_style_mod = require 'src.text.text_style'
local framework_mod = require 'src.widgets.framework'
local ambient_mod = require 'src.widgets.ambient'
local sized_box_mod = require 'src.widgets.sized_box'

local TextStyle = text_style_mod.TextStyle
local StatelessWidget = framework_mod.StatelessWidget
local SizedBox = sized_box_mod.SizedBox
local DisplaySnapshot = ambient_mod.DisplaySnapshot
local DisplayScope = ambient_mod.DisplayScope
local DefaultTextStyle = ambient_mod.DefaultTextStyle

---@class _WidgetsAppOptions
---@field child              Widget?
---@field display            DisplaySnapshot?
---@field default_text_style TextStyle?
---@field key                any?

---@class WidgetsApp: StatelessWidget
---@field child              Widget?
---@field display            DisplaySnapshot
---@field default_text_style TextStyle
---@overload fun(options?: _WidgetsAppOptions): self
local WidgetsApp = std.class.new('WidgetsApp', StatelessWidget)

---@param options _WidgetsAppOptions?
function WidgetsApp:__init(options)
    options = options or {}
    self.key = options.key
    self.child = options.child
    self.display = options.display or DisplaySnapshot({ width = 0, height = 0 })
    self.default_text_style = options.default_text_style or TextStyle({ font_size = 14 })
    if not std.isinstance(self.display, DisplaySnapshot) then
        std.raise(std.TypeError('WidgetsApp.display must be DisplaySnapshot'))
    end
    if not std.isinstance(self.default_text_style, TextStyle) then
        std.raise(std.TypeError('WidgetsApp.default_text_style must be TextStyle'))
    end
end

---@return Widget?
function WidgetsApp:build()
    return DisplayScope({
        snapshot = self.display,
        child = DefaultTextStyle({
            style = self.default_text_style,
            child = self.child or SizedBox.shrink()
        })
    })
end

---@class mod.src.widgets.app
local M = {
    WidgetsApp = WidgetsApp
}
return M
