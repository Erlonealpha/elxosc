-- LinearProgressIndicator reports progress; it never accepts pointer input.
local std = require 'elxlibs.std'
local widget_mod = require 'widget.widget'
local State = require('widget.state').State
local render_mod = require 'render.progress_indicator'
local RenderLinearProgressIndicator = render_mod.RenderLinearProgressIndicator
local LeafRenderObjectWidget = widget_mod.LeafRenderObjectWidget
local StatefulWidget = widget_mod.StatefulWidget

---@class LinearProgressIndicator : StatefulWidget, _LinearProgressIndicatorOptions
---@overload fun(options?: _LinearProgressIndicatorOptions): self
local LinearProgressIndicator = std.class.new('LinearProgressIndicator', StatefulWidget)

function LinearProgressIndicator:__init(options)
    local config = render_mod.normalize(options)
    for name, value in pairs(config) do
        self[name] = value
    end
end

---@class _ProgressIndicatorOptions : _LinearProgressIndicatorOptions
---@field phase number

---@class _ProgressIndicator : LeafRenderObjectWidget, _ProgressIndicatorOptions
---@overload fun(options: _ProgressIndicatorOptions): self
local ProgressIndicator = std.class.new('_ProgressIndicator', LeafRenderObjectWidget)

function ProgressIndicator:__init(options)
    for name, value in pairs(options) do
        self[name] = value
    end
end

function ProgressIndicator:create_render_object()
    local render = RenderLinearProgressIndicator(self)
    render:set_phase(self.phase)
    return render
end

---@param render RenderLinearProgressIndicator
function ProgressIndicator:update_render_object(render)
    render:configure(self)
    render:set_phase(self.phase)
end

---@class LinearProgressIndicatorState : State
---@field _ticker Ticker?
---@field _phase number
---@overload fun(): self
local LinearProgressIndicatorState = std.class.new('LinearProgressIndicatorState', State)

function LinearProgressIndicatorState:init_state()
    self._phase = 0
    self:_sync_ticker()
end

function LinearProgressIndicatorState:_sync_ticker()
    local widget = self.widget --[[@as LinearProgressIndicator]]
    if widget.value == nil then
        if not self._ticker then
            self._ticker = self:create_ticker(function(dt)
                self._phase = (self._phase + dt / 1.8) % 1
                local render = self.context and self.context:first_render_object()
                if render then
                    local indicator = render --[[@as RenderLinearProgressIndicator]]
                    indicator:set_phase(self._phase)
                end
            end)
        end
        self._ticker:start()
    elseif self._ticker then
        self._ticker:stop()
    end
end

function LinearProgressIndicatorState:did_update_widget(_old_widget)
    self:_sync_ticker()
end

function LinearProgressIndicatorState:dispose()
    if self._ticker then
        self._ticker:stop()
    end
end

function LinearProgressIndicatorState:build()
    local widget = self.widget --[[@as LinearProgressIndicator]]
    return ProgressIndicator({ value = widget.value, color = widget.color,
        background_color = widget.background_color, min_height = widget.min_height,
        border_radius = widget.border_radius, phase = self._phase })
end

function LinearProgressIndicator:create_state()
    return LinearProgressIndicatorState()
end

---@class elxosc.widget.widgets.progress_indicator
local M = { LinearProgressIndicator = LinearProgressIndicator }

return M
