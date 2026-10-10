-- Reusable button visual state and style values.

local std = require 'elxlibs.std'
local color_mod = require 'foundation.color'

local Color = color_mod.Color

---@class _ButtonStyleOptions
---@field background_color Color?
---@field color Color?
---@field foreground_color Color?
---@field hover_color Color?
---@field pressed_color Color?
---@field disabled_color Color?
---@field border_color Color?
---@field border_width number?
---@field radius number?
---@field padding EdgeInsets?
---@field elevation number?

---@class ButtonStyle : std.object
---@field background_color Color?
---@field foreground_color Color
---@field hover_color Color?
---@field pressed_color Color?
---@field disabled_color Color?
---@field border_color Color?
---@field border_width number
---@field radius number
---@field padding EdgeInsets?
---@field elevation number
---@overload fun(options: _ButtonStyleOptions?): ButtonStyle
local ButtonStyle = std.class.new('ButtonStyle')

---@param options _ButtonStyleOptions?
---@return nil
function ButtonStyle:__init(options)
    options = options or {}
    self.background_color = options.background_color or options.color
    self.foreground_color = options.foreground_color or Color.rgba255(255, 255, 255)
    self.hover_color = options.hover_color
    self.pressed_color = options.pressed_color
    self.disabled_color = options.disabled_color or Color.rgba255(85, 85, 85)
    self.border_color = options.border_color
    self.border_width = options.border_width or 0
    self.radius = options.radius or 4
    self.padding = options.padding
    self.elevation = options.elevation or 0
end

---@param state "normal"|"hover"|"pressed"|"disabled"
---@return Color?
function ButtonStyle:background_for(state)
    if state == 'disabled' then
        return self.disabled_color
    end
    if state == 'pressed' then
        return self.pressed_color or self.hover_color or self.background_color
    end
    if state == 'hover' then
        return self.hover_color or self.background_color
    end
    return self.background_color
end

---@param options _ButtonStyleOptions?
---@return ButtonStyle
function ButtonStyle:copy_with(options)
    options = options or {}
    local values = {}
    for key, value in pairs(self) do
        values[key] = value
    end
    for key, value in pairs(options) do
        values[key] = value
    end
    return ButtonStyle(values)
end

---@param elevation number
---@return Color?
function ButtonStyle:shadow_for(elevation)
    if elevation <= 0 then
        return nil
    end
    return Color.rgba255(0, 0, 0, math.min(100, 18 + elevation * 8))
end

return { ButtonStyle = ButtonStyle }
