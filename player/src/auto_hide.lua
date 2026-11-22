-- Player inactivity policy; framework visibility and animation stay reusable.
---@namespace elxosc
---@using elxosc
---@using elxosc.player

local std = require 'elxlibs.std'
local widget_mod = require 'src.widgets.framework'
local State = require('src.widgets.state').State
local StatefulWidget = widget_mod.StatefulWidget
local RenderOpacity = require('src.render.opacity').RenderOpacity
local Opacity = require('src.widgets.visibility').Opacity

---@class mod.player.src.auto_hide
local M = {}

--== AutoHide ===============================================================

---@class player.AutoHideController : std.object
---@field visible boolean
---@overload fun(visible: boolean?): self
local AutoHideController = std.class.new('AutoHideController')

function AutoHideController:__init(visible)
    if visible ~= nil and type(visible) ~= 'boolean' then
        error('AutoHideController.visible must be a boolean', 2)
    end
    self.visible = visible ~= false
    self._listeners = {}
end

---@param callback fun(event: 'activity'|'visibility', visible: boolean, x: number?, y: number?, viewport: Rect?)
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

---@param x number?
---@param y number?
---@param viewport Rect?
function AutoHideController:activity(x, y, viewport)
    local listeners = {}
    for callback in pairs(self._listeners) do
        listeners[#listeners + 1] = callback
    end
    for _, callback in ipairs(listeners) do
        callback('activity', self.visible, x, y, viewport)
    end
end

---@class player._AutoHideOptions
---@field child Widget?
---@field controller AutoHideController?
---@field timeout number? seconds of inactivity before hiding; zero disables timeout
---@field enabled boolean?
---@field maintain_state boolean?
---@field fade_duration number? seconds for frame-clock fade; zero disables fade
---@field bottom_hover boolean? reveal and retain only from the bottom hover zone
---@field hover_zone number? bottom hover zone height in logical pixels
---@field top_hover boolean? reveal and retain only from the top hover zone
---@field top_hover_enabled boolean? application policy gate for the top zone
---@field top_hover_zone number? top hover zone height in logical pixels
---@field key any?

---@class player.AutoHide : StatefulWidget
---@field child Widget?
---@field controller AutoHideController
---@field timeout number
---@field enabled boolean
---@field maintain_state boolean
---@field fade_duration number
---@field bottom_hover boolean
---@field hover_zone number
---@field top_hover boolean
---@field top_hover_enabled boolean
---@field top_hover_zone number
---@overload fun(options?: _AutoHideOptions): self
local AutoHide = std.class.new('AutoHide', StatefulWidget)

function AutoHide:__init(options)
    options = options or {}
    self.key = options.key
    self.child = options.child
    self.controller = options.controller or AutoHideController()
    self.timeout = options.timeout == nil and 3 or options.timeout
    self.enabled = options.enabled ~= false
    self.maintain_state = options.maintain_state ~= false
    self.fade_duration = options.fade_duration == nil and 0.15 or options.fade_duration
    self.bottom_hover = options.bottom_hover == true
    self.hover_zone = options.hover_zone == nil and 175 or options.hover_zone
    self.top_hover = options.top_hover == true
    self.top_hover_enabled = options.top_hover_enabled == nil
        and true or options.top_hover_enabled
    self.top_hover_zone = options.top_hover_zone == nil and 40 or options.top_hover_zone
    if type(self.top_hover_enabled) ~= 'boolean' then
        error('AutoHide.top_hover_enabled must be a boolean', 2)
    end
    if type(self.timeout) ~= 'number' or self.timeout < 0
        or self.timeout == math.huge or self.timeout ~= self.timeout then
        error('AutoHide.timeout must be a finite non-negative number', 2)
    end
    if type(self.fade_duration) ~= 'number' or self.fade_duration < 0
        or self.fade_duration == math.huge or self.fade_duration ~= self.fade_duration then
        error('AutoHide.fade_duration must be a finite non-negative number', 2)
    end
    if type(self.hover_zone) ~= 'number' or self.hover_zone < 0
        or self.hover_zone == math.huge or self.hover_zone ~= self.hover_zone then
        error('AutoHide.hover_zone must be a finite non-negative number', 2)
    end
    if type(self.top_hover_zone) ~= 'number' or self.top_hover_zone < 0
        or self.top_hover_zone == math.huge or self.top_hover_zone ~= self.top_hover_zone then
        error('AutoHide.top_hover_zone must be a finite non-negative number', 2)
    end
    if not std.isinstance(self.controller, AutoHideController) then
        error('AutoHide.controller must be an AutoHideController', 2)
    end
end

---@class player.AutoHideState : State
---@field private _policy_cache _TreeQueryCache?
---@field elapsed number
---@field opacity number
---@field hidden boolean
---@field _remove_listener fun()?
---@field _ticker Ticker?
---@field _fade_controller AnimationController?
---@field _fade_listener fun(controller: AnimationController)?
---@overload fun(): self
local AutoHideState = std.class.new('AutoHideState', State)

function AutoHideState:__init()
    std.super(AutoHideState, self, State).__init(self)
    self.elapsed = 0
    self.opacity = 1
    self.hidden = false
    self._remove_listener = nil
    self._ticker = nil
    self._fade_controller = nil
    self._fade_listener = nil
end

function AutoHideState:_render_opacity()
    local context = self.context
    local render_object = context and context:first_render_object()
    if render_object and std.isinstance(render_object, RenderOpacity) then
        return render_object
    end
    return nil
end

function AutoHideState:_apply_render_state()
    local render_object = self:_render_opacity()
    if render_object == nil then
        return
    end
    render_object:set_opacity(self.opacity)
    render_object:set_hidden(self.hidden)
end

---@return Element[]
function AutoHideState:_policy_targets()
    local context = self.context
    local cache = self._policy_cache
    if cache == nil then
        cache = {}
        self._policy_cache = cache
        if context and context.owner then
            context.owner:_register_tree_cache(cache)
        end
    end
    if cache.value == nil or context ~= cache.value.context then
        local elements = {}
        local function visit(element)
            if element.state then
                elements[#elements + 1] = element
            end
            for _, child in ipairs(element:element_children()) do
                visit(child)
            end
        end
        if context then
            visit(context)
        end
        cache.value = { context = context, elements = elements }
    end
    return cache.value.elements
end

---@return boolean
function AutoHideState:_child_requests_visibility()
    for _, element in ipairs(self:_policy_targets()) do
        local state = element.state
        if state and type(state.keep_auto_hide_visible) == 'function' and state:keep_auto_hide_visible() then
            return true
        end
    end
    return false
end

-- Retained children may own external hover resources. Notify only when the
-- visibility policy changes, before fading; keep ordinary input unchanged.
function AutoHideState:_notify_child_visibility()
    for _, element in ipairs(self:_policy_targets()) do
        if element ~= self.context then
            local state = element.state
            if state and type(state.refresh_hover_visibility) == 'function' then
                state:refresh_hover_visibility()
            end
        end
    end
end

---@param controller AnimationController
function AutoHideState:_fade_changed(controller)
    self.opacity = controller.value
    local render_object = self:_render_opacity()
    if render_object then
        render_object:set_opacity(self.opacity)
    end
    if controller.status == 'dismissed' and self.hidden == false
        and not (self.widget --[[@as AutoHide]]).controller.visible then
        self.hidden = true
        self:_apply_render_state()
        local owner = self.context and self.context.owner
        if owner and owner.render_owner then
            owner.render_owner:cancel_pointer()
        end
        local widget = self.widget --[[@as AutoHide]]
        if not widget.maintain_state and self:is_mounted() then
            self:set_state()
        end
    elseif controller.status == 'completed' then
        self.hidden = false
        self.opacity = 1
        self:_apply_render_state()
    end
end

function AutoHideState:_dispose_fade_controller()
    local controller = self._fade_controller
    if controller == nil then
        return
    end
    if self._fade_listener then
        controller:remove_listener(self._fade_listener)
    end
    controller:dispose()
    self._fade_controller = nil
    self._fade_listener = nil
end

function AutoHideState:_ensure_fade_controller()
    local widget = self.widget --[[@as AutoHide]]
    if widget.fade_duration <= 0 then
        self:_dispose_fade_controller()
        return nil
    end
    if self._fade_controller then
        return self._fade_controller
    end
    local context = self.context
    local owner = context and context.owner
    if owner == nil or owner.scheduler == nil then
        return nil
    end
    local controller = self:create_animation_controller({ duration = widget.fade_duration })
    local listener = function(animation)
        self:_fade_changed(animation)
    end
    controller:add_listener(listener)
    self._fade_controller = controller
    self._fade_listener = listener
    controller.value = self.opacity
    return controller
end

function AutoHideState:_finish_hidden()
    self.opacity = 0
    self.hidden = true
    local controller = self._fade_controller
    if controller and controller:is_animating() then
        controller:stop()
    end
    self:_apply_render_state()
    local owner = self.context and self.context.owner
    if owner and owner.render_owner then
        owner.render_owner:cancel_pointer()
    end
    local widget = self.widget --[[@as AutoHide]]
    if not widget.maintain_state and self:is_mounted() then
        self:set_state()
    end
end

function AutoHideState:_set_visibility(visible)
    local widget = self.widget --[[@as AutoHide]]
    self:_notify_child_visibility()
    if visible then
        self.hidden = false
        if self.opacity <= 0 then
            self.opacity = 0
        end
        self:_apply_render_state()
        if not self:is_mounted() then
            return
        end
        self:set_state()
        local controller = self:_ensure_fade_controller()
        if controller then
            controller:forward(self.opacity)
        else
            self.opacity = 1
            self:_apply_render_state()
        end
        return
    end

    if self.hidden then
        return
    end
    local controller = self:_ensure_fade_controller()
    if controller and self.opacity > 0 then
        controller:reverse(self.opacity)
    else
        self:_finish_hidden()
    end
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

function AutoHideState:_controller_event(event, visible, x, y, viewport)
    if event == 'activity' then
        local widget = self.widget --[[@as AutoHide]]
        if self:_child_requests_visibility() then
            self:_restart_timer()
            if not widget.controller.visible then
                widget.controller:show()
            end
            return
        end
        local in_hover_zone = true
        if (widget.bottom_hover or (widget.top_hover and widget.top_hover_enabled))
            and x ~= nil and y ~= nil and viewport ~= nil then
            local in_viewport = y >= viewport.top and y < viewport.bottom
            local in_bottom_zone = widget.bottom_hover
                and y >= viewport.bottom - widget.hover_zone
            local in_top_zone = widget.top_hover and widget.top_hover_enabled
                and y >= viewport.top
                and y < viewport.top + widget.top_hover_zone
            in_hover_zone = in_viewport and (in_bottom_zone or in_top_zone)
        end
        if not in_hover_zone then
            if widget.controller.visible then
                widget.controller:hide()
            end
            if self._ticker then
                self._ticker:stop()
            end
            return
        end
        self:_restart_timer()
        if not widget.controller.visible then
            widget.controller:show()
        end
        return
    end
    self:_set_visibility(visible)
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
    self.hidden = not widget.controller.visible
    self.opacity = self.hidden and 0 or 1
    self._remove_listener = widget.controller:add_listener(function(event, visible, x, y, viewport)
        self:_controller_event(event, visible, x, y, viewport)
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
            if self:_child_requests_visibility() then
                self.elapsed = 0
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
        self._remove_listener = widget.controller:add_listener(function(event, visible, x, y, viewport)
            self:_controller_event(event, visible, x, y, viewport)
        end)
        self.hidden = not widget.controller.visible
        self.opacity = self.hidden and 0 or 1
        self:_notify_child_visibility()
        self:_apply_render_state()
        if self:is_mounted() then
            self:set_state()
        end
    elseif old.fade_duration ~= widget.fade_duration then
        self:_dispose_fade_controller()
    end
    self:_restart_timer()
end

function AutoHideState:dispose()
    self._policy_cache = nil
    if self._remove_listener then
        self._remove_listener()
        self._remove_listener = nil
    end
    if self._ticker then
        self._ticker:stop()
        self._ticker = nil
    end
    self:_dispose_fade_controller()
end

function AutoHideState:build()
    local widget = self.widget --[[@as AutoHide]]
    if self.hidden and not widget.maintain_state then
        return nil
    end
    return Opacity({
        opacity = self.opacity,
        hidden = self.hidden,
        child = widget.child,
    })
end

function AutoHide:create_state()
    return AutoHideState()
end

M.AutoHideController = AutoHideController
M.AutoHide = AutoHide
M.AutoHideState = AutoHideState

return M
