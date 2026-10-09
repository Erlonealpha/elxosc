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
local widget_mod = require 'widget.widget'

local Offset = geometry.Offset
local EdgeInsets = geometry.EdgeInsets
local RenderPadding = padding_mod.RenderPadding
local RenderAlign = align_mod.RenderAlign
local RenderSizedBox = sized_box_mod.RenderSizedBox
local Decoration = decorated_box_mod.Decoration
local RenderDecoratedBox = decorated_box_mod.RenderDecoratedBox
local RenderFlex = flex_mod.RenderFlex
local RenderStack = stack_mod.RenderStack
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
---@overload fun(child: Widget?, options: { flex: number?, key: any? }?): Flexible
local Flexible = std.class.new('Flexible', { ParentDataWidget })

function Flexible:__init(child, options)
    options = options or {}
    self.key = options.key
    self.id = options.id
    self.child = child
    self.flex = options.flex or 1
end

function Flexible:apply_parent_data(render_object)
    render_object.parent_data.flex = self.flex
end

---@param child Widget?
---@param options { flex: number?, key: any? }?
---@return Flexible
local function Expanded(child, options)
    options = options or {}
    return Flexible(child, { key = options.key, flex = options.flex or 1 })
end

---@param options { flex: number?, key: any? }?
---@return Flexible
local function Spacer(options)
    options = options or {}
    return Flexible(SizedBox({ width = 0, height = 0 }), { key = options.key, flex = options.flex or 1 })
end

---@class Flex : MultiChildRenderObjectWidget
---@field direction "row" | "column"
---@field children Widget[]
---@overload fun(direction: "row" | "column", options: { children: Widget[]?, main_alignment: string?, cross_alignment: string?, spacing: number?, key: any? }?): Flex
local Flex = std.class.new('Flex', { MultiChildRenderObjectWidget })

function Flex:__init(direction, options)
    options = options or {}
    self.key = options.key
    self.id = options.id
    self.direction = direction or 'row'
    self.children = options.children or {}
    self.main_alignment = options.main_alignment or 'start'
    self.cross_alignment = options.cross_alignment or 'start'
    self.spacing = options.spacing or 0
end

function Flex:create_render_object()
    return RenderFlex(self.direction, {
        main_alignment = self.main_alignment,
        cross_alignment = self.cross_alignment,
        spacing = self.spacing,
    })
end

function Flex:update_render_object(render_object)
    render_object.direction = self.direction
    render_object.main_alignment = self.main_alignment
    render_object.cross_alignment = self.cross_alignment
    render_object.spacing = self.spacing
    render_object:mark_needs_layout()
end

---@param options { children: Widget[]?, main_alignment: string?, cross_alignment: string?, spacing: number?, key: any? }?
---@return Flex
local function Row(options)
    return Flex('row', options)
end

---@param options { children: Widget[]?, main_alignment: string?, cross_alignment: string?, spacing: number?, key: any? }?
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
    self.alignment = options.alignment or Offset(0.5, 0.5)
end

function Stack:create_render_object()
    return RenderStack({ alignment = self.alignment })
end

function Stack:update_render_object(render_object)
    render_object.alignment = self.alignment
    render_object:mark_needs_layout()
end

--== container ============================================================

--- A convenience composition of margin / sizing / decoration / alignment /
--- padding (Flutter's `Container`). It owns no render object of its own; the
--- whole thing is expressed with the widgets above.
---@class Container : StatelessWidget
---@overload fun(options: { child: Widget?, padding: EdgeInsets?, margin: EdgeInsets?, alignment: Offset?, width: number?, height: number?, decoration: Decoration?, color: Color?, radius: number?, border_width: number?, border_color: Color?, key: any? }?): Container
local Container = std.class.new('Container', { StatelessWidget })

function Container:__init(options)
    options = options or {}
    self.key = options.key
    self.id = options.id
    self.child = options.child
    self.padding = options.padding
    self.margin = options.margin
    self.alignment = options.alignment
    self.width = options.width
    self.height = options.height
    self.decoration = options.decoration
        or (options.color and Decoration({
            color = options.color,
            radius = options.radius or 0,
            border_width = options.border_width or 0,
            border_color = options.border_color,
        }) or nil)
end

function Container:build()
    local child = self.child
    if child == nil then
        -- an empty Container still fills a bounded box, so a decoration shows
        child = SizedBox({ width = self.width, height = self.height })
    else
        if self.padding then
            child = Padding(child, { padding = self.padding })
        end
        if self.alignment then
            child = Align(child, { alignment = self.alignment })
        end
    end
    if self.decoration then
        child = DecoratedBox(child, { decoration = self.decoration })
    end
    if self.width or self.height then
        child = SizedBox({ width = self.width, height = self.height, child = child })
    end
    if self.margin then
        child = Padding(child, { padding = self.margin })
    end
    return child
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
M.Container = Container

return M
