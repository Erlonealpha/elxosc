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

---@namespace elxosc
---@using elxosc
---@using elxosc.host

local mp = require 'mp'

local std = require 'elxlibs.std'
local constraints_mod = require 'src.layout.constraints'
local geometry = require 'src.foundation.geometry'
local scheduler_mod = require 'src.scheduler.scheduler'
local pipeline_owner = require 'src.render.pipeline_owner'
local ass_canvas = require 'src.backends.ass_canvas'
local ass_text_layout = require 'src.backends.ass_text_layout'
local text_layout = require 'src.text.text_layout'
local binding_mod = require 'src.widgets.widgets_binding'
local app_widgets = require 'src.widgets.app'
local ambient_mod = require 'src.widgets.ambient'
local mpv_input = require 'host.mpv_input'
local mpv_primitives = require 'host.mpv_primitives'
local ass_measure_mod = require 'host.ass_measure'

local Constraints = constraints_mod.Constraints
local Rect = geometry.Rect
local Scheduler = scheduler_mod.Scheduler
local PipelineOwner = pipeline_owner.PipelineOwner
local AssCanvas = ass_canvas.AssCanvas
local AssTextLayout = ass_text_layout.AssTextLayout
local WidgetsBinding = binding_mod.WidgetsBinding
local WidgetsApp = app_widgets.WidgetsApp
local DisplaySnapshot = ambient_mod.DisplaySnapshot
local TextLayoutScope = ambient_mod.TextLayoutScope
local AssMeasure = ass_measure_mod.AssMeasure
local MpInput = mpv_input.MpInput
local MpFrameClock = mpv_primitives.MpFrameClock
local AssPresenter = mpv_primitives.AssPresenter
local Navigator = require('src.widgets.navigation').Navigator

---@class mod.host.mpv_app
local M = {}

---@class host.Display
---@field width number
---@field height number
---@field initialized boolean

---@class host._AppOptions
---@field z number?
---@field delay number?
---@field default_text_style TextStyle?
---@field root_wrapper (fun(root: Widget, display: DisplaySnapshot): Widget)?
---@field on_activity (fun(app: App, x: number?, y: number?, viewport: Rect?))?
---@field on_dispose fun()?

--== app ===================================================================

--- Wires a render tree to the scheduler, the ASS canvas, the overlay and input.
---@class host.App : std.object
---@field display Display
---@field clock MpFrameClock
---@field scheduler Scheduler
---@field owner RenderOwner
---@field widgets_binding WidgetsBinding
---@field binding WidgetTree
---@field root_widget Widget
---@field display_snapshot DisplaySnapshot
---@field canvas AssCanvas
---@field presenter AssPresenter
---@field input MpInput
---@field _shutdown boolean
---@field _property_callbacks fun(name: string, value: any)[]
---@field _render_callback fun(dt: number, time: number)
---@field _shutdown_callback fun()
---@field _root_wrapper (fun(root: Widget, display: DisplaySnapshot): Widget)?
---@field _activity_callback (fun(app: App, x: number?, y: number?, viewport: Rect?))?
---@field _dispose_callback fun()?
---@field text_layout AssTextLayout
---@field text_layout_generation integer
---@field private _text_sessions AssMeasure[]
---@field private _text_font string?
---@field private _keyboard_cache _TreeQueryCache?
---@field default_text_style TextStyle?
---@overload fun(root_widget: Widget, options?: _AppOptions): self
local App = std.class.new('App')

function App:__init(root_widget, options)
    self._shutdown = false
    self._property_callbacks = {}
    self._text_sessions = {}
    self.text_layout_generation = 0
    self._dispose_callback = options and options.on_dispose
    local ok, err = pcall(self._initialize, self, root_widget, options)
    if not ok then
        pcall(self.shutdown, self)
        error(err, 0)
    end
end

function App:_initialize(root_widget, options)
    options = options or {}
    self.root_widget = root_widget
    self._root_wrapper = options.root_wrapper
    self._activity_callback = options.on_activity
    self._dispose_callback = options.on_dispose
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

    -- Only an offline measurer may live in the module default. Each attached
    -- tree receives its own service, including custom player root wrappers.
    if text_layout.get_default() == nil then
        text_layout.set_default(AssTextLayout())
    end
    self.text_layout = AssTextLayout()

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
        notify_activity = function(x, y, viewport)
            self:notify_activity(x, y, viewport)
        end,
        request_frame = function()
            self:request_frame()
        end,
        get_can_pop = function()
            return self:_can_handle_key()
        end,
        handle_key = function(event)
            return self:_handle_key(event)
        end,
    })
end

--- Cache traversal order, while querying live State capabilities every time.
---@return Element[]
function App:_keyboard_targets()
    local root = self.binding and self.binding.root_element
    local cache = self._keyboard_cache
    if cache == nil then
        cache = {}
        self._keyboard_cache = cache
        if self.binding then
            self.binding.build_owner:_register_tree_cache(cache)
        end
    end
    if cache.value and root == cache.value.root then
        return cache.value.elements
    end
    local elements = {}
    local navigation
    local function visit(element)
        if navigation == nil and element.widget and element.widget.__class == Navigator then
            navigation = element.state
        end
        local children = element:element_children()
        for index = #children, 1, -1 do
            visit(children[index])
        end
        if element.state then
            elements[#elements + 1] = element
        end
    end
    if root then
        visit(root)
    end
    -- Navigator fallback uses forward preorder, unlike key target priority.
    local function first_navigator(element)
        if element.widget and element.widget.__class == Navigator then
            return element.state
        end
        for _, child in ipairs(element:element_children()) do
            local found = first_navigator(child)
            if found then
                return found
            end
        end
        return nil
    end
    cache.value = { root = root, elements = elements,
        navigator = navigation and root and first_navigator(root) or nil }
    return elements
end

---@return NavigatorState?
function App:_navigation_state()
    self:_keyboard_targets()
    return self._keyboard_cache and self._keyboard_cache.value and self._keyboard_cache.value.navigator or nil
end

---@param event KeyEvent
---@return boolean
function App:_handle_key(event)
    for _, element in ipairs(self:_keyboard_targets()) do
        local state = element.state
        if state and type(state.can_handle_key) == 'function'
            and state:can_handle_key(event)
            and type(state.handle_key) == 'function' then
            if state:handle_key(event) == true then
                return true
            end
        end
    end
    local navigation = self:_navigation_state()
    return navigation ~= nil and navigation:handle_key(event) or false
end

---@return boolean
function App:_can_handle_key()
    for _, element in ipairs(self:_keyboard_targets()) do
        local state = element.state
        if state and type(state.can_handle_key) == 'function' and state:can_handle_key() then
            return true
        end
    end
    local navigation = self:_navigation_state()
    return navigation ~= nil and navigation:can_pop() or false
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
    local content
    if self._root_wrapper then
        content = self._root_wrapper(root_widget, self.display_snapshot)
    else
        content = WidgetsApp({
            display = self.display_snapshot,
            default_text_style = self.default_text_style,
            child = root_widget,
        })
    end
    return TextLayoutScope({
        layout = self.text_layout,
        generation = self.text_layout_generation,
        child = content,
    })
end

--- Retries pending removals without dropping ownership of a failed ID.
---@return string?
function App:_dispose_text_sessions()
    local pending = {}
    local failure
    for _, session in ipairs(self._text_sessions) do
        local ok, _removed, err = pcall(session.dispose, session)
        if not ok or err ~= nil then
            pending[#pending + 1] = session
            failure = failure or tostring(ok and err or _removed)
        end
    end
    self._text_sessions = pending
    return failure
end

--- Explicit recovery for a failed native session; no per-frame retries.
function App:refresh_text_layout()
    if self._shutdown then
        return
    end
    local cleanup_error = self:_dispose_text_sessions()
    local width, height = mp.get_osd_size()
    local family = mp.get_property_native('osd-font')
    self._text_font = type(family) == 'string' and family or nil
    self.canvas.default_font_family = self._text_font
    ---@type _AssTextLayoutOptions
    local options = { default_font_family = self._text_font }
    if width > 0 and height > 0 then
        if cleanup_error then
            -- A failed removal must not accumulate one hidden ID per resize.
            options.res_x = math.floor(width)
            options.res_y = math.floor(height)
            options.measure_ass = function()
                return nil, cleanup_error, 'error'
            end
        else
            local session = AssMeasure({ res_x = width, res_y = height })
            self._text_sessions[#self._text_sessions + 1] = session
            options.measure_ass = function(data)
                local raw, err, kind = session:measure(data)
                return raw --[[@as AssTextRawBounds?]], err, kind
            end
            options.res_x = session.res_x
            options.res_y = session.res_y
        end
    end
    self.text_layout = AssTextLayout(options)
    self.text_layout_generation = self.text_layout_generation + 1
    if self.binding then
        self.binding:set_root_widget(self:_wrap_root(self.root_widget))
        self:request_frame()
    end
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
function App:notify_activity(x, y, viewport)
    if self._shutdown or not self.binding or not self.binding.root_element then
        return
    end
    if self._activity_callback then
        self._activity_callback(self, x, y, viewport)
    end
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
    local font_callback = function()
        local family = mp.get_property_native('osd-font')
        if family ~= self._text_font then
            self:refresh_text_layout()
        end
    end
    local names = { 'osd-dimensions', 'display-fps', 'estimated-display-fps', 'osd-font' }
    local callbacks = { dimensions_callback, display_fps_callback, estimated_fps_callback, font_callback }
    for index, callback in ipairs(callbacks) do
        self._property_callbacks[#self._property_callbacks + 1] = callback
        mp.observe_property(assert(names[index]), 'native', callback)
    end
    self._shutdown_callback = function()
        self:shutdown()
    end
    mp.register_event('shutdown', self._shutdown_callback)
end

function App:shutdown()
    if self._shutdown then
        local err = self:_dispose_text_sessions()
        if err then
            error(err, 0)
        end
        return false
    end
    self._shutdown = true
    self._keyboard_cache = nil
    local failure
    ---@param callback fun()
    local function release(callback)
        local ok, err = pcall(callback)
        if not ok then
            failure = failure or err
        end
    end
    for _, callback in ipairs(self._property_callbacks) do
        release(function()
            mp.unobserve_property(callback)
        end)
    end
    self._property_callbacks = {}
    if self._shutdown_callback and mp.unregister_event then
        release(function()
            mp.unregister_event(self._shutdown_callback)
        end)
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
        release(function()
            self.scheduler:remove_persistent(self._render_callback)
            self.scheduler:dispose()
        end)
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
    if self._dispose_callback then
        release(self._dispose_callback)
        self._dispose_callback = nil
    end
    if self.presenter then
        release(function()
            self.presenter:remove()
        end)
    end
    release(function()
        local err = self:_dispose_text_sessions()
        self.text_layout = AssTextLayout()
        if err then
            error(err, 0)
        end
    end)
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
        if self.display.initialized then
            self.display.initialized = false
            self.display_snapshot = DisplaySnapshot({ width = 0, height = 0, initialized = false })
            self:refresh_text_layout()
        end
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
        self:refresh_text_layout()
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
---@param options _AppOptions?
---@return App
function M.start(build, options)
    local ok, root = pcall(build)
    if not ok then
        if options and options.on_dispose then
            pcall(options.on_dispose)
        end
        error(root, 0)
    end
    local app = App(root, options)
    local started, err = pcall(app.request_frame, app)
    if not started then
        pcall(app.shutdown, app)
        error(err, 0)
    end
    return app
end

M.App = App
M.MpFrameClock = MpFrameClock
M.AssPresenter = AssPresenter

return M
