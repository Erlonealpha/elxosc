-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

---@class elxosc.render
local M = {}

M.align = require 'src.render.align'
M.constrained_box = require 'src.render.constrained_box'
M.custom_paint = require 'src.render.custom_paint'
M.decorated_box = require 'src.render.decorated_box'
M.fitted_box = require 'src.render.fitted_box'
M.flex = require 'src.render.flex'
M.gesture = require 'src.render.gesture'
M.layout_scale_box = require 'src.render.layout_scale_box'
M.offset_box = require 'src.render.offset_box'
M.offstage = require 'src.render.offstage'
M.opacity = require 'src.render.opacity'
M.overflow_box = require 'src.render.overflow_box'
M.padding = require 'src.render.padding'
M.painting_context = require 'src.render.painting_context'
M.pipeline_owner = require 'src.render.pipeline_owner'
M.progress_indicator = require 'src.render.progress_indicator'
M.region_snapshot = require 'src.render.region_snapshot'
M.render_object = require 'src.render.render_object'
M.render_owner = require 'src.render.render_owner'
M.renderer_binding = require 'src.render.renderer_binding'
M.sized_box = require 'src.render.sized_box'
M.slider = require 'src.render.slider'
M.stack = require 'src.render.stack'
M.text = require 'src.render.text'
M.timeline = require 'src.render.timeline'
M.transform_box = require 'src.render.transform_box'

M.RenderAlign = M.align.RenderAlign
M.RenderConstrainedBox = M.constrained_box.RenderConstrainedBox
M.RenderLimitedBox = M.constrained_box.RenderLimitedBox
M.RenderCustomPaint = M.custom_paint.RenderCustomPaint
M.Decoration = M.decorated_box.Decoration
M.RenderDecoratedBox = M.decorated_box.RenderDecoratedBox
M.RenderFittedBox = M.fitted_box.RenderFittedBox
M.RenderFlex = M.flex.RenderFlex
M.RenderGesture = M.gesture.RenderGesture
M.RenderLayoutScaleBox = M.layout_scale_box.RenderLayoutScaleBox
M.RenderOffsetBox = M.offset_box.RenderOffsetBox
M.RenderOffstage = M.offstage.RenderOffstage
M.RenderOpacity = M.opacity.RenderOpacity
M.RenderUnconstrainedBox = M.overflow_box.RenderUnconstrainedBox
M.RenderOverflowBox = M.overflow_box.RenderOverflowBox
M.RenderPadding = M.padding.RenderPadding
M.PaintingContext = M.painting_context.PaintingContext
M.PipelineOwner = M.pipeline_owner.PipelineOwner
M.RenderOwner = M.pipeline_owner.RenderOwner
M.RenderLinearProgressIndicator = M.progress_indicator.RenderLinearProgressIndicator
M.RegionSnapshot = M.region_snapshot.RegionSnapshot
M.RenderObject = M.render_object.RenderObject
M.RenderOwner = M.render_owner.RenderOwner
M.RendererBinding = M.renderer_binding.RendererBinding
M.RenderSizedBox = M.sized_box.RenderSizedBox
M.RenderSlider = M.slider.RenderSlider
M.RenderStack = M.stack.RenderStack
M.RenderText = M.text.RenderText
M.RenderTimeline = M.timeline.RenderTimeline
M.RenderTransformBox = M.transform_box.RenderTransformBox

M.normalize_slider = M.slider.normalize
M.normalize_progress_indicator = M.progress_indicator.normalize

return M
