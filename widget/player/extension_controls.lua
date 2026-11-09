-- Fixed button cells and themed buttons for the player extension slots.
local std = require 'elxlibs.std'
local widget_mod = require 'widget.widget'
local layout_mod = require 'widget.widgets.layout'
local basic_mod = require 'widget.widgets.basic'
local geometry = require 'foundation.geometry'
local theme_mod = require 'widget.player.theme'
local visuals_mod = require 'widget.player.visuals'
local StatelessWidget = widget_mod.StatelessWidget
local Widget = widget_mod.Widget
local Row = layout_mod.Row
local SizedBox = layout_mod.SizedBox
local raise = std.raise

---@class _PlayerControlBarOptions
---@field children Widget[]?
---@field key any?

---@class PlayerControlBar : StatelessWidget
---@field children Widget[]
---@overload fun(options?: _PlayerControlBarOptions): self
local PlayerControlBar = std.class.new('PlayerControlBar', StatelessWidget)

function PlayerControlBar:__init(options)
    self.key = options and options.key
    self.children = {}
    for index, child in ipairs(options and options.children or {}) do
        if not std.isinstance(child, Widget) then
            raise(std.TypeError('PlayerControlBar.children must contain Widgets'))
        end
        self.children[index] = child
    end
end

function PlayerControlBar:child_widgets()
    return self.children
end

---@return integer
function PlayerControlBar:control_count()
    return #self.children
end

function PlayerControlBar:build()
    local children = {}
    for index, child in ipairs(self.children) do
        children[index] = SizedBox({ width = 24, height = 24, child = child })
    end
    if #children == 0 then
        return SizedBox.shrink()
    end
    return Row({ children = children, spacing = 21, main_axis_size = 'min', cross_alignment = 'center' })
end

---@class _PlayerControlButtonOptions
---@field icon string?
---@field on_click fun()?
---@field enabled boolean?
---@field key any?

---@class PlayerControlButton : StatelessWidget
---@field icon string
---@field on_click fun()?
---@field enabled boolean
---@overload fun(options?: _PlayerControlButtonOptions): self
local PlayerControlButton = std.class.new('PlayerControlButton', StatelessWidget)

function PlayerControlButton:__init(options)
    options = options or {}
    self.key = options.key
    self.icon = options.icon or 'extension'
    self.on_click = options.on_click
    self.enabled = options.enabled ~= false
end

function PlayerControlButton:build(context)
    local scope = theme_mod.PlayerTheme.maybe_of(context)
    local theme = scope and scope.data or theme_mod.PlayerThemeData()
    return basic_mod.IconButton({
        key = self.key,
        icon = layout_mod.Container({
            alignment = geometry.Offset(0.5, 0.5),
            child = basic_mod.Icon(self.icon, { size = theme.side_button_size, color = theme.side_button_color }),
        }),
        style = visuals_mod.control_style(theme),
        enabled = self.enabled,
        on_click = self.on_click,
    })
end

return { PlayerControlBar = PlayerControlBar, PlayerControlButton = PlayerControlButton }
