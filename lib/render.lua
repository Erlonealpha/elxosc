-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

---@class elxosc.render
local M = {}

local align = require 'src.render.align'
local constrained_box = require 'src.render.constrained_box'
local custom_paint = require 'src.render.custom_paint'
local decorated_box = require 'src.render.decorated_box'
local fitted_box = require 'src.render.fitted_box'
local flex = require 'src.render.flex'
local gesture = require 'src.render.gesture'
local layout_scale_box = require 'src.render.layout_scale_box'
local offset_box = require 'src.render.offset_box'
local offstage = require 'src.render.offstage'
local opacity = require 'src.render.opacity'
local overflow_box = require 'src.render.overflow_box'
local padding = require 'src.render.padding'
local painting_context = require 'src.render.painting_context'
local pipeline_owner = require 'src.render.pipeline_owner'
local progress_indicator = require 'src.render.progress_indicator'
local region_snapshot = require 'src.render.region_snapshot'
local render_object = require 'src.render.render_object'
local render_owner = require 'src.render.render_owner'
local renderer_binding = require 'src.render.renderer_binding'
local sized_box = require 'src.render.sized_box'
local slider = require 'src.render.slider'
local stack = require 'src.render.stack'
local text = require 'src.render.text'
local transform_box = require 'src.render.transform_box'

M.RenderAlign = align.RenderAlign
M.RenderConstrainedBox = constrained_box.RenderConstrainedBox
M.RenderLimitedBox = constrained_box.RenderLimitedBox
M.RenderCustomPaint = custom_paint.RenderCustomPaint
M.Decoration = decorated_box.Decoration
M.RenderDecoratedBox = decorated_box.RenderDecoratedBox
M.RenderFittedBox = fitted_box.RenderFittedBox
M.RenderFlex = flex.RenderFlex
M.RenderGesture = gesture.RenderGesture
M.RenderLayoutScaleBox = layout_scale_box.RenderLayoutScaleBox
M.RenderOffsetBox = offset_box.RenderOffsetBox
M.RenderOffstage = offstage.RenderOffstage
M.RenderOpacity = opacity.RenderOpacity
M.RenderUnconstrainedBox = overflow_box.RenderUnconstrainedBox
M.RenderOverflowBox = overflow_box.RenderOverflowBox
M.RenderPadding = padding.RenderPadding
M.PaintingContext = painting_context.PaintingContext
M.PipelineOwner = pipeline_owner.PipelineOwner
M.RenderLinearProgressIndicator = progress_indicator.RenderLinearProgressIndicator
M.RegionSnapshot = region_snapshot.RegionSnapshot
M.RenderObject = render_object.RenderObject
M.RenderOwner = render_owner.RenderOwner
M.RendererBinding = renderer_binding.RendererBinding
M.RenderSizedBox = sized_box.RenderSizedBox
M.RenderSlider = slider.RenderSlider
M.RenderStack = stack.RenderStack
M.RenderText = text.RenderText
M.RenderTransformBox = transform_box.RenderTransformBox

M.normalize_slider = slider.normalize
M.normalize_progress_indicator = progress_indicator.normalize

return M
