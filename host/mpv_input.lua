-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- Pointer/key input for the mpv host.
--
-- Follows uosc's `lib/cursor.lua` where it matters:
--   * the pointer comes from the `mouse-pos` property (pixel centres, +0.5);
--   * mouse buttons/wheel are captured through a named key binding *section*
--     which is only enabled while the cursor is over something interactive,
--     so ordinary clicks still reach mpv's default bindings elsewhere.

local mp = require 'mp'

local std = require 'elxlibs.std'
local geometry = require 'foundation.geometry'
local pointer_event = require 'foundation.pointer_event'

local Offset = geometry.Offset
local PointerEvent = pointer_event.PointerEvent
local math = math
local debug_msgf = rawget(_G, 'debug_msgf') or function(...) end
local debug_msg = rawget(_G, 'debug_msg') or function(...) end

---@class elxinput
local M = {}

local BINDING_GROUP = 'elxosc_mouse'
local BINDING_FLAGS = 'allow-vo-dragging+allow-hide-cursor'

---@class MpInput : std.object
---@field app App
---@field hover boolean
---@overload fun(app: App): MpInput
local MpInput = std.class.new('MpInput')

function MpInput:__init(app)
    self.app = app
    self.x, self.y = math.huge, math.huge
    self.hover = false
    self._enabled = false
    self._pressed = false
    self:_bind_mouse()
    self:_bind_keys()
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
    mp.observe_property('mouse-pos', 'native', function(_, mouse)
        if not mouse then
            return
        end
        if not mouse.hover then
            if self.hover then
                self.hover = false
                self.app.owner:clear_hover()
                self:_decide_bindings()
            end
            return
        end
        self.x, self.y = mouse.x + 0.5, mouse.y + 0.5
        self.hover = true
        self.app.owner:dispatch_pointer(PointerEvent('move', self:_point())) --[[@as PointerEvent]]
        self:_decide_bindings()
        self.app:request_frame()
    end)
end

---@param event string
---@param data any?
function MpInput:_dispatch(event, data)
    debug_msgf('MpInput:_dispatch(%s)', event)
    if event == 'down' then
        self:_refresh_position()
    end
    local handled = self.app.owner:dispatch_pointer(PointerEvent(event, self:_point(), data)) --[[@as PointerEvent]]
    if event == 'down' and data == 'left' then
        self._pressed = handled
    elseif event == 'up' and data == 'left' then
        self._pressed = false
    end
    self:_decide_bindings()
    self.app:request_frame()
end

function MpInput:_bind_keys()
    mp.set_key_bindings({
        { 'mbtn_left', function() self:_dispatch('up', 'left') end, function() self:_dispatch('down', 'left') end },
        { 'mbtn_right', function() self:_dispatch('up', 'right') end, function() self:_dispatch('down', 'right') end },
        { 'wheel_up', function() self:_dispatch('wheel', 1) end },
        { 'wheel_down', function() self:_dispatch('wheel', -1) end },
    }, BINDING_GROUP, 'force')
    mp.disable_key_bindings(BINDING_GROUP)
end

--- Enable the mouse section only while the cursor is over an interactive node,
--- so clicks elsewhere keep their normal mpv meaning.
function MpInput:_decide_bindings()
    local point = self:_point()
    local want = self._pressed or self.hover and (
        self.app.owner:wants_pointer('down', point)
        or self.app.owner:wants_pointer('wheel', point)) or false
    if want == self._enabled then
        return
    end
    self._enabled = want
    if want then
        debug_msg('enable_key_bindings')
        mp.enable_key_bindings(BINDING_GROUP, BINDING_FLAGS)
    else
        debug_msg('disable_key_bindings')
        mp.disable_key_bindings(BINDING_GROUP)
    end
end

M.MpInput = MpInput

return M
