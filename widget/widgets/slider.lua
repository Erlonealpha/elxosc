-- Public controlled numeric Slider; media behavior belongs to Timeline.
local std = require 'elxlibs.std'
local widget_mod = require 'widget.widget'
local slider_mod = require 'render.slider'

local LeafRenderObjectWidget = widget_mod.LeafRenderObjectWidget
local RenderSlider = slider_mod.RenderSlider

---@class Slider : LeafRenderObjectWidget, _SliderOptions
---@overload fun(options?: _SliderOptions): self
local Slider = std.class.new('Slider', LeafRenderObjectWidget)

function Slider:__init(options)
    local config = slider_mod.normalize(options)
    for name, value in pairs(config) do
        self[name] = value
    end
end

function Slider:create_render_object()
    return RenderSlider(self)
end

---@param render_object RenderSlider
function Slider:update_render_object(render_object)
    render_object:configure(self)
end

---@class elxosc.widget.widgets.slider
local M = { Slider = Slider }

return M
