-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- Layout widgets: the declarative front end for the `render/` boxes.
--
-- `Row`, `Column`, `Center`, `Expanded` and `Spacer` are plain functions that
-- return the corresponding widget, matching Flutter's API without extra
-- classes (element reuse only ever sees the returned widget's class).

local std = require 'elxlibs.std'
local geometry = require 'foundation.geometry'
local padding_mod = require 'render.padding'
local align_mod = require 'render.align'
local sized_box_mod = require 'render.sized_box'
local decorated_box_mod = require 'render.decorated_box'
local flex_mod = require 'render.flex'
local stack_mod = require 'render.stack'
local constrained_box_mod = require 'render.constrained_box'
local overflow_box_mod = require 'render.overflow_box'
local fitted_box_mod = require 'render.fitted_box'
local widget_mod = require 'widget.widget'

local Offset = geometry.Offset
local EdgeInsets = geometry.EdgeInsets
local Constraints = require('layout.constraints').Constraints
local RenderPadding = padding_mod.RenderPadding
local RenderAlign = align_mod.RenderAlign
local RenderSizedBox = sized_box_mod.RenderSizedBox
local Decoration = decorated_box_mod.Decoration
local RenderDecoratedBox = decorated_box_mod.RenderDecoratedBox
local RenderFlex = flex_mod.RenderFlex
local RenderStack = stack_mod.RenderStack
local RenderConstrainedBox = constrained_box_mod.RenderConstrainedBox
local RenderLimitedBox = constrained_box_mod.RenderLimitedBox
local RenderUnconstrainedBox = overflow_box_mod.RenderUnconstrainedBox
local RenderOverflowBox = overflow_box_mod.RenderOverflowBox
local RenderFittedBox = fitted_box_mod.RenderFittedBox
local StatelessWidget = widget_mod.StatelessWidget
local ParentDataWidget = widget_mod.ParentDataWidget
local SingleChildRenderObjectWidget = widget_mod.SingleChildRenderObjectWidget
local MultiChildRenderObjectWidget = widget_mod.MultiChildRenderObjectWidget

---@class elxwidgets_layout
local M = {}

--== padding / align / size ===============================================

---@class Padding : SingleChildRenderObjectWidget
---@field padding EdgeInsets
---@overload fun(child: Widget?, options: { padding: EdgeInsets, key: any? }?): Padding
local Padding = std.class.new('Padding', { SingleChildRenderObjectWidget })

function Padding:__init(child, options)
    options = options or {}
    self.key = options.key
    self.id = options.id
    self.child = child
    self.padding = options.padding or EdgeInsets.zero()
end

function Padding:create_render_object()
    return RenderPadding(self.padding)
end

function Padding:update_render_object(render_object)
    render_object.padding = self.padding
    render_object:mark_needs_layout()
end

---@class Align : SingleChildRenderObjectWidget
---@field alignment Offset
---@overload fun(child: Widget?, options: { alignment: Offset?, width_factor: number?, height_factor: number?, key: any? }?): Align
local Align = std.class.new('Align', { SingleChildRenderObjectWidget })

function Align:__init(child, options)
    options = options or {}
    self.key = options.key
    self.id = options.id
    self.child = child
    self.alignment = options.alignment or Offset(0.5, 0.5)
    self.width_factor = options.width_factor
    self.height_factor = options.height_factor
end

function Align:create_render_object()
    return RenderAlign(self.alignment, nil, self.width_factor, self.height_factor)
end

function Align:update_render_object(render_object)
    render_object.alignment = self.alignment
    render_object.width_factor = self.width_factor
    render_object.height_factor = self.height_factor
    render_object:mark_needs_layout()
end

---@param child Widget?
---@param options { key: any?, width_factor: number?, height_factor: number? }?
---@return Align
local function Center(child, options)
    options = options or {}
    return Align(child, {
        key = options.key,
        alignment = Offset(0.5, 0.5),
        width_factor = options.width_factor,
        height_factor = options.height_factor,
    })
end

---@class SizedBox : SingleChildRenderObjectWidget
---@field width number?
---@field height number?
---@overload fun(options: { width: number?, height: number?, child: Widget?, key: any? }?): SizedBox
local SizedBox = std.class.new('SizedBox', { SingleChildRenderObjectWidget })

function SizedBox:__init(options)
    options = options or {}
    self.key = options.key
    self.id = options.id
    self.child = options.child
    self.width = options.width
    self.height = options.height
end

function SizedBox:create_render_object()
    return RenderSizedBox(self.width, self.height)
end

function SizedBox:update_render_object(render_object)
    render_object.width = self.width
    render_object.height = self.height
    render_object:mark_needs_layout()
end

--- Make the box as large as the parent allows (Flutter's `SizedBox.expand`).
---@param options { child: Widget?, key: any?, id: string? }?
---@return SizedBox
function SizedBox.expand(options)
    options = options or {}
    return SizedBox({
        key = options.key, id = options.id, child = options.child,
        width = math.huge, height = math.huge,
    })
end

--- Make the box as small as the parent allows (Flutter's `SizedBox.shrink`).
---@param options { child: Widget?, key: any?, id: string? }?
---@return SizedBox
function SizedBox.shrink(options)
    options = options or {}
    return SizedBox({
        key = options.key, id = options.id, child = options.child,
        width = 0, height = 0,
    })
end

---@param size Size
---@param options { child: Widget?, key: any?, id: string? }?
---@return SizedBox
function SizedBox.from_size(size, options)
    options = options or {}
    return SizedBox({
        key = options.key, id = options.id, child = options.child,
        width = size.width, height = size.height,
    })
end

---@class DecoratedBox : SingleChildRenderObjectWidget
---@field decoration Decoration
---@overload fun(child: Widget?, options: { decoration: Decoration, key: any? }?): DecoratedBox
local DecoratedBox = std.class.new('DecoratedBox', { SingleChildRenderObjectWidget })

function DecoratedBox:__init(child, options)
    options = options or {}
    self.key = options.key
    self.id = options.id
    self.child = child
    self.decoration = options.decoration or Decoration()
end

function DecoratedBox:create_render_object()
    return RenderDecoratedBox(self.decoration)
end

function DecoratedBox:update_render_object(render_object)
    render_object.decoration = self.decoration
    render_object:mark_needs_paint()
end

--== flex =================================================================

---@class Flexible : ParentDataWidget
---@field flex number
---@field fit "tight" | "loose"
---@overload fun(child: Widget?, options: { flex: number?, fit: "tight" | "loose"?, key: any? }?): Flexible
local Flexible = std.class.new('Flexible', { ParentDataWidget })

function Flexible:__init(child, options)
    options = options or {}
    self.key = options.key
    self.id = options.id
    self.child = child
    self.flex = options.flex or 1
    -- `Flexible` defaults to a loose fit; `Expanded` passes "tight".
    self.fit = options.fit or 'loose'
end

function Flexible:apply_parent_data(render_object)
    local parent_data = render_object.parent_data
    local changed = parent_data.flex ~= self.flex or parent_data.fit ~= self.fit
    parent_data.flex = self.flex
    parent_data.fit = self.fit
    -- Flutter's `applyParentData` relayouts the enclosing flex when the
    -- parent data actually changes (otherwise a new `flex:` would be ignored).
    if changed and render_object.parent then
        render_object.parent:mark_needs_layout()
    end
end

---@param child Widget?
---@param options { flex: number?, key: any? }?
---@return Flexible
local function Expanded(child, options)
    options = options or {}
    return Flexible(child, { key = options.key, flex = options.flex or 1, fit = 'tight' })
end

---@param options { flex: number?, key: any? }?
---@return Flexible
local function Spacer(options)
    options = options or {}
    -- Flutter's `Spacer` is `Expanded(child: SizedBox.shrink())`.
    return Expanded(SizedBox.shrink(), { key = options.key, flex = options.flex or 1 })
end

---@class Flex : MultiChildRenderObjectWidget
---@field direction "row" | "column"
---@field children Widget[]
---@overload fun(direction: "row" | "column", options: { children: Widget[]?, main_alignment: string?, main_axis_size: "max" | "min"?, cross_alignment: string?, spacing: number?, key: any? }?): Flex
local Flex = std.class.new('Flex', { MultiChildRenderObjectWidget })

function Flex:__init(direction, options)
    options = options or {}
    self.key = options.key
    self.id = options.id
    self.direction = direction or 'row'
    self.children = options.children or {}
    self.main_alignment = options.main_alignment or 'start'
    self.main_axis_size = options.main_axis_size or 'max'
    -- `Flex.crossAxisAlignment` defaults to `CrossAxisAlignment.center`.
    self.cross_alignment = options.cross_alignment or 'center'
    self.spacing = options.spacing or 0
end

function Flex:create_render_object()
    return RenderFlex(self.direction, {
        main_alignment = self.main_alignment,
        main_axis_size = self.main_axis_size,
        cross_alignment = self.cross_alignment,
        spacing = self.spacing,
    })
end

function Flex:update_render_object(render_object)
    render_object.direction = self.direction
    render_object.main_alignment = self.main_alignment
    render_object.main_axis_size = self.main_axis_size
    render_object.cross_alignment = self.cross_alignment
    render_object.spacing = self.spacing
    render_object:mark_needs_layout()
end

---@param options { children: Widget[]?, main_alignment: string?, main_axis_size: "max" | "min"?, cross_alignment: string?, spacing: number?, key: any? }?
---@return Flex
local function Row(options)
    return Flex('row', options)
end

---@param options { children: Widget[]?, main_alignment: string?, main_axis_size: "max" | "min"?, cross_alignment: string?, spacing: number?, key: any? }?
---@return Flex
local function Column(options)
    return Flex('column', options)
end

---@class Stack : MultiChildRenderObjectWidget
---@field children Widget[]
---@overload fun(options: { children: Widget[]?, alignment: Offset?, key: any? }?): Stack
local Stack = std.class.new('Stack', { MultiChildRenderObjectWidget })

function Stack:__init(options)
    options = options or {}
    self.key = options.key
    self.id = options.id
    self.children = options.children or {}
    -- `Stack.alignment` defaults to `AlignmentDirectional.topStart`.
    self.alignment = options.alignment or Offset(0, 0)
end

function Stack:create_render_object()
    return RenderStack({ alignment = self.alignment })
end

function Stack:update_render_object(render_object)
    render_object.alignment = self.alignment
    render_object:mark_needs_layout()
end

--== constrained / overflow / fitted ======================================

---@class ConstrainedBox : SingleChildRenderObjectWidget
---@field constraints Constraints
---@overload fun(options: { child: Widget?, constraints: Constraints, key: any? }?): ConstrainedBox
local ConstrainedBox = std.class.new('ConstrainedBox', { SingleChildRenderObjectWidget })

function ConstrainedBox:__init(options)
    options = options or {}
    self.key = options.key
    self.id = options.id
    self.child = options.child
    self.constraints = options.constraints or Constraints.unbounded()
end

function ConstrainedBox:create_render_object()
    return RenderConstrainedBox(self.constraints)
end

function ConstrainedBox:update_render_object(render_object)
    render_object.additional = self.constraints
    render_object:mark_needs_layout()
end

---@class LimitedBox : SingleChildRenderObjectWidget
---@field max_width number?
---@field max_height number?
---@overload fun(options: { child: Widget?, max_width: number?, max_height: number?, key: any? }?): LimitedBox
local LimitedBox = std.class.new('LimitedBox', { SingleChildRenderObjectWidget })

function LimitedBox:__init(options)
    options = options or {}
    self.key = options.key
    self.id = options.id
    self.child = options.child
    self.max_width = options.max_width
    self.max_height = options.max_height
end

function LimitedBox:create_render_object()
    return RenderLimitedBox(self.max_width, self.max_height)
end

function LimitedBox:update_render_object(render_object)
    render_object.max_width = self.max_width or math.huge
    render_object.max_height = self.max_height or math.huge
    render_object:mark_needs_layout()
end

---@class UnconstrainedBox : SingleChildRenderObjectWidget
---@field alignment Offset?
---@overload fun(options: { child: Widget?, alignment: Offset?, key: any? }?): UnconstrainedBox
local UnconstrainedBox = std.class.new('UnconstrainedBox', { SingleChildRenderObjectWidget })

function UnconstrainedBox:__init(options)
    options = options or {}
    self.key = options.key
    self.id = options.id
    self.child = options.child
    self.alignment = options.alignment or Offset(0.5, 0.5)
end

function UnconstrainedBox:create_render_object()
    return RenderUnconstrainedBox(nil, self.alignment)
end

function UnconstrainedBox:update_render_object(render_object)
    render_object.alignment = self.alignment
    render_object:mark_needs_layout()
end

---@class OverflowBox : SingleChildRenderObjectWidget
---@field opts OverflowBoxOpts
---@overload fun(options: { child: Widget?, min_width: number?, max_width: number?, min_height: number?, max_height: number?, fit: "max" | "defer_to_child"?, alignment: Offset?, key: any? }?): OverflowBox
local OverflowBox = std.class.new('OverflowBox', { SingleChildRenderObjectWidget })

function OverflowBox:__init(options)
    options = options or {}
    self.key = options.key
    self.id = options.id
    self.child = options.child
    self.opts = {
        min_width = options.min_width,
        max_width = options.max_width,
        min_height = options.min_height,
        max_height = options.max_height,
        fit = options.fit,
        alignment = options.alignment,
    }
end

function OverflowBox:create_render_object()
    return RenderOverflowBox(nil, self.opts)
end

function OverflowBox:update_render_object(render_object)
    render_object.opts = self.opts
    render_object.alignment = self.opts.alignment or Offset(0.5, 0.5)
    render_object.fit = self.opts.fit or 'max'
    render_object:mark_needs_layout()
end

---@class FittedBox : SingleChildRenderObjectWidget
---@field fit "contain" | "cover" | "fill" | "fit_width" | "fit_height" | "none" | "scale_down"
---@field alignment Offset
---@overload fun(child: Widget?, options: { fit: "contain" | "cover" | "fill" | "fit_width" | "fit_height" | "none" | "scale_down"?, alignment: Offset?, key: any? }?): FittedBox
local FittedBox = std.class.new('FittedBox', { SingleChildRenderObjectWidget })

function FittedBox:__init(child, options)
    options = options or {}
    self.key = options.key
    self.id = options.id
    self.child = child
    self.fit = options.fit or 'contain'
    self.alignment = options.alignment or Offset(0.5, 0.5)
end

function FittedBox:create_render_object()
    return RenderFittedBox(nil, { fit = self.fit, alignment = self.alignment })
end

function FittedBox:update_render_object(render_object)
    render_object.fit = self.fit
    render_object.alignment = self.alignment
    render_object:mark_needs_layout()
end

--== container ============================================================

--- A convenience composition of margin / sizing / decoration / alignment /
--- padding (Flutter's `Container`). It owns no render object of its own; the
--- whole thing is expressed with the widgets above.
---@class Container : StatelessWidget
---@overload fun(options: { child: Widget?, padding: EdgeInsets?, margin: EdgeInsets?, alignment: Offset?, width: number?, height: number?, constraints: Constraints?, decoration: Decoration?, color: Color?, radius: number?, border_width: number?, border_color: Color?, key: any? }?): Container
local Container = std.class.new('Container', { StatelessWidget })

function Container:__init(options)
    options = options or {}
    self.key = options.key
    self.id = options.id
    self.child = options.child
    self.padding = options.padding
    self.margin = options.margin
    self.alignment = options.alignment
    self.decoration = options.decoration
        or (options.color and Decoration({
            color = options.color,
            radius = options.radius or 0,
            border_width = options.border_width or 0,
            border_color = options.border_color,
        }) or nil)
    -- `width`/`height` are folded into `constraints`, exactly like Flutter's
    -- constructor (`constraints?.tighten(...) ?? BoxConstraints.tightFor(...)`).
    local width, height = options.width, options.height
    local constraints = options.constraints
    if width ~= nil or height ~= nil then
        constraints = constraints and constraints:tighten({ width = width, height = height })
            or Constraints.tight_for({ width = width, height = height })
    end
    self.constraints = constraints
end

function Container:build()
    -- Port of `Container.build`. The childless branch expands to fill a bounded
    -- box (so a decoration shows) but collapses to nothing when the parent is
    -- unbounded; with a child, alignment happens *before* padding.
    local current = self.child
    if current == nil and (self.constraints == nil or not self.constraints:is_tight()) then
        current = LimitedBox({
            max_width = 0,
            max_height = 0,
            child = ConstrainedBox({ constraints = Constraints.expand() }),
        })
    elseif self.alignment then
        current = Align(current, { alignment = self.alignment })
    end
    if self.padding then
        current = Padding(current, { padding = self.padding })
    end
    if self.decoration then
        current = DecoratedBox(current, { decoration = self.decoration })
    end
    if self.constraints then
        current = ConstrainedBox({ constraints = self.constraints, child = current })
    end
    if self.margin then
        current = Padding(current, { padding = self.margin })
    end
    return current
end

function Container:child_widgets()
    return self.child and { self.child } or {}
end

function Container:bind_target()
    return 'child'
end

M.Padding = Padding
M.Align = Align
M.Center = Center
M.SizedBox = SizedBox
M.DecoratedBox = DecoratedBox
M.Flexible = Flexible
M.Expanded = Expanded
M.Spacer = Spacer
M.Flex = Flex
M.Row = Row
M.Column = Column
M.Stack = Stack
M.ConstrainedBox = ConstrainedBox
M.LimitedBox = LimitedBox
M.UnconstrainedBox = UnconstrainedBox
M.OverflowBox = OverflowBox
M.FittedBox = FittedBox
M.Container = Container

return M
