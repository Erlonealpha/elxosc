-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- Render primitives; colliding helpers receive explicit public aliases.
local exports = require 'export'.new()

local export = exports.export
local get = exports.get

export('render', require 'src.render.align', true)
export('render', require 'src.render.constrained_box', true)
export('render', require 'src.render.custom_paint', true)
export('render', require 'src.render.decorated_box', true)
export('render', require 'src.render.fitted_box', true)
export('render', require 'src.render.flex', true)
export('render', require 'src.render.gesture', true)
export('render', require 'src.render.layout_scale_box', true)
export('render', require 'src.render.offset_box', true)
export('render', require 'src.render.offstage', true)
export('render', require 'src.render.opacity', true)
export('render', require 'src.render.overflow_box', true)
export('render', require 'src.render.padding', true)
export('render', require 'src.render.painting_context', true)
export('render', require 'src.render.pipeline_owner', true)
export('render', require 'src.render.progress_indicator', true).hide('normalize')
export('render', require 'src.render.region_snapshot', true)
export('render', require 'src.render.render_object', true)
export('render', require 'src.render.render_owner', true)
export('render', require 'src.render.renderer_binding', true)
export('render', require 'src.render.sized_box', true)
export('render', require 'src.render.slider', true).hide('normalize')
export('render', require 'src.render.stack', true)
export('render', require 'src.render.text', true)
export('render', require 'src.render.transform_box', true)

export('render', {
    normalize_slider = require 'src.render.slider'.normalize,
    normalize_progress_indicator = require 'src.render.progress_indicator'.normalize,
}, true)

---@class elxosc.render :
--- elxosc.src.render.align,
--- elxosc.src.render.constrained_box,
--- elxosc.src.render.custom_paint,
--- elxosc.src.render.decorated_box,
--- elxosc.src.render.fitted_box,
--- elxosc.src.render.flex,
--- elxosc.src.render.gesture,
--- elxosc.src.render.layout_scale_box,
--- elxosc.src.render.offset_box,
--- elxosc.src.render.offstage,
--- elxosc.src.render.opacity,
--- elxosc.src.render.overflow_box,
--- elxosc.src.render.padding,
--- elxosc.src.render.painting_context,
--- elxosc.src.render.pipeline_owner,
--- elxosc.src.render.region_snapshot,
--- elxosc.src.render.render_object,
--- elxosc.src.render.render_owner,
--- elxosc.src.render.renderer_binding,
--- elxosc.src.render.sized_box,
--- elxosc.src.render.stack,
--- elxosc.src.render.text,
--- elxosc.src.render.transform_box
---@field RenderSlider RenderSlider
---@field RenderLinearProgressIndicator RenderLinearProgressIndicator
---@field normalize_slider fun(options: _RenderSliderOptions): _RenderSliderOptions
---@field normalize_progress_indicator fun(options: _RenderLinearProgressIndicatorOptions): _RenderLinearProgressIndicatorOptions
local M = get('render')

return M
