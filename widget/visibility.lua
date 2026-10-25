-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- Visibility and player-control auto-hide widgets.

local std = require 'elxlibs.std'
local offstage_mod = require 'render.offstage'
local widget_mod = require 'widget.widget'

local RenderOffstage = offstage_mod.RenderOffstage
local SingleChildRenderObjectWidget = widget_mod.SingleChildRenderObjectWidget
local StatelessWidget = widget_mod.StatelessWidget
local StatefulWidget = widget_mod.StatefulWidget
local State = require('widget.state').State

local M = {}

--== Offstage ===============================================================

---@class _OffstageOptions
---@field offstage boolean?
---@field child Widget?
---@field key any?
---@field id string?

---@class Offstage : SingleChildRenderObjectWidget
---@field offstage boolean
---@field child Widget?
---@overload fun(options?: _OffstageOptions): self
local Offstage = std.class.new('Offstage', { SingleChildRenderObjectWidget })

function Offstage:__init(options)
    options = options or {}
    self.key = options.key
    self.id = options.id
    self.offstage = options.offstage == true
    self.child = options.child
end

function Offstage:create_render_object()
    return RenderOffstage(self.offstage)
end

---@param render_object RenderOffstage
function Offstage:update_render_object(render_object)
    render_object:set_offstage(self.offstage)
end

--== Visibility =============================================================

---@class _VisibilityOptions
---@field visible boolean?
---@field maintain_state boolean?
---@field child Widget?
---@field key any?
---@field id string?

---@class Visibility : StatelessWidget
---@field visible boolean
---@field maintain_state boolean
---@field child Widget?
---@overload fun(options?: _VisibilityOptions): self
local Visibility = std.class.new('Visibility', { StatelessWidget })

function Visibility:__init(options)
    options = options or {}
    self.key = options.key
    self.id = options.id
    self.visible = options.visible ~= false
    self.maintain_state = options.maintain_state ~= false
    self.child = options.child
end

function Visibility:child_widgets()
    return self.child and { self.child } or {}
end

function Visibility:build()
    if self.visible then
        return self.child
    end
    if self.maintain_state then
        return Offstage({ offstage = true, child = self.child })
    end
    return nil
end

--== AutoHide ===============================================================

---@class AutoHideController : std.object
---@field visible boolean
---@overload fun(visible: boolean?): self
local AutoHideController = std.class.new('AutoHideController', {})

function AutoHideController:__init(visible)
    if visible ~= nil and type(visible) ~= 'boolean' then
        error('AutoHideController.visible must be a boolean', 2)
    end
    self.visible = visible ~= false
    self._listeners = {}
end

---@param callback fun(event: 'activity'|'visibility', visible: boolean)
---@return fun()
function AutoHideController:add_listener(callback)
    if type(callback) ~= 'function' then
        error('AutoHideController listener must be a function', 2)
    end
    self._listeners[callback] = true
    local active = true
    return function()
        if not active then
            return false
        end
        active = false
        self._listeners[callback] = nil
        return true
    end
end

---@param visible boolean
function AutoHideController:set_visible(visible)
    if type(visible) ~= 'boolean' then
        error('AutoHideController:set_visible expects a boolean', 2)
    end
    if self.visible == visible then
        return false
    end
    self.visible = visible
    local listeners = {}
    for callback in pairs(self._listeners) do
        listeners[#listeners + 1] = callback
    end
    for _, callback in ipairs(listeners) do
        callback('visibility', visible)
    end
    return true
end

function AutoHideController:show()
    return self:set_visible(true)
end

function AutoHideController:hide()
    return self:set_visible(false)
end

function AutoHideController:activity()
    local listeners = {}
    for callback in pairs(self._listeners) do
        listeners[#listeners + 1] = callback
    end
    for _, callback in ipairs(listeners) do
        callback('activity', self.visible)
    end
end

---@class _AutoHideOptions
---@field child Widget?
---@field controller AutoHideController?
---@field timeout number? seconds of inactivity before hiding; zero disables timeout
---@field enabled boolean?
---@field maintain_state boolean?
---@field key any?

---@class AutoHide : StatefulWidget
---@field child Widget?
---@field controller AutoHideController
---@field timeout number
---@field enabled boolean
---@field maintain_state boolean
---@overload fun(options?: _AutoHideOptions): self
local AutoHide = std.class.new('AutoHide', { StatefulWidget })

function AutoHide:__init(options)
    options = options or {}
    self.key = options.key
    self.child = options.child
    self.controller = options.controller or AutoHideController()
    self.timeout = options.timeout == nil and 3 or options.timeout
    self.enabled = options.enabled ~= false
    self.maintain_state = options.maintain_state ~= false
    if type(self.timeout) ~= 'number' or self.timeout < 0
        or self.timeout == math.huge or self.timeout ~= self.timeout then
        error('AutoHide.timeout must be a finite non-negative number', 2)
    end
    if not std.isinstance(self.controller, AutoHideController) then
        error('AutoHide.controller must be an AutoHideController', 2)
    end
end

---@class AutoHideState : State
---@field elapsed number
---@field _remove_listener fun()?
---@field _ticker Ticker?
---@overload fun(): self
local AutoHideState = std.class.new('AutoHideState', { State })

function AutoHideState:__init()
    std.super(AutoHideState, self, State).__init(self)
    self.elapsed = 0
    self._remove_listener = nil
    self._ticker = nil
end

function AutoHideState:_restart_timer()
    self.elapsed = 0
    local ticker = self._ticker
    if ticker then
        if self.widget.enabled and self.widget.timeout > 0
            and self.widget.controller.visible then
            ticker:start()
        else
            ticker:stop()
        end
    end
end

function AutoHideState:_controller_event(event, visible)
    if event == 'activity' then
        self:_restart_timer()
        if not self.widget.controller.visible and self:is_mounted() then
            self:set_state(function()
                self.widget.controller.visible = true
            end)
        end
        return
    end
    if self:is_mounted() then
        self:set_state(function() end)
    end
    if self._ticker then
        if visible and self.widget.enabled and self.widget.timeout > 0 then
            self._ticker:start()
        else
            self._ticker:stop()
        end
    end
end

function AutoHideState:init_state()
    local widget = self.widget --[[@as AutoHide]]
    self._remove_listener = widget.controller:add_listener(function(event, visible)
        self:_controller_event(event, visible)
    end)

    local context = self.context
    local owner = context and context.owner
    if owner and owner.scheduler and widget.enabled and widget.timeout > 0 then
        self._ticker = self:create_ticker(function(dt)
            local current_widget = self.widget --[[@as AutoHide]]
            local ticker = self._ticker
            if ticker == nil then
                return
            end
            if not current_widget.controller.visible then
                ticker:stop()
                return
            end
            self.elapsed = self.elapsed + dt
            if self.elapsed >= current_widget.timeout then
                current_widget.controller:hide()
                ticker:stop()
            end
        end)
        self._ticker:start()
    end
end

function AutoHideState:did_update_widget(old_widget)
    local old = old_widget --[[@as AutoHide]]
    local widget = self.widget --[[@as AutoHide]]
    if old.controller ~= widget.controller then
        if self._remove_listener then
            self._remove_listener()
        end
        self._remove_listener = widget.controller:add_listener(function(event, visible)
            self:_controller_event(event, visible)
        end)
    end
    self:_restart_timer()
end

function AutoHideState:dispose()
    if self._remove_listener then
        self._remove_listener()
        self._remove_listener = nil
    end
    if self._ticker then
        self._ticker:stop()
        self._ticker = nil
    end
end

function AutoHideState:build()
    local widget = self.widget --[[@as AutoHide]]
    return Visibility({
        visible = widget.controller.visible,
        maintain_state = widget.maintain_state,
        child = widget.child,
    })
end

function AutoHide:create_state()
    return AutoHideState()
end

M.Offstage = Offstage
M.Visibility = Visibility
M.AutoHideController = AutoHideController
M.AutoHide = AutoHide
M.AutoHideState = AutoHideState

return M
