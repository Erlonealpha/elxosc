-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- Backend-independent pointer input value. The owner still accepts the
-- historical (event, point, data) arguments; this value gives hosts a
-- structured place to carry pointer metadata without growing that positional
-- interface.

local std = require 'elxlibs.std'
local geometry = require 'foundation.geometry'

local Offset = geometry.Offset
local floor = math.floor
local raise = std.raise
local huge = math.huge
local M = {}

---@alias PointerEventType
--- | 'down'
--- | 'up'
--- | 'cancel'
--- | 'move'
--- | 'enter'
--- | 'leave'
--- | 'wheel'
--- | 'double'

---@alias PointerEvents PointerEventType

---@alias PointerButton
--- | 'left'
--- | 'middle'
--- | 'right'

---@alias PointerSource
--- | 'mouse'

---@alias PointerPoint Offset | {x: number, y: number}

---@class InputModifiers
---@field shift boolean?
---@field ctrl boolean?
---@field alt boolean?
---@field meta boolean?

---@class PointerButtons
---@field left boolean?
---@field middle boolean?
---@field right boolean?

---@class _PointerEventFields : table<string, any>
---@field type PointerEventType
---@field point PointerPoint?
---@field data any?
---@field pointer_id integer?
---@field button PointerButton?
---@field buttons PointerButtons?
---@field click_count integer?
---@field delta_x number?
---@field delta_y number?
---@field modifiers InputModifiers?
---@field source PointerSource?
---@field timestamp number?

---@class PointerEvent : std.object
---@field [string] any extension fields are retained verbatim
---@field type PointerEventType
---@field point Offset?
---@field data any?
---@field pointer_id integer?
---@field button PointerButton?
---@field buttons PointerButtons?
---@field click_count integer?
---@field delta_x number?
---@field delta_y number?
---@field modifiers InputModifiers?
---@field source PointerSource?
---@field timestamp number?
---@overload fun(type: string, point: PointerPoint?, data: any?, extra: table?): self
---@overload fun(fields: _PointerEventFields): self
local PointerEvent = std.class.new('PointerEvent', {})
local instances = setmetatable({}, { __mode = 'k' })

local EVENT_TYPES = {
    down = true,
    up = true,
    cancel = true,
    move = true,
    enter = true,
    leave = true,
    wheel = true,
    double = true,
}

local BUTTONS = { left = true, middle = true, right = true }
local MODIFIERS = { shift = true, ctrl = true, alt = true, meta = true }

---@param value number
---@return boolean
local function is_finite(value)
    return value == value and value ~= huge and value ~= -huge
end

---@param value any
---@return boolean
local function is_integer(value)
    return type(value) == 'number' and is_finite(value) and value == floor(value)
end

---@param name string
---@param value table?
---@param allowed table<string, true>
---@return table?
local function copy_boolean_map(name, value, allowed)
    if value == nil then
        return nil
    end
    if type(value) ~= 'table' then
        raise(std.TypeError('PointerEvent.' .. name .. ' must be a table'))
    end
    local copy = {}
    for key, item in pairs(value) do
        if not allowed[key] then
            raise(std.ValueError('PointerEvent.' .. name .. ' has an unknown key'))
        end
        if type(item) ~= 'boolean' then
            raise(std.TypeError('PointerEvent.' .. name .. ' values must be boolean'))
        end
        copy[key] = item
    end
    return copy
end

---@param point any
---@param event_type PointerEventType
---@return Offset?
local function validate_point(point, event_type)
    if point == nil then
        if event_type == 'cancel' or event_type == 'leave' then
            return
        end
        raise(std.ValueError('PointerEvent.point is required for ' .. event_type))
    end
    if type(point) ~= 'table' then
        raise(std.TypeError('PointerEvent.point must be a finite Offset'))
    end
    if type(point.x) ~= 'number' or not is_finite(point.x)
        or type(point.y) ~= 'number' or not is_finite(point.y) then
        raise(std.ValueError('PointerEvent.point must be a finite Offset'))
    end
    return Offset(point.x, point.y)
end

---@param value any
---@return PointerEventType
local function validate_event_type(value)
    if type(value) ~= 'string' or not EVENT_TYPES[value] then
        raise(std.ValueError('PointerEvent.type is not supported'))
    end
    return value --[[@as PointerEventType]]
end

---@param name string
---@param value any
---@return number?
local function validate_finite(name, value)
    if value == nil then
        return nil
    end
    if type(value) ~= 'number' or not is_finite(value) then
        raise(std.ValueError('PointerEvent.' .. name .. ' must be a finite number'))
    end
    return value
end

---@param name string
---@param value any
---@param minimum number
---@param description string
---@return integer?
local function validate_integer(name, value, minimum, description)
    if value == nil then
        return nil
    end
    if not is_integer(value) or value < minimum then
        raise(std.ValueError('PointerEvent.' .. name .. ' must be ' .. description))
    end
    return value
end

---@param fields table
local function validate_fields(fields)
    local event_type = validate_event_type(fields.type)
    fields.type = event_type
    fields.point = validate_point(fields.point, event_type)
    fields.pointer_id = validate_integer(
        'pointer_id', fields.pointer_id, 0, 'a non-negative integer')
    if fields.button ~= nil
        and (type(fields.button) ~= 'string' or not BUTTONS[fields.button]) then
        raise(std.ValueError('PointerEvent.button is not supported'))
    end
    fields.buttons = copy_boolean_map('buttons', fields.buttons, BUTTONS)
    fields.click_count = validate_integer(
        'click_count', fields.click_count, 1, 'a positive integer')
    fields.delta_x = validate_finite('delta_x', fields.delta_x)
    fields.delta_y = validate_finite('delta_y', fields.delta_y)
    fields.timestamp = validate_finite('timestamp', fields.timestamp)
    fields.modifiers = copy_boolean_map('modifiers', fields.modifiers, MODIFIERS)
    if fields.source ~= nil and fields.source ~= 'mouse' then
        raise(std.ValueError('PointerEvent.source is not supported'))
    end
    if event_type == 'double' and fields.click_count == nil then
        fields.click_count = 2
    end
end

---@param event_or_fields string|_PointerEventFields
---@param point PointerPoint?
---@param data any?
---@param extra table?
function PointerEvent:__init(event_or_fields, point, data, extra)
    local fields = {}
    if type(event_or_fields) == 'table' then
        for key, value in pairs(event_or_fields) do
            fields[key] = value
        end
    else
        fields.type = event_or_fields
        fields.point = point
        fields.data = data
        if extra then
            if type(extra) ~= 'table' then
                raise(std.TypeError('PointerEvent extra fields must be a table'))
            end
            for key, value in pairs(extra) do
                fields[key] = value
            end
        end
    end
    validate_fields(fields)
    for key, value in pairs(fields) do
        self[key] = value
    end
    instances[self] = true
end

--- Convert structured fields back to the historical `data` payload.
---@param event PointerEvent
---@return any?
local function legacy_data(event)
    if event.data ~= nil then
        return event.data
    end
    if event.type == 'down' or event.type == 'up' or event.type == 'double' then
        return event.button
    end
    if event.type == 'wheel' then
        local delta_x = event.delta_x
        local delta_y = event.delta_y
        if delta_y ~= nil and (delta_x == nil or delta_x == 0) then
            return delta_y
        end
        if delta_x ~= nil and (delta_x ~= 0 or delta_y ~= nil) then
            return { x = delta_x or 0, y = delta_y or 0 }
        end
    end
    return nil
end

---@return any?
function PointerEvent:legacy_data()
    return legacy_data(self)
end

---@param value any
---@return boolean
function M.is_instance(value)
    return type(value) == 'table' and instances[value] == true
end

---@param event PointerEvent
---@return any?
function M.legacy_data(event)
    return legacy_data(event)
end

M.PointerEvent = PointerEvent

return M
