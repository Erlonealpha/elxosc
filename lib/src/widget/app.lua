-- Generic display and text ambients, independent of player and Material.
local std = require 'elxlibs.std'
local TextStyle = require('src.text.text_style').TextStyle
local StatelessWidget = require('src.widget.widget').StatelessWidget
local ambient_mod = require 'src.widget.ambient'
local SizedBox = require('src.widget.widgets.sized_box').SizedBox
local DisplaySnapshot = ambient_mod.DisplaySnapshot
local DisplayScope = ambient_mod.DisplayScope
local DefaultTextStyle = ambient_mod.DefaultTextStyle

---@class _WidgetsAppOptions
---@field child Widget?
---@field display DisplaySnapshot?
---@field default_text_style TextStyle?
---@field key any?

---@class WidgetsApp : StatelessWidget
---@field child Widget?
---@field display DisplaySnapshot
---@field default_text_style TextStyle
---@overload fun(options?: _WidgetsAppOptions): self
local WidgetsApp = std.class.new('WidgetsApp', StatelessWidget)

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

function WidgetsApp:build()
    return DisplayScope({
        snapshot = self.display,
        child = DefaultTextStyle({
            style = self.default_text_style,
            child = self.child or SizedBox.shrink(),
        }),
    })
end

---@class elxosc.src.widget.app
local M = { WidgetsApp = WidgetsApp }
return M
