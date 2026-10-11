-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- Backend-neutral nine-point paint anchors. ASS numbers are deliberately not
-- part of this module; the ASS backend maps these names to `\an` values.

local std = require 'elxlibs.std'
local geometry = require 'foundation.geometry'

local Offset = geometry.Offset
local raise = std.raise

local M = {}

---@alias AnchorName
--- | 'top_left'
--- | 'top_center'
--- | 'top_right'
--- | 'center_left'
--- | 'center'
--- | 'center_right'
--- | 'bottom_left'
--- | 'bottom_center'
--- | 'bottom_right'

local Anchor = {
    TOP_LEFT = 'top_left',
    TOP_CENTER = 'top_center',
    TOP_RIGHT = 'top_right',
    CENTER_LEFT = 'center_left',
    CENTER = 'center',
    CENTER_RIGHT = 'center_right',
    BOTTOM_LEFT = 'bottom_left',
    BOTTOM_CENTER = 'bottom_center',
    BOTTOM_RIGHT = 'bottom_right',
}

local FRACTIONS = {
    top_left = { 0, 0 },
    top_center = { 0.5, 0 },
    top_right = { 1, 0 },
    center_left = { 0, 0.5 },
    center = { 0.5, 0.5 },
    center_right = { 1, 0.5 },
    bottom_left = { 0, 1 },
    bottom_center = { 0.5, 1 },
    bottom_right = { 1, 1 },
}

---@param anchor AnchorName
---@return Offset
function M.fraction(anchor)
    local value = type(anchor) == 'string' and FRACTIONS[anchor]
    if not value then
        raise(std.ValueError('unknown paint anchor: ' .. tostring(anchor)))
    end
    return Offset(value[1], value[2])
end

---@param anchor any
---@return boolean
function M.is_valid(anchor)
    return type(anchor) == 'string' and FRACTIONS[anchor] ~= nil
end

M.Anchor = Anchor

return M
