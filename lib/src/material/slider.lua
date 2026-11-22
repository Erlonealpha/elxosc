-- Public controlled numeric Slider; media behavior belongs to Timeline.
---@namespace elxosc
---@using elxosc
---@using elxosc.material

local std = require 'elxlibs.std'
local dataclass = require 'elxlibs.dataclass'
local widget_mod = require 'src.widgets.framework'
local slider_mod = require 'src.render.slider'

local LeafRenderObjectWidget = widget_mod.LeafRenderObjectWidget
local RenderSlider = slider_mod.RenderSlider
local Color = require('src.foundation.color').Color

---@class material._SliderOptions : _SliderInputOptions
---@field active_color Color?
---@field inactive_color Color?
---@field secondary_active_color Color?
---@field thumb_color Color?
---@field disabled_active_color Color?
---@field disabled_inactive_color Color?
---@field disabled_thumb_color Color?
---@field overlay_color Color?
---@field height number? logical layout height; default 48
---@field track_height number? default 4
---@field track_inset number? horizontal padding; default 20
---@field thumb_radius number? default 10
---@field overlay_radius number? default 20

---@param options _SliderOptions?
---@return _RenderSliderOptions
local function normalize(options)
    local config = {}
    for name, value in pairs(options or {}) do
        config[name] = value
    end
    local active = config.active_color or Color.rgba255(70, 150, 240)
    local defaults = {
        active_color = active,
        inactive_color = Color.rgba255(255, 255, 255, 60),
        secondary_active_color = Color.rgba255(70, 150, 240, 102),
        thumb_color = active,
        disabled_active_color = Color.rgba255(255, 255, 255, 80),
        disabled_inactive_color = Color.rgba255(255, 255, 255, 30),
        disabled_thumb_color = Color.rgba255(255, 255, 255, 100),
        overlay_color = Color.rgba255(70, 150, 240, 38),
        height = 48, track_height = 4, track_inset = 20,
        thumb_radius = 10, overlay_radius = 20,
    }
    if dataclass.isinstance(active, Color) then
        defaults.secondary_active_color = active:with_alpha(0.4)
        defaults.overlay_color = active:with_alpha(0.15)
    end
    for name, value in pairs(defaults) do
        if config[name] == nil then
            config[name] = value
        end
    end
    return slider_mod.normalize(config --[[@as _RenderSliderOptions]])
end

---@class material.Slider : LeafRenderObjectWidget, _RenderSliderOptions
---@overload fun(options?: _SliderOptions): self
local Slider = std.class.new('Slider', LeafRenderObjectWidget)

function Slider:__init(options)
    local config = normalize(options)
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

---@class mod.src.material.slider
local M = { Slider = Slider, normalize = normalize }

return M
