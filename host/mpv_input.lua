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
local key_event = require 'foundation.key_event'
local region_snapshot = require 'render.region_snapshot'

local Offset = geometry.Offset
local PointerEvent = pointer_event.PointerEvent
local KeyEvent = key_event.KeyEvent
local RegionSnapshot = region_snapshot.RegionSnapshot
local raise = std.raise
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
local NAVIGATION_SECTION = 'elxosc-navigation'
local BINDING_FLAGS = 'allow-hide-cursor'
local owned_sections = {}

---@class MpInputOwner
---@field clear_hover fun(self: MpInputOwner)
---@field cancel_pointer fun(self: MpInputOwner)
---@field dispatch_pointer_result fun(self: MpInputOwner, event: PointerEvent): DispatchResult
---@field has_pointer_capture fun(self: MpInputOwner): boolean
---@field pointer_regions fun(self: MpInputOwner): PointerRegion[]
---@field region_snapshot (fun(self: MpInputOwner): RegionSnapshot)?

---@class MpInputOptions
---@field owner MpInputOwner receives structured pointer events
---@field get_viewport fun(): Rect returns the current root-space viewport
---@field notify_activity fun() informs application visibility policies
---@field request_frame fun() schedules a frame after input
---@field get_can_pop (fun(): boolean)? whether an ESC action is currently claimed
---@field handle_key (fun(event: KeyEvent): boolean)? dispatches a structured key event

---@class MpInput : std.object
---@field owner MpInputOwner
---@field get_viewport fun(): Rect
---@field notify_activity fun()
---@field request_frame fun()
---@field get_can_pop fun(): boolean
---@field handle_key fun(event: KeyEvent): boolean?
---@field hover boolean
---@field _regions PointerRegion[]
---@field _snapshot RegionSnapshot?
---@field _last_viewport Rect?
---@field _last_pressed_section string?
---@field _last_pressed boolean?
---@field _defined_sections table<string, true>
---@field _active_sections table<string, Rect>
---@field _section_order string[]
---@field _input_sections string[]
---@field _wheel_sections string[]
---@field _navigation_enabled boolean
---@field _pressed_section string?
---@field _buttons table<PointerButton, true>
---@field _cancelled_buttons table<PointerButton, true>
---@field _mouse_callback fun(name: string, mouse: table)?
---@field _shutdown boolean
---@overload fun(options: MpInputOptions): self
local MpInput = std.class.new('MpInput', {})

function MpInput:__init(options)
    options = options or {}
    if options.owner == nil then
        raise(std.TypeError('MpInput.owner is required'))
    end
    if type(options.get_viewport) ~= 'function' then
        raise(std.TypeError('MpInput.get_viewport is required'))
    end
    if type(options.notify_activity) ~= 'function' then
        raise(std.TypeError('MpInput.notify_activity is required'))
    end
    if type(options.request_frame) ~= 'function' then
        raise(std.TypeError('MpInput.request_frame is required'))
    end
    self.owner = options.owner
    self.get_viewport = options.get_viewport
    self.notify_activity = options.notify_activity
    self.request_frame = options.request_frame
    self.get_can_pop = type(options.get_can_pop) == 'function'
        and options.get_can_pop or function() return false end
    self.handle_key = type(options.handle_key) == 'function'
        and options.handle_key or function() return false end
    self.x, self.y = huge, huge
    self.hover = false
    self._pressed = false
    self._regions = {}
    self._snapshot = nil
    self._last_viewport = nil
    self._last_pressed_section = nil
    self._last_pressed = nil
    self._defined_sections = {}
    self._active_sections = {}
    self._section_order = {}
    self._input_sections = {}
    self._wheel_sections = {}
    self._navigation_enabled = false
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
                self.owner:clear_hover()
            end
            if self._pressed then
                self.owner:cancel_pointer()
                self._pressed = false
                self._pressed_section = nil
                self:update_regions()
            end
            self._buttons = {}
            return
        end
        self.x, self.y = mouse.x + 0.5, mouse.y + 0.5
        self.hover = true
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
    if event == 'move' or event == 'down' or event == 'double' or event == 'wheel' then
        self.notify_activity()
    end
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
    local result = self.owner:dispatch_pointer_result(pointer)
    if event == 'down' then
        if result.capture and not self._pressed then
            self._pressed = true
            self._pressed_section = section
        end
        self:update_regions()
    elseif event == 'up' then
        if not self.owner:has_pointer_capture() then
            self._pressed = false
            self._pressed_section = nil
        end
        self:update_regions()
    end
    self.request_frame()
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
    if self._defined_sections[section] then
        return
    end
    self:_register_section(section)
    self._defined_sections[section] = true
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
    if self._defined_sections[section] then
        return
    end
    self:_register_section(section)
    self._defined_sections[section] = true
    mp.set_key_bindings({
        { 'wheel_up', function() self:_dispatch('wheel', 1) end },
        { 'wheel_down', function() self:_dispatch('wheel', -1) end },
        { 'wheel_left', function() self:_dispatch('wheel', { x = -1, y = 0 }) end },
        { 'wheel_right', function() self:_dispatch('wheel', { x = 1, y = 0 }) end },
    }, section, 'force')
end

---@param section string
function MpInput:_define_navigation_section(section)
    self:_register_section(section)
    mp.set_key_bindings({
        { 'ESC', function()
            self:_dispatch_key('ESC')
        end },
    }, section, 'force')
end

function MpInput:_bind_keys()
    self:_define_input_section(INPUT_SECTION)
    self:_define_wheel_section(WHEEL_SECTION)
    self:_define_navigation_section(NAVIGATION_SECTION)
    mp.disable_key_bindings(INPUT_SECTION)
    mp.disable_key_bindings(WHEEL_SECTION)
    mp.disable_key_bindings(NAVIGATION_SECTION)
end

---@param key string
function MpInput:_dispatch_key(key)
    if self._shutdown then
        return
    end
    local event = KeyEvent({
        key = key,
        type = 'press',
        timestamp = mp.get_time(),
    })
    if self.handle_key(event) then
        self.notify_activity()
        self.request_frame()
    end
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
    return self.get_viewport()
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
    self._active_sections[section] = nil
    for index, current in ipairs(self._section_order) do
        if current == section then
            table.remove(self._section_order, index)
            break
        end
    end
end

---@param regions PointerRegion[]
function MpInput:_apply_regions(regions)
    self._input_sections = {}
    self._wheel_sections = {}
    local desired, order = {}, {}
    local viewport = self:_viewport_rect()
    local function add(section, rect, family)
        local area = rect:intersect(viewport)
        if area:is_empty() then
            return
        end
        desired[section] = area
        order[#order + 1] = section
        family[#family + 1] = section
    end
    local down_index, wheel_index = 0, 0
    if self._pressed then
        local section = self._pressed_section or INPUT_SECTION
        self:_define_input_section(section)
        add(section, viewport, self._input_sections)
    else
        for _, region in ipairs(regions) do
            if region.down then
                down_index = down_index + 1
                local section = self:_input_section(down_index)
                self:_define_input_section(section)
                add(section, region.rect, self._input_sections)
            end
            if region.wheel then
                wheel_index = wheel_index + 1
                local section = self:_wheel_section(wheel_index)
                self:_define_wheel_section(section)
                add(section, region.rect, self._wheel_sections)
            end
        end
    end

    -- Remove only obsolete sections. Geometry updates must not reorder mpv's
    -- active stack or allocate new Lua script-binding callbacks.
    for index = #self._section_order, 1, -1 do
        local section = self._section_order[index]
        if not desired[section] then
            self:_disable_section(section)
        end
    end
    local predicted = {}
    for _, section in ipairs(self._section_order) do
        predicted[#predicted + 1] = section
    end
    for _, section in ipairs(order) do
        if not self._active_sections[section] then
            predicted[#predicted + 1] = section
        end
    end
    for index, section in ipairs(order) do
        if predicted[index] ~= section then
            for old_index = #self._section_order, 1, -1 do
                self:_disable_section(self._section_order[old_index])
            end
            break
        end
    end
    for _, section in ipairs(order) do
        local previous = self._active_sections[section]
        ---@type Rect
        local area = desired[section]
        if previous ~= area then
            self:_set_mouse_area(area, section)
        end
        if previous == nil then
            mp.enable_key_bindings(section, BINDING_FLAGS)
        end
        self._active_sections[section] = area
    end
    self._section_order = order
end

function MpInput:_sync_navigation()
    local can_pop = self.get_can_pop() == true
    if can_pop == self._navigation_enabled then
        return
    end
    self._navigation_enabled = can_pop
    if can_pop then
        mp.enable_key_bindings(NAVIGATION_SECTION, BINDING_FLAGS)
    else
        self:_disable_section(NAVIGATION_SECTION)
    end
end

--- Synchronize RenderOwner regions with mpv sections and mouse areas.
function MpInput:update_regions()
    if self._shutdown then
        return
    end
    if self._pressed and not self.owner:has_pointer_capture() then
        self._pressed = false
        self._pressed_section = nil
        self._buttons = {}
    end
    self:_sync_navigation()
    local snapshot = self.owner.region_snapshot and self.owner:region_snapshot()
        or RegionSnapshot({ generation = 0, regions = self.owner:pointer_regions() })
    local viewport = self:_viewport_rect()
    if snapshot:same_regions(self._snapshot) and viewport == self._last_viewport
        and self._pressed == self._last_pressed
        and self._pressed_section == self._last_pressed_section then
        return
    end
    self._snapshot = snapshot
    self._last_viewport = viewport
    self._last_pressed = self._pressed
    self._last_pressed_section = self._pressed_section
    self._regions = snapshot:regions()
    self:_apply_regions(self._regions)
end

--- Cancel host-side pointer capture and restore the normal region policy.
function MpInput:cancel_capture()
    self.owner:cancel_pointer()
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
    self.owner:clear_hover()
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
    self._navigation_enabled = false
    self:_clear_owned_sections()
    self:_disable_section(INPUT_SECTION)
    self:_disable_section(WHEEL_SECTION)
    self:_disable_section(NAVIGATION_SECTION)
end

M.MpInput = MpInput

return M
