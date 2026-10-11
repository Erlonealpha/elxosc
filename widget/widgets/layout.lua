-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- Layout widgets: the declarative front end for the `render/` boxes.
-- `Row`, `Column`, `Center`, `Expanded` and `Spacer` are plain functions that
-- return the corresponding widget. Imports here share the direct modules'
-- class identities so element reuse behaves the same through either entry point.

local padding_mod = require 'widget.widgets.padding'
local align_mod = require 'widget.widgets.align'
local sized_box_mod = require 'widget.widgets.sized_box'
local decorated_box_mod = require 'widget.widgets.decorated_box'
local flex_mod = require 'widget.widgets.flex'
local stack_mod = require 'widget.widgets.stack'
local constraints_mod = require 'widget.widgets.constraints'
local overflow_mod = require 'widget.widgets.overflow'
local container_mod = require 'widget.widgets.container'
local offset_box_mod = require 'widget.widgets.offset_box'

---@class elxwidgets_layout
---@field Padding Padding
---@field Align Align
---@field Center fun(child: Widget?, options?: _CenterOptions): Align
---@field SizedBox SizedBox
---@field DecoratedBox DecoratedBox
---@field Flexible Flexible
---@field Expanded fun(child: Widget?, options?: _ExpandedOptions): Flexible
---@field Spacer fun(options?: _ExpandedOptions): Flexible
---@field Flex Flex
---@field Row fun(options?: _FlexOptions): Flex
---@field Column fun(options?: _FlexOptions): Flex
---@field Stack Stack
---@field ConstrainedBox ConstrainedBox
---@field LimitedBox LimitedBox
---@field UnconstrainedBox UnconstrainedBox
---@field OverflowBox OverflowBox
---@field FittedBox FittedBox
---@field Container Container
---@field OffsetBox OffsetBox
local M = {}

M.Padding = padding_mod.Padding
M.Align = align_mod.Align
M.Center = align_mod.Center
M.SizedBox = sized_box_mod.SizedBox
M.DecoratedBox = decorated_box_mod.DecoratedBox
M.Flexible = flex_mod.Flexible
M.Expanded = flex_mod.Expanded
M.Spacer = flex_mod.Spacer
M.Flex = flex_mod.Flex
M.Row = flex_mod.Row
M.Column = flex_mod.Column
M.Stack = stack_mod.Stack
M.ConstrainedBox = constraints_mod.ConstrainedBox
M.LimitedBox = constraints_mod.LimitedBox
M.UnconstrainedBox = overflow_mod.UnconstrainedBox
M.OverflowBox = overflow_mod.OverflowBox
M.FittedBox = overflow_mod.FittedBox
M.Container = container_mod.Container
M.OffsetBox = offset_box_mod.OffsetBox

return M
