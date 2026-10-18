-- Host-independent application composition widgets.

local std = require 'elxlibs.std'
local text_style_mod = require 'text.text_style'
local widget_mod = require 'widget.widget'
local theme_mod = require 'widget.theme'
local display_scope_mod = require 'widget.display_scope'
local default_text_style_mod = require 'widget.default_text_style'
local player_context_mod = require 'widget.player_context'
local stack_mod = require 'widget.widgets.stack'
local sized_box_mod = require 'widget.widgets.sized_box'

local raise = std.raise
local TextStyle = text_style_mod.TextStyle
local Widget = widget_mod.Widget
local StatelessWidget = widget_mod.StatelessWidget
local Theme = theme_mod.Theme
local ThemeData = theme_mod.ThemeData
local DisplayScope = display_scope_mod.DisplayScope
local DisplaySnapshot = display_scope_mod.DisplaySnapshot
local DefaultTextStyle = default_text_style_mod.DefaultTextStyle
local PlayerScope = player_context_mod.PlayerScope
local PlayerStore = player_context_mod.PlayerStore
local Stack = stack_mod.Stack
local SizedBox = sized_box_mod.SizedBox

local M = {}

local function require_widget(name, value)
    if type(value) ~= 'table' or type(value.create_element) ~= 'function' then
        raise(std.TypeError(name .. ' must be a Widget'))
    end
end

local function copy_child_widgets(child)
    return child and { child } or {}
end

local function require_optional_widget(name, value)
    if value ~= nil then
        require_widget(name, value)
    end
end

---@class _WidgetsAppOptions
---@field child Widget
---@field theme ThemeData
---@field player_store PlayerStore
---@field display_snapshot DisplaySnapshot
---@field default_text_style TextStyle
---@field key any?

---@class WidgetsApp : StatelessWidget
---@field child Widget
---@field theme ThemeData
---@field player_store PlayerStore
---@field display_snapshot DisplaySnapshot
---@field default_text_style TextStyle
---@overload fun(options: _WidgetsAppOptions): self
local WidgetsApp = std.class.new('WidgetsApp', { StatelessWidget })

function WidgetsApp:__init(options)
    if type(options) ~= 'table' then
        raise(std.TypeError('WidgetsApp expects an options table'))
    end
    require_widget('WidgetsApp.child', options.child)
    if not std.isinstance(options.theme, ThemeData) then
        raise(std.TypeError('WidgetsApp.theme must be a ThemeData'))
    end
    if not std.isinstance(options.player_store, PlayerStore) then
        raise(std.TypeError('WidgetsApp.player_store must be a PlayerStore'))
    end
    if not std.isinstance(options.display_snapshot, DisplaySnapshot) then
        raise(std.TypeError('WidgetsApp.display_snapshot must be a DisplaySnapshot'))
    end
    if not std.isinstance(options.default_text_style, TextStyle) then
        raise(std.TypeError('WidgetsApp.default_text_style must be a TextStyle'))
    end
    self.key = options.key
    self.child = options.child
    self.theme = options.theme
    self.player_store = options.player_store
    self.display_snapshot = options.display_snapshot
    self.default_text_style = options.default_text_style
end

function WidgetsApp:build()
    return Theme({
        data = self.theme,
        child = PlayerScope({
            store = self.player_store,
            child = DisplayScope({
                snapshot = self.display_snapshot,
                child = DefaultTextStyle({
                    style = self.default_text_style,
                    child = self.child,
                }),
            }),
        }),
    })
end

function WidgetsApp:child_widgets()
    return copy_child_widgets(self.child)
end

function WidgetsApp:bind_target()
    return 'child'
end

---@class _DefaultAppOptions
---@field main Widget?
---@field extension Widget?
---@field popup Widget?
---@field key any?

--- The host-independent application content composition.
---
--- `DefaultApp` keeps the three application surfaces in one Widget tree. It is
--- deliberately separate from OverlayHost layers: host-level layers retain
--- independent presenters, visibility, z policies, and input policies.
---@class DefaultApp : StatelessWidget
---@field main Widget?
---@field extension Widget?
---@field popup Widget?
---@overload fun(options?: _DefaultAppOptions): self
local DefaultApp = std.class.new('DefaultApp', { StatelessWidget })

function DefaultApp:__init(options)
    options = options or {}
    if type(options) ~= 'table' then
        raise(std.TypeError('DefaultApp expects an options table'))
    end
    require_optional_widget('DefaultApp.main', options.main)
    require_optional_widget('DefaultApp.extension', options.extension)
    require_optional_widget('DefaultApp.popup', options.popup)
    self.key = options.key
    self.main = options.main
    self.extension = options.extension
    self.popup = options.popup
end

function DefaultApp:child_widgets()
    local children = {}
    if self.main then
        children[#children + 1] = self.main
    end
    if self.extension then
        children[#children + 1] = self.extension
    end
    if self.popup then
        children[#children + 1] = self.popup
    end
    return children
end

function DefaultApp:build()
    local children = {}
    for _, surface in ipairs({
        { key = 'main', child = self.main },
        { key = 'extension', child = self.extension },
        { key = 'popup', child = self.popup },
    }) do
        if surface.child ~= nil then
            children[#children + 1] = SizedBox.expand(surface)
        end
    end
    return Stack({ children = children })
end

---@class _MaterialAppOptions : _WidgetsAppOptions

---@class MaterialApp : StatelessWidget
---@field child Widget
---@field theme ThemeData
---@field player_store PlayerStore
---@field display_snapshot DisplaySnapshot
---@field default_text_style TextStyle
---@overload fun(options: _MaterialAppOptions): self
local MaterialApp = std.class.new('MaterialApp', { StatelessWidget })

function MaterialApp:__init(options)
    if type(options) ~= 'table' then
        raise(std.TypeError('MaterialApp expects an options table'))
    end
    require_widget('MaterialApp.child', options.child)
    if not std.isinstance(options.theme, ThemeData) then
        raise(std.TypeError('MaterialApp.theme must be a ThemeData'))
    end
    if not std.isinstance(options.player_store, PlayerStore) then
        raise(std.TypeError('MaterialApp.player_store must be a PlayerStore'))
    end
    if not std.isinstance(options.display_snapshot, DisplaySnapshot) then
        raise(std.TypeError('MaterialApp.display_snapshot must be a DisplaySnapshot'))
    end
    if not std.isinstance(options.default_text_style, TextStyle) then
        raise(std.TypeError('MaterialApp.default_text_style must be a TextStyle'))
    end
    self.key = options.key
    self.child = options.child
    self.theme = options.theme
    self.player_store = options.player_store
    self.display_snapshot = options.display_snapshot
    self.default_text_style = options.default_text_style
end

function MaterialApp:build()
    return WidgetsApp({
        child = self.child,
        theme = self.theme,
        player_store = self.player_store,
        display_snapshot = self.display_snapshot,
        default_text_style = self.default_text_style,
    })
end

function MaterialApp:child_widgets()
    return copy_child_widgets(self.child)
end

function MaterialApp:bind_target()
    return 'child'
end

---@class _MpvAppOptions
---@field child Widget?
---@field default_app Widget?
---@field theme ThemeData?
---@field player_store PlayerStore?
---@field display_snapshot DisplaySnapshot?
---@field default_text_style TextStyle?
---@field key any?

---@class MpvApp : StatelessWidget
---@field child Widget
---@field theme ThemeData
---@field player_store PlayerStore
---@field display_snapshot DisplaySnapshot
---@field default_text_style TextStyle
---@overload fun(options: _MpvAppOptions): self
local MpvApp = std.class.new('MpvApp', { StatelessWidget })

function MpvApp:__init(options)
    options = options or {}
    if type(options) ~= 'table' then
        raise(std.TypeError('MpvApp expects an options table'))
    end
    local child = options.default_app
    if child == nil and options.child ~= nil then
        child = DefaultApp({ main = options.child })
    end
    require_widget('MpvApp.child', child)
    self.key = options.key
    self.id = 'app'
    self.child = child
    self.theme = options.theme or ThemeData()
    self.player_store = options.player_store or PlayerStore()
    self.display_snapshot = options.display_snapshot or DisplaySnapshot({
        width = 0,
        height = 0,
        initialized = false,
    })
    self.default_text_style = options.default_text_style or TextStyle()
end

function MpvApp:build()
    return MaterialApp({
        child = self.child,
        theme = self.theme,
        player_store = self.player_store,
        display_snapshot = self.display_snapshot,
        default_text_style = self.default_text_style,
    })
end

function MpvApp:child_widgets()
    return copy_child_widgets(self.child)
end

function MpvApp:bind_target()
    return 'child'
end

M.WidgetsApp = WidgetsApp
M.DefaultApp = DefaultApp
M.MaterialApp = MaterialApp
M.MpvApp = MpvApp

return M
