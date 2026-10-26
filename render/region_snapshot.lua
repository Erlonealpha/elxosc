-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- A value snapshot of one root's effective input regions, in paint order.
local std = require 'elxlibs.std'
local geometry = require 'foundation.geometry'
local Rect = geometry.Rect

local function copy_regions(regions)
    local copy = {}
    for index, region in ipairs(regions) do
        local rect = region.rect
        copy[index] = {
            node = region.node,
            rect = Rect(rect.left, rect.top, rect.right, rect.bottom),
            down = region.down,
            wheel = region.wheel,
        }
    end
    return copy
end

---@class _RegionSnapshotOptions
---@field generation integer
---@field root RenderObject?
---@field regions PointerRegion[]

---@class RegionSnapshot : std.object
---@field generation integer
---@field root RenderObject?
---@field private _regions PointerRegion[]
---@overload fun(options: _RegionSnapshotOptions): self
local RegionSnapshot = std.class.new('RegionSnapshot', {})

function RegionSnapshot:__init(options)
    self.generation = options.generation
    self.root = options.root
    self._regions = copy_regions(options.regions)
end

---@return PointerRegion[]
function RegionSnapshot:regions()
    return copy_regions(self._regions)
end

---@param other RegionSnapshot?
---@return boolean
function RegionSnapshot:same_regions(other)
    if other == self then
        return true
    end
    if other == nil or self.root ~= other.root or #self._regions ~= #other._regions then
        return false
    end
    for index, region in ipairs(self._regions) do
        local previous = other._regions[index]
        if previous == nil or region.node ~= previous.node or region.rect ~= previous.rect
            or region.down ~= previous.down or region.wheel ~= previous.wheel then
            return false
        end
    end
    return true
end

return { RegionSnapshot = RegionSnapshot }
