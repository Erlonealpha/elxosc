-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- Generic visibility render wrappers.

local std = require 'elxlibs.std'
local offstage_mod = require 'src.render.offstage'
local opacity_mod = require 'src.render.opacity'
local widget_mod = require 'src.widgets.framework'

local RenderOffstage = offstage_mod.RenderOffstage
local RenderOpacity = opacity_mod.RenderOpacity
local SingleChildRenderObjectWidget = widget_mod.SingleChildRenderObjectWidget
local StatelessWidget = widget_mod.StatelessWidget

---@class elxosc.mod.src.widgets.visibility
local M = {}

--== Opacity ================================================================

---@class _OpacityOptions
---@field opacity number? paint-only alpha from 0 to 1
---@field hidden boolean? suppress paint/input while retaining layout
---@field child Widget?
---@field key any?

---@class Opacity : SingleChildRenderObjectWidget
---@field opacity number
---@field hidden boolean
---@field child Widget?
---@overload fun(options?: _OpacityOptions): self
local Opacity = std.class.new('Opacity', SingleChildRenderObjectWidget)

function Opacity:__init(options)
    options = options or {}
    self.key = options.key
    self.opacity = options.opacity == nil and 1 or options.opacity
    self.hidden = options.hidden == true
    self.child = options.child
end

function Opacity:create_render_object()
    return RenderOpacity(self.opacity, nil, self.hidden)
end

---@param render_object RenderOpacity
function Opacity:update_render_object(render_object)
    render_object:set_opacity(self.opacity)
    render_object:set_hidden(self.hidden)
end

--== Offstage ===============================================================

---@class _OffstageOptions
---@field offstage boolean?
---@field child Widget?
---@field key any?

---@class Offstage : SingleChildRenderObjectWidget
---@field offstage boolean
---@field child Widget?
---@overload fun(options?: _OffstageOptions): self
local Offstage = std.class.new('Offstage', SingleChildRenderObjectWidget)

function Offstage:__init(options)
    options = options or {}
    self.key = options.key
    self.offstage = options.offstage == true
    self.child = options.child
end

function Offstage:create_render_object()
    return RenderOffstage(self.offstage)
end

---@param render_object RenderOffstage
function Offstage:update_render_object(render_object)
    render_object:set_offstage(self.offstage)
end

--== Visibility =============================================================

---@class _VisibilityOptions
---@field visible boolean?
---@field maintain_state boolean?
---@field child Widget?
---@field key any?

---@class Visibility : StatelessWidget
---@field visible boolean
---@field maintain_state boolean
---@field child Widget?
---@overload fun(options?: _VisibilityOptions): self
local Visibility = std.class.new('Visibility', StatelessWidget)

function Visibility:__init(options)
    options = options or {}
    self.key = options.key
    self.visible = options.visible ~= false
    self.maintain_state = options.maintain_state ~= false
    self.child = options.child
end

function Visibility:child_widgets()
    return self.child and { self.child } or {}
end

function Visibility:build()
    if self.visible then
        return self.child
    end
    if self.maintain_state then
        return Offstage({ offstage = true, child = self.child })
    end
    return nil
end

M.Opacity = Opacity
M.Offstage = Offstage
M.Visibility = Visibility

return M
