-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- mpv host wiring: frame clock, `osd-overlay` presenter and the frame loop.
--
-- Mirrors uosc's proven main loop (`lib/utils.lua`: `render` + `request_render`):
--   * frames are coalesced and rate limited to the display refresh rate;
--   * the overlay is only pushed when its data or resolution changed;
--   * `mp.get_osd_size()` is the logical (1:1) coordinate space, so an
--     `ass-events` overlay with matching `res_x`/`res_y` maps pixels 1:1.

local mp = require 'mp'

local std = require 'elxlibs.std'
local constraints_mod = require 'layout.constraints'
local frame_clock = require 'scheduler.frame_clock'
local scheduler_mod = require 'scheduler.scheduler'
local render_owner = require 'render.render_owner'
local ass_canvas = require 'backends.ass_canvas'
local mpv_input = require 'host.mpv_input'

local Constraints = constraints_mod.Constraints
local FrameClock = frame_clock.FrameClock
local Scheduler = scheduler_mod.Scheduler
local RenderOwner = render_owner.RenderOwner
local AssCanvas = ass_canvas.AssCanvas
local MpInput = mpv_input.MpInput

local math = math

---@class elxhost
local M = {}

---@class Display
---@field width number
---@field height number
---@field initialized boolean

--== frame clock ===========================================================

--- Drives frames from `mp.add_timeout`, one timer per requested frame, with
--- the same rate limiting uosc applies via `render_delay`.
---@class MpFrameClock : FrameClock
---@field delay number minimum seconds between frames
---@overload fun(delay: number?): MpFrameClock
local MpFrameClock = std.class.new('MpFrameClock', { FrameClock })

function MpFrameClock:__init(delay)
    self.delay = delay or (1 / 60)
    self._timer = nil
    self._last_frame = nil
end

function MpFrameClock:now()
    return mp.get_time()
end

---@param delay number
function MpFrameClock:set_delay(delay)
    self.delay = delay
end

function MpFrameClock:request_frame()
    if self._timer then
        return
    end
    local last = self._last_frame
    local since = last and (mp.get_time() - last) or math.huge
    self._timer = mp.add_timeout(math.max(0, self.delay - since), function()
        self._timer = nil
        self._last_frame = mp.get_time()
        self:_emit()
    end)
end

--== presenter =============================================================

--- Pushes the canvas as an `ass-events` overlay, skipping identical frames.
---@class AssPresenter : std.object
---@field overlay table
---@overload fun(z: number?): AssPresenter
local AssPresenter = std.class.new('AssPresenter')

function AssPresenter:__init(z)
    self.overlay = mp.create_osd_overlay('ass-events')
    self.overlay.z = z or 2000
    self._last_data = nil
    self._last_w, self._last_h = -1, -1
end

---@param canvas AssCanvas
---@param width number
---@param height number
function AssPresenter:present(canvas, width, height)
    local res_x, res_y = math.floor(width), math.floor(height)
    local data = canvas:text()
    if data == self._last_data and res_x == self._last_w and res_y == self._last_h then
        return
    end
    self._last_data = data
    self._last_w, self._last_h = res_x, res_y
    self.overlay.res_x, self.overlay.res_y = res_x, res_y
    self.overlay.data = data
    self.overlay:update()
end

function AssPresenter:remove()
    self.overlay:remove()
end

--== app ===================================================================

--- Wires a render tree to the scheduler, the ASS canvas, the overlay and input.
---@class App : std.object
---@field display Display
---@field clock MpFrameClock
---@field scheduler Scheduler
---@field owner RenderOwner
---@field canvas AssCanvas
---@field presenter AssPresenter
---@field input MpInput
---@overload fun(root: RenderObject, options: { z: number?, delay: number? }?): App
local App = std.class.new('App')

function App:__init(root, options)
    options = options or {}
    ---@type Display
    self.display = { width = 1280, height = 720, initialized = false }
    self.clock = MpFrameClock(options.delay)
    self.scheduler = Scheduler(self.clock)
    self.owner = RenderOwner(root)
    self.canvas = AssCanvas()
    self.presenter = AssPresenter(options.z)

    self.owner.on_dirty = function()
        self.scheduler:schedule_frame()
    end
    self.scheduler:add_persistent(function()
        self:render()
    end)

    self:_observe()
    self:_update_display()
    self:_update_delay()
    self.input = MpInput(self)
end

--- Force a redraw (e.g. after mutating the tree by hand).
function App:request_frame()
    self.scheduler:schedule_frame()
end

function App:_observe()
    mp.observe_property('osd-dimensions', 'native', function()
        self:_update_display()
    end)
    mp.observe_property('display-fps', 'native', function()
        self:_update_delay()
    end)
    mp.observe_property('estimated-display-fps', 'native', function()
        self:_update_delay()
    end)
    mp.register_event('shutdown', function()
        self.presenter:remove()
    end)
end

function App:_update_display()
    local width, height = mp.get_osd_size()
    if width <= 0 or height <= 0 then
        return
    end
    self.display.width, self.display.height = width, height
    self.display.initialized = true
    self.owner:set_viewport(Constraints.loose(width, height))
end

function App:_update_delay()
    local fps = mp.get_property_number('estimated-display-fps')
        or mp.get_property_number('display-fps')
    if fps and fps > 0 then
        self.clock:set_delay(1 / fps)
    end
end

function App:render()
    if not self.display.initialized then
        return
    end
    self.owner:layout()
    self.canvas:reset()
    self.owner:paint(self.canvas)
    self.presenter:present(self.canvas, self.display.width, self.display.height)
end

--- Build a root render object and start rendering it.
---@param build fun(): RenderObject
---@param options { z: number?, delay: number? }?
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
