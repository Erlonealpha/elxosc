-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- Backend-independent keyboard input value. Host adapters create these values;
-- focus ownership and keyboard routing remain outside this value type.

local std = require 'elxlibs.std'

local huge = math.huge
local raise = std.raise
local M = {}

---@alias KeyEventType
--- | 'down'
--- | 'up'
--- | 'press'

---@class _KeyEventFields
---@field key string
---@field type KeyEventType
---@field modifiers InputModifiers?
---@field is_repeat boolean?
---@field timestamp number?

---@class KeyEvent : std.object
---@field key string
---@field type KeyEventType
---@field modifiers InputModifiers?
---@field is_repeat boolean
---@field timestamp number?
---@overload fun(fields: _KeyEventFields): self
local KeyEvent = std.class.new('KeyEvent', {})

local EVENT_TYPES = { down = true, up = true, press = true }
local MODIFIERS = { shift = true, ctrl = true, alt = true, meta = true }

---@param value number
---@return boolean
local function is_finite(value)
    return value == value and value ~= huge and value ~= -huge
end

---@param value any
---@return KeyEventType
local function validate_event_type(value)
    if type(value) ~= 'string' or not EVENT_TYPES[value] then
        raise(std.ValueError('KeyEvent.type is not supported'))
    end
    return value --[[@as KeyEventType]]
end

---@param value any
---@return number?
local function validate_timestamp(value)
    if value == nil then
        return nil
    end
    if type(value) ~= 'number' or not is_finite(value) then
        raise(std.ValueError('KeyEvent.timestamp must be a finite number'))
    end
    return value
end

---@param modifiers InputModifiers?
---@return InputModifiers?
local function copy_modifiers(modifiers)
    if modifiers == nil then
        return nil
    end
    if type(modifiers) ~= 'table' then
        raise(std.TypeError('KeyEvent.modifiers must be a table'))
    end
    local copy = {}
    for key, value in pairs(modifiers) do
        if not MODIFIERS[key] then
            raise(std.ValueError('KeyEvent.modifiers has an unknown key'))
        end
        if type(value) ~= 'boolean' then
            raise(std.TypeError('KeyEvent.modifiers values must be boolean'))
        end
        copy[key] = value
    end
    return copy
end

---@param fields _KeyEventFields
function KeyEvent:__init(fields)
    if type(fields) ~= 'table' then
        raise(std.TypeError('KeyEvent expects a fields table'))
    end
    if type(fields.key) ~= 'string' or fields.key == '' then
        raise(std.ValueError('KeyEvent.key must be a non-empty string'))
    end
    local event_type = validate_event_type(fields.type)
    if fields.is_repeat ~= nil and type(fields.is_repeat) ~= 'boolean' then
        raise(std.TypeError('KeyEvent.is_repeat must be a boolean'))
    end
    self.key = fields.key
    self.type = event_type
    self.modifiers = copy_modifiers(fields.modifiers)
    self.is_repeat = fields.is_repeat == true
    self.timestamp = validate_timestamp(fields.timestamp)
end

M.KeyEvent = KeyEvent

return M
