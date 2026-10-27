-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- mpv host wiring: the single App owner and its frame loop.
--
-- Mirrors uosc's proven main loop (`lib/utils.lua`: `render` + `request_render`):
--   * frames are coalesced and rate limited to the display refresh rate;
--   * the overlay is only pushed when its data or resolution changed;
--   * `mp.get_osd_size()` is the logical (1:1) coordinate space, so an
--     `ass-events` overlay with matching `res_x`/`res_y` maps pixels 1:1.
--
-- Since the Widget layer landed, the app drives a `WidgetsBinding` rather than a
-- hand-built `RenderObject` tree (dev/design/HOST.md): `build()` returns a
-- Widget, the binding turns it into the render tree, and every frame flushes
-- pending rebuilds before layout.

local mp = require 'mp'

local std = require 'elxlibs.std'
local constraints_mod = require 'layout.constraints'
local geometry = require 'foundation.geometry'
local scheduler_mod = require 'scheduler.scheduler'
local pipeline_owner = require 'render.pipeline_owner'
local ass_canvas = require 'backends.ass_canvas'
local ass_text_layout = require 'backends.ass_text_layout'
local text_layout = require 'text.text_layout'
local binding_mod = require 'widget.widgets_binding'
local app_widgets = require 'widget.app'
local ambient_mod = require 'widget.ambient'
local mpv_actions = require 'host.mpv_actions'
local mpv_input = require 'host.mpv_input'
local mpv_primitives = require 'host.mpv_primitives'
local player_context = require 'widget.player_context'

local Constraints = constraints_mod.Constraints
local Rect = geometry.Rect
local Scheduler = scheduler_mod.Scheduler
---@alias PipelineOwner RenderOwner
local PipelineOwner = pipeline_owner.PipelineOwner
local AssCanvas = ass_canvas.AssCanvas
local AssTextLayout = ass_text_layout.AssTextLayout
local WidgetsBinding = binding_mod.WidgetsBinding
local WidgetsApp = app_widgets.WidgetsApp
local ThemeData = ambient_mod.ThemeData
local DisplaySnapshot = ambient_mod.DisplaySnapshot
local MpInput = mpv_input.MpInput
local MpFrameClock = mpv_primitives.MpFrameClock
local AssPresenter = mpv_primitives.AssPresenter
local PlayerScope = player_context.PlayerScope
local Navigator = require('widget.navigation').Navigator

local M = {}

---@class Display
---@field width number
---@field height number
---@field initialized boolean

--== app ===================================================================

--- Wires a render tree to the scheduler, the ASS canvas, the overlay and input.
---@class App : std.object
---@field display Display
---@field clock MpFrameClock
---@field scheduler Scheduler
---@field owner PipelineOwner
---@field widgets_binding WidgetsBinding
---@field binding WidgetTree
---@field root_widget Widget
---@field display_snapshot DisplaySnapshot
---@field theme ThemeData
---@field actions HostActions
---@field canvas AssCanvas
---@field presenter AssPresenter
---@field input MpInput
---@field player_store PlayerStore?
---@field player_context MpPlayerContext?
---@field _shutdown boolean
---@field _property_callbacks fun(name: string, value: any)[]
---@field _render_callback fun(dt: number, time: number)
---@field _shutdown_callback fun()
---@overload fun(root_widget: Widget, options: { z: number?, delay: number?, player_store: PlayerStore?, player_context: MpPlayerContext?, theme: ThemeData?, actions: HostActions?, default_text_style: TextStyle? }?): self
local App = std.class.new('App', {})

function App:__init(root_widget, options)
    options = options or {}
    self.root_widget = root_widget
    self.player_store = options.player_store
    self.player_context = options.player_context
    self.theme = options.theme or ThemeData()
    self.actions = options.actions or mpv_actions.default()
    self.default_text_style = options.default_text_style
    self._shutdown = false
    self._property_callbacks = {}
    ---@type Display
    self.display = { width = 1280, height = 720, initialized = false }
    self.display_snapshot = DisplaySnapshot({ width = 0, height = 0, initialized = false })
    self.clock = MpFrameClock(options.delay)
    self.scheduler = Scheduler(self.clock)
    self.canvas = AssCanvas()
    self.widgets_binding = WidgetsBinding.ensure_initialized()
    self.owner = self.widgets_binding:create_pipeline_owner()
    self.presenter = AssPresenter(options.z)

    self.owner.on_dirty = function()
        self.scheduler:schedule_frame()
    end
    self._render_callback = function()
        self:render()
    end
    self.scheduler:add_persistent(self._render_callback)

    -- the engine stand-in: `RenderText` falls back to this measurer
    text_layout.set_default(AssTextLayout())

    self.binding = self.widgets_binding:attach(
        self:_wrap_root(self.root_widget), self.owner, self.scheduler)
    self.binding.on_dirty = function()
        self.scheduler:schedule_frame()
    end

    self:_observe()
    self:_update_display()
    self:_update_delay()
    self.input = MpInput({
        owner = self.owner,
        get_viewport = function()
            return self:_input_viewport()
        end,
        notify_activity = function()
            self:notify_activity()
        end,
        request_frame = function()
            self:request_frame()
        end,
        get_can_pop = function()
            local state = self:_navigation_state()
            return state ~= nil and state:can_pop() or false
        end,
        handle_key = function(event)
            local state = self:_navigation_state()
            return state and state:handle_key(event) or false
        end,
    })
end

---@return NavigatorState?
function App:_navigation_state()
    local root = self.binding and self.binding.root_element
    local function visit(element)
        if element.widget and element.widget.__class == Navigator then
            return element.state
        end
        for _, child in ipairs(element:element_children()) do
            local found = visit(child)
            if found then
                return found
            end
        end
        return nil
    end
    return root and visit(root) or nil
end

---@return Rect
function App:_input_viewport()
    local width, height = self.display.width, self.display.height
    if width <= 0 or height <= 0 then
        width, height = mp.get_osd_size()
    end
    return Rect(0, 0, width, height)
end

---@param root_widget Widget
---@return Widget
function App:_wrap_root(root_widget)
    local content = root_widget
    if self.player_store == nil then
        content = root_widget
    else
        content = PlayerScope({
            store = self.player_store,
            child = root_widget,
        })
    end
    return WidgetsApp({
        theme = self.theme,
        display = self.display_snapshot,
        default_text_style = self.default_text_style,
        actions = self.actions,
        child = content,
    })
end

--- Force a redraw (e.g. after mutating the tree by hand).
function App:request_frame()
    if self._shutdown then
        return
    end
    self.scheduler:schedule_frame()
end

-- Notify application-level visibility policies without installing a full-size
-- pointer interceptor in the render tree.  A passive Main/background layer must
-- not swallow clicks destined for an Extension or WindowLayer control.
function App:notify_activity()
    if self._shutdown or not self.binding or not self.binding.root_element then
        return
    end
    local function visit(element)
        local state = element.state
        if state and type(state.notify_activity) == 'function' then
            state:notify_activity()
        end
        for _, child in ipairs(element:element_children()) do
            visit(child)
        end
    end
    visit(self.binding.root_element)
end

--- Swap the root widget (the define phase finished, or a script re-declared).
---@param root_widget Widget
function App:set_root_widget(root_widget)
    if self._shutdown then
        return
    end
    if self.input then
        self.input:cancel_capture()
    end
    self.root_widget = root_widget
    self.binding:set_root_widget(self:_wrap_root(root_widget))
    self:request_frame()
end

function App:_observe()
    local dimensions_callback = function()
        self:_update_display()
    end
    local display_fps_callback = function()
        self:_update_delay()
    end
    local estimated_fps_callback = function()
        self:_update_delay()
    end
    mp.observe_property('osd-dimensions', 'native', dimensions_callback)
    mp.observe_property('display-fps', 'native', display_fps_callback)
    mp.observe_property('estimated-display-fps', 'native', estimated_fps_callback)
    self._property_callbacks = {
        dimensions_callback,
        display_fps_callback,
        estimated_fps_callback,
    }
    self._shutdown_callback = function()
        self:shutdown()
    end
    mp.register_event('shutdown', self._shutdown_callback)
end

function App:shutdown()
    if self._shutdown then
        return false
    end
    self._shutdown = true
    local failure
    ---@param callback fun()
    local function release(callback)
        local ok, err = pcall(callback)
        if not ok then
            failure = failure or err
        end
    end
    for _, callback in ipairs(self._property_callbacks) do
        mp.unobserve_property(callback)
    end
    self._property_callbacks = {}
    if self._shutdown_callback and mp.unregister_event then
        mp.unregister_event(self._shutdown_callback)
    end
    if self.input then
        release(function()
            self.input:shutdown()
        end)
    end
    if self.owner then
        self.owner.on_dirty = nil
    end
    if self.scheduler then
        self.scheduler:remove_persistent(self._render_callback)
        self.scheduler:dispose()
    end
    if self.binding then
        release(function()
            self.binding:dispose()
        end)
    end
    if self.owner then
        release(function()
            self.owner:dispose()
        end)
    end
    if self.clock then
        release(function()
            self.clock:dispose()
        end)
    end
    if self.player_context then
        release(function()
            self.player_context:dispose()
        end)
    end
    if self.presenter then
        release(function()
            self.presenter:remove()
        end)
    end
    if failure then
        error(failure, 0)
    end
    return true
end

function App:_update_display()
    if self._shutdown then
        return
    end
    local width, height = mp.get_osd_size()
    if width <= 0 or height <= 0 then
        return
    end
    self.display.width, self.display.height = width, height
    self.display.initialized = true
    if self.display_snapshot.width ~= width
        or self.display_snapshot.height ~= height
        or not self.display_snapshot.initialized then
        self.display_snapshot = DisplaySnapshot({
            width = width,
            height = height,
            initialized = true,
        })
        if self.binding then
            self.binding:set_root_widget(self:_wrap_root(self.root_widget))
        end
    end
    -- The root gets tight constraints (Flutter's `RenderView` forces the
    -- application's child to exactly fill the viewport), which is what makes
    -- the doc's Example 1/2 fill the screen.
    self.owner:set_viewport(Constraints.tight(width, height))
    if self.input then
        self:request_frame()
    end
end

function App:_update_delay()
    if self._shutdown then
        return
    end
    local fps = mp.get_property_number('estimated-display-fps')
        or mp.get_property_number('display-fps')
    if fps and fps > 0 then
        self.clock:set_delay(1 / fps)
    end
end

function App:render()
    if self._shutdown or not self.display.initialized then
        return
    end
    self.binding:flush_build()
    self.owner:layout()
    self.input:update_regions()
    if not self.owner:needs_paint() then
        return
    end
    self.canvas:reset()
    self.owner:paint(self.canvas)
    self.presenter:present(self.canvas, self.display.width, self.display.height)
end

--- Build a root widget and start rendering it.
---@param build fun(): Widget
---@param options { z: number?, delay: number?, player_store: PlayerStore?, player_context: MpPlayerContext? }?
---@return App
function M.start(build, options)
    local app = App(build(), options)
    app:request_frame()
    return app
end

M.App = App
M.MpFrameClock = MpFrameClock
M.AssPresenter = AssPresenter

return M
