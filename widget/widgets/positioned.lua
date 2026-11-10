-- Parent-data widget for root-relative Stack placement.

local std = require 'elxlibs.std'
local widget_mod = require 'widget.widget'

local ParentDataWidget = widget_mod.ParentDataWidget
local raise = std.raise
local huge = math.huge

---@class elxosc.widget.widgets.positioned
local M = {}

---@class _PositionedOptions
---@field left number?
---@field top number?
---@field right number?
---@field bottom number?
---@field width number?
---@field height number?
---@field child Widget?
---@field key any?

---@class Positioned : ParentDataWidget
---@field left number?
---@field top number?
---@field right number?
---@field bottom number?
---@field width number?
---@field height number?
---@overload fun(options?: _PositionedOptions): self
local Positioned = std.class.new('Positioned', ParentDataWidget)

local function optional_number(name, value, non_negative)
    if value == nil then
        return nil
    end
    if type(value) ~= 'number' or value ~= value
        or value == huge or value == -huge then
        raise(std.ValueError('Positioned.' .. name .. ' must be finite'))
    end
    if non_negative and value < 0 then
        raise(std.ValueError('Positioned.' .. name .. ' must be non-negative'))
    end
    return value
end

function Positioned:__init(options)
    options = options or {}
    self.key = options.key
    self.child = options.child
    self.left = optional_number('left', options.left, false)
    self.top = optional_number('top', options.top, false)
    self.right = optional_number('right', options.right, false)
    self.bottom = optional_number('bottom', options.bottom, false)
    self.width = optional_number('width', options.width, true)
    self.height = optional_number('height', options.height, true)
    if self.width == nil and self.left == nil and self.right == nil then
        if self.height == nil and self.top == nil and self.bottom == nil then
            raise(std.ValueError('Positioned needs at least one position or size constraint'))
        end
    end
end

local function apply_data(render_object, data)
    local parent_data = render_object.parent_data
    local changed = parent_data.positioned ~= data.positioned
    for _, name in ipairs({ 'left', 'top', 'right', 'bottom', 'width', 'height' }) do
        if parent_data[name] ~= data[name] then
            changed = true
        end
        parent_data[name] = data[name]
    end
    parent_data.positioned = data.positioned
    if changed and render_object.parent then
        render_object.parent:mark_needs_layout()
    end
end

function Positioned:apply_parent_data(render_object)
    apply_data(render_object, {
        positioned = true,
        left = self.left,
        top = self.top,
        right = self.right,
        bottom = self.bottom,
        width = self.width,
        height = self.height,
    })
end

function Positioned:clear_parent_data(render_object)
    apply_data(render_object, { positioned = false })
end

M.Positioned = Positioned

return M
