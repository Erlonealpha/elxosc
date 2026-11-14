-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- Render primitives; colliding helpers receive explicit public aliases.
---@namespace elxosc
---@using elxosc

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

---@class mod.render :
--- mod.src.render.align,
--- mod.src.render.constrained_box,
--- mod.src.render.custom_paint,
--- mod.src.render.decorated_box,
--- mod.src.render.fitted_box,
--- mod.src.render.flex,
--- mod.src.render.gesture,
--- mod.src.render.layout_scale_box,
--- mod.src.render.offset_box,
--- mod.src.render.offstage,
--- mod.src.render.opacity,
--- mod.src.render.overflow_box,
--- mod.src.render.padding,
--- mod.src.render.painting_context,
--- mod.src.render.pipeline_owner,
--- mod.src.render.region_snapshot,
--- mod.src.render.render_object,
--- mod.src.render.render_owner,
--- mod.src.render.renderer_binding,
--- mod.src.render.sized_box,
--- mod.src.render.stack,
--- mod.src.render.text,
--- mod.src.render.transform_box
---@field RenderSlider RenderSlider
---@field RenderLinearProgressIndicator RenderLinearProgressIndicator
---@field normalize_slider fun(options: _RenderSliderOptions): _RenderSliderOptions
---@field normalize_progress_indicator fun(options: _RenderLinearProgressIndicatorOptions): _RenderLinearProgressIndicatorOptions
local M = get('render')

return M
