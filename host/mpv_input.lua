-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- Pointer/key input for the mpv host.
--
-- Follows uosc's `lib/cursor.lua` where it matters:
--   * the pointer comes from the `mouse-pos` property (pixel centres, +0.5);
--   * mouse buttons/wheel are captured through named key-binding sections;
--   * sections have mouse areas, so ordinary clicks still reach mpv's default
--     bindings outside interactive render regions.

local mp = require 'mp'

local std = require 'elxlibs.std'
local geometry = require 'foundation.geometry'
local pointer_event = require 'foundation.pointer_event'

local Offset = geometry.Offset
local PointerEvent = pointer_event.PointerEvent
local math = math
local floor = math.floor
local ceil = math.ceil
local huge = math.huge
local debug_msgf = rawget(_G, 'debug_msgf') or function(...) end
local debug_msg = rawget(_G, 'debug_msg') or function(...) end

---@param value number
---@return integer
local function pixel_floor(value)
    return floor(value) --[[@as integer]]
end

---@param value number
---@return integer
local function pixel_ceil(value)
    return ceil(value) --[[@as integer]]
end

local M = {}

local INPUT_SECTION = 'elxosc-input'
local WHEEL_SECTION = 'elxosc-wheel'
local BINDING_FLAGS = 'allow-hide-cursor'
local owned_sections = {}

---@class MpInput : std.object
---@field app App
---@field app.on_pointer_move fun()?
---@field app.on_pointer_leave fun()?
---@field hover boolean
---@field _regions PointerRegion[]
---@field _region_signature string?
---@field _input_sections string[]
---@field _wheel_sections string[]
---@field _pressed_section string?
---@field _buttons table<PointerButton, true>
---@field _mouse_callback fun(name: string, mouse: table)?
---@field _shutdown boolean
---@overload fun(app: App): self
local MpInput = std.class.new('MpInput', {})

function MpInput:__init(app)
    self.app = app
    self.x, self.y = huge, huge
    self.hover = false
    self._pressed = false
    self._regions = {}
    self._region_signature = nil
    self._input_sections = {}
    self._wheel_sections = {}
    self._pressed_section = nil
    self._buttons = {}
    self._mouse_callback = nil
    self._shutdown = false
    self:_clear_owned_sections()
    self:_bind_mouse()
    self:_bind_keys()
    self:_clear_mouse_areas()
end

---@return Offset
function MpInput:_point()
    return Offset(self.x, self.y)
end

function MpInput:_refresh_position()
    local mouse = mp.get_property_native('mouse-pos')
    if mouse then
        self.x, self.y = mouse.x + 0.5, mouse.y + 0.5
    end
end

function MpInput:_bind_mouse()
    self._mouse_callback = function(_, mouse)
        if self._shutdown then
            return
        end
        if not mouse then
            return
        end
        if not mouse.hover then
            if self.hover then
                self.hover = false
                self.app.owner:clear_hover()
                if self.app.on_pointer_leave then
                    self.app.on_pointer_leave()
                end
            end
            if self._pressed then
                self.app.owner:cancel_pointer()
                self._pressed = false
                self._pressed_section = nil
                self:update_regions()
            end
            self._buttons = {}
            return
        end
        self.x, self.y = mouse.x + 0.5, mouse.y + 0.5
        self.hover = true
        if self.app.on_pointer_move then
            self.app.on_pointer_move()
        end
        self:_dispatch('move')
    end
    mp.observe_property('mouse-pos', 'native', self._mouse_callback)
end

---@return PointerButtons
local function copy_buttons(buttons)
    local copy = {}
    for button, pressed in pairs(buttons) do
        copy[button] = pressed
    end
    return copy
end

---@param data any?
---@return number?
---@return number?
local function wheel_delta(data)
    if type(data) == 'number' then
        return nil, data
    end
    if type(data) == 'table' then
        return data.x, data.y
    end
    return nil, nil
end

---@return boolean
local function has_position(input)
    return input.x == input.x and input.y == input.y
        and input.x ~= huge and input.y ~= huge
        and input.x ~= -huge and input.y ~= -huge
end

---@param event string
---@param data any?
---@param section string?
function MpInput:_dispatch(event, data, section)
    if self._shutdown then
        return
    end
    debug_msgf('MpInput:_dispatch(%s)', event)
    if event == 'down' or event == 'double' then
        self:_refresh_position()
    end
    if not has_position(self) then
        return
    end
    local button
    if event == 'down' or event == 'up' or event == 'double' then
        button = data
        if event == 'down' and button ~= nil then
            self._buttons[button] = true
        elseif event == 'up' and button ~= nil then
            self._buttons[button] = nil
        end
    end
    local delta_x, delta_y
    if event == 'wheel' then
        delta_x, delta_y = wheel_delta(data)
    end
    local pointer = PointerEvent(event, self:_point(), data, {
        pointer_id = 1,
        button = button,
        buttons = copy_buttons(self._buttons),
        click_count = event == 'double' and 2 or nil,
        delta_x = delta_x,
        delta_y = delta_y,
        source = 'mouse',
        timestamp = mp.get_time(),
    })
    local result = self.app.owner:dispatch_pointer_result(pointer)
    if event == 'down' then
        if result.capture and not self._pressed then
            self._pressed = true
            self._pressed_section = section
        end
        self:update_regions()
    elseif event == 'up' then
        if not self.app.owner:has_pointer_capture() then
            self._pressed = false
            self._pressed_section = nil
        end
        self:update_regions()
    end
    self.app:request_frame()
end

function MpInput:_input_section(index)
    return index == 1 and INPUT_SECTION or INPUT_SECTION .. '-' .. tostring(index)
end

function MpInput:_register_section(section)
    owned_sections[section] = true
end

function MpInput:_clear_owned_sections()
    for section in pairs(owned_sections) do
        self:_disable_section(section)
    end
    owned_sections = {}
end

function MpInput:_wheel_section(index)
    return index == 1 and WHEEL_SECTION or WHEEL_SECTION .. '-' .. tostring(index)
end

---@param section string
function MpInput:_define_input_section(section)
    self:_register_section(section)
    mp.set_key_bindings({
        { 'mbtn_left', function() self:_dispatch('up', 'left', section) end, function()
            self:_dispatch('down', 'left', section)
        end },
        { 'mbtn_right', function() self:_dispatch('up', 'right', section) end, function()
            self:_dispatch('down', 'right', section)
        end },
        { 'mbtn_mid', function() self:_dispatch('up', 'middle', section) end, function()
            self:_dispatch('down', 'middle', section)
        end },
        { 'mbtn_left_dbl', function() self:_dispatch('double', 'left', section) end },
        { 'mbtn_right_dbl', function() self:_dispatch('double', 'right', section) end },
    }, section, 'force')
end

---@param section string
function MpInput:_define_wheel_section(section)
    self:_register_section(section)
    mp.set_key_bindings({
        { 'wheel_up', function() self:_dispatch('wheel', 1) end },
        { 'wheel_down', function() self:_dispatch('wheel', -1) end },
        { 'wheel_left', function() self:_dispatch('wheel', { x = -1, y = 0 }) end },
        { 'wheel_right', function() self:_dispatch('wheel', { x = 1, y = 0 }) end },
    }, section, 'force')
end

function MpInput:_bind_keys()
    self:_define_input_section(INPUT_SECTION)
    self:_define_wheel_section(WHEEL_SECTION)
    mp.disable_key_bindings(INPUT_SECTION)
    mp.disable_key_bindings(WHEEL_SECTION)
end

---@param section string
function MpInput:_clear_mouse_area(section)
    if mp.set_mouse_area then
        mp.set_mouse_area(0, 0, 0, 0, section)
    end
end

function MpInput:_clear_mouse_areas()
    self:_clear_mouse_area(INPUT_SECTION)
    self:_clear_mouse_area(WHEEL_SECTION)
end

---@return Rect
function MpInput:_viewport_rect()
    local display = self.app.display
    local width, height = display.width, display.height
    if width <= 0 or height <= 0 then
        width, height = mp.get_osd_size()
    end
    return geometry.Rect(0, 0, width, height)
end

---@param rect Rect
---@param section string
function MpInput:_set_mouse_area(rect, section)
    if mp.set_mouse_area then
        mp.set_mouse_area(
            pixel_floor(rect.left),
            pixel_floor(rect.top),
            pixel_ceil(rect.right),
            pixel_ceil(rect.bottom),
            section)
    end
end

---@param section string
function MpInput:_disable_section(section)
    self:_clear_mouse_area(section)
    mp.disable_key_bindings(section)
end

---@param regions PointerRegion[]
function MpInput:_apply_regions(regions)
    for _, section in ipairs(self._input_sections) do
        self:_disable_section(section)
    end
    for _, section in ipairs(self._wheel_sections) do
        self:_disable_section(section)
    end
    self._input_sections = {}
    self._wheel_sections = {}

    local down_index, wheel_index = 0, 0
    ---@type string?
    local pressed_section = nil
    if self._pressed then
        pressed_section = self._pressed_section
    end
    local pressed_section_found = false
    for _, region in ipairs(regions) do
        if region.down then
            down_index = down_index + 1
            local section = self:_input_section(down_index)
            if down_index > 1 then
                self:_define_input_section(section)
            end
            if pressed_section == nil or pressed_section == section then
                self._input_sections[#self._input_sections + 1] = section
                local area = region.rect
                if pressed_section == section then
                    area = self:_viewport_rect()
                    pressed_section_found = true
                end
                self:_set_mouse_area(area, section)
                mp.enable_key_bindings(section, BINDING_FLAGS)
            end
        end
        if pressed_section == nil and region.wheel then
            wheel_index = wheel_index + 1
            local section = self:_wheel_section(wheel_index)
            if wheel_index > 1 then
                self:_define_wheel_section(section)
            end
            self._wheel_sections[#self._wheel_sections + 1] = section
            self:_set_mouse_area(region.rect, section)
            mp.enable_key_bindings(section, BINDING_FLAGS)
        end
    end

    if pressed_section ~= nil and not pressed_section_found then
        local capture_section = pressed_section --[[@as string]]
        self:_define_input_section(capture_section)
        self._input_sections[#self._input_sections + 1] = capture_section
        self:_set_mouse_area(self:_viewport_rect(), capture_section)
        mp.enable_key_bindings(capture_section, BINDING_FLAGS)
    end
end

---@param regions PointerRegion[]
---@return string
local function region_signature(regions)
    local values = {}
    for _, region in ipairs(regions) do
        values[#values + 1] = string.format('%g,%g,%g,%g:%d:%d',
            region.rect.left, region.rect.top, region.rect.right, region.rect.bottom,
            region.down and 1 or 0, region.wheel and 1 or 0)
    end
    return table.concat(values, ';')
end

--- Synchronize RenderOwner regions with mpv sections and mouse areas.
function MpInput:update_regions()
    if self._shutdown then
        return
    end
    local regions = self.app.owner:pointer_regions()
    local signature = region_signature(regions) .. (self._pressed and ':pressed' or '')
    if signature == self._region_signature then
        return
    end
    self._region_signature = signature
    self._regions = regions
    self:_apply_regions(regions)
end

--- Cancel host-side pointer capture and restore the normal region policy.
function MpInput:cancel_capture()
    self.app.owner:cancel_pointer()
    self._pressed = false
    self._pressed_section = nil
    self._buttons = {}
    self:update_regions()
end

--- Release host input resources when the app is shutting down.
function MpInput:shutdown()
    if self._shutdown then
        return
    end
    self._shutdown = true
    if self._mouse_callback then
        mp.unobserve_property(self._mouse_callback)
        self._mouse_callback = nil
    end
    self.app.owner:clear_hover()
    self._pressed = false
    self._pressed_section = nil
    self._buttons = {}
    for _, section in ipairs(self._input_sections) do
        self:_disable_section(section)
    end
    for _, section in ipairs(self._wheel_sections) do
        self:_disable_section(section)
    end
    self._input_sections = {}
    self._wheel_sections = {}
    self:_clear_owned_sections()
    self:_disable_section(INPUT_SECTION)
    self:_disable_section(WHEEL_SECTION)
end

M.MpInput = MpInput

return M
