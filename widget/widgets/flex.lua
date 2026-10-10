-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

local std = require 'elxlibs.std'
local flex_mod = require 'render.flex'
local sized_box_mod = require 'widget.widgets.sized_box'
local widget_mod = require 'widget.widget'

local RenderFlex = flex_mod.RenderFlex
local SizedBox = sized_box_mod.SizedBox
local ParentDataWidget = widget_mod.ParentDataWidget
local MultiChildRenderObjectWidget = widget_mod.MultiChildRenderObjectWidget

---@class _FlexibleOptions
---@field flex? number
---@field fit? 'tight'|'loose'
---@field key? any
---@field id? string

---@class _ExpandedOptions
---@field flex? number
---@field key? any
---@field id? string

---@class _FlexOptions
---@field children? Widget[]
---@field main_alignment? 'start'|'center'|'end'|'space_between'|'space_around'|'space_evenly'
---@field main_axis_size? 'max'|'min'
---@field cross_alignment? 'start'|'center'|'end'|'stretch'|'baseline'
---@field spacing? number
---@field key? any
---@field id? string

---@class Flexible : ParentDataWidget
---@field flex number
---@field fit 'tight'|'loose'
---@overload fun(child: Widget?, options?: _FlexibleOptions): Flexible
local Flexible = std.class.new('Flexible', { ParentDataWidget })

---@param child Widget?
---@param options? _FlexibleOptions
function Flexible:__init(child, options)
    options = options or {}
    self.key = options.key
    self.id = options.id
    self.child = child
    self.flex = options.flex or 1
    -- `Flexible` defaults to a loose fit; `Expanded` passes 'tight'.
    self.fit = options.fit or 'loose'
end

---@param render_object RenderObject
function Flexible:apply_parent_data(render_object)
    local parent_data = render_object.parent_data
    local changed = parent_data.flex ~= self.flex or parent_data.fit ~= self.fit
    parent_data.flex = self.flex
    parent_data.fit = self.fit
    -- Relayout the enclosing flex only when parent data changes.
    if changed and render_object.parent then
        render_object.parent:mark_needs_layout()
    end
end

---@param child Widget?
---@param options? _ExpandedOptions
---@return Flexible
local function Expanded(child, options)
    options = options or {}
    return Flexible(child, { key = options.key, id = options.id, flex = options.flex or 1, fit = 'tight' })
end

---@param options? _ExpandedOptions
---@return Flexible
local function Spacer(options)
    options = options or {}
    -- Flutter's `Spacer` is `Expanded(child: SizedBox.shrink())`.
    return Expanded(SizedBox.shrink(), { key = options.key, id = options.id, flex = options.flex or 1 })
end

---@class Flex : MultiChildRenderObjectWidget
---@field direction 'row'|'column'
---@field children Widget[]
---@field main_alignment 'start'|'center'|'end'|'space_between'|'space_around'|'space_evenly'
---@field main_axis_size 'max'|'min'
---@field cross_alignment 'start'|'center'|'end'|'stretch'|'baseline'
---@field spacing number
---@overload fun(direction: 'row'|'column', options?: _FlexOptions): Flex
local Flex = std.class.new('Flex', { MultiChildRenderObjectWidget })

---@param direction 'row'|'column'
---@param options? _FlexOptions
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

---@param render_object RenderFlex
function Flex:update_render_object(render_object)
    render_object.direction = self.direction
    render_object.main_alignment = self.main_alignment
    render_object.main_axis_size = self.main_axis_size
    render_object.cross_alignment = self.cross_alignment
    render_object.spacing = self.spacing
    render_object:mark_needs_layout()
end

---@param options? _FlexOptions
---@return Flex
local function Row(options)
    return Flex('row', options)
end

---@param options? _FlexOptions
---@return Flex
local function Column(options)
    return Flex('column', options)
end

return { Flexible = Flexible, Expanded = Expanded, Spacer = Spacer, Flex = Flex, Row = Row, Column = Column }
