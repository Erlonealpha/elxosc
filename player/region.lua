-- Host-independent region names owned by the player composition layer.

local M = {}

---@alias RegionId
---| 'main.title_bar'
---| 'main.timeline'
---| 'main.bottom'
---| 'main.left'
---| 'main.right'
---| 'grid.top_left'
---| 'grid.top'
---| 'grid.top_right'
---| 'grid.left'
---| 'grid.middle'
---| 'grid.right'
---| 'grid.bottom_left'
---| 'grid.bottom'
---| 'grid.bottom_right'
---| 'more'

---@alias RegionCardinality
---| 'single'
---| 'multi'

---@class RegionDefinition
---@field id RegionId
---@field cardinality RegionCardinality
---@field extension boolean

---@class RegionNames
---@field MAIN_TITLE_BAR 'main.title_bar'
---@field MAIN_TIMELINE 'main.timeline'
---@field MAIN_BOTTOM 'main.bottom'
---@field MAIN_BOTTOM_CONTROLS 'main.bottom'
---@field MAIN_LEFT 'main.left'
---@field MAIN_RIGHT 'main.right'
---@field GRID_TOP_LEFT 'grid.top_left'
---@field GRID_TOP 'grid.top'
---@field GRID_TOP_RIGHT 'grid.top_right'
---@field GRID_LEFT 'grid.left'
---@field GRID_MIDDLE 'grid.middle'
---@field GRID_RIGHT 'grid.right'
---@field GRID_BOTTOM_LEFT 'grid.bottom_left'
---@field GRID_BOTTOM 'grid.bottom'
---@field GRID_BOTTOM_RIGHT 'grid.bottom_right'
---@field MORE 'more'

local Region = {
    MAIN_TITLE_BAR = 'main.title_bar',
    MAIN_TIMELINE = 'main.timeline',
    MAIN_BOTTOM = 'main.bottom',
    MAIN_BOTTOM_CONTROLS = 'main.bottom',
    MAIN_LEFT = 'main.left',
    MAIN_RIGHT = 'main.right',
    GRID_TOP_LEFT = 'grid.top_left',
    GRID_TOP = 'grid.top',
    GRID_TOP_RIGHT = 'grid.top_right',
    GRID_LEFT = 'grid.left',
    GRID_MIDDLE = 'grid.middle',
    GRID_RIGHT = 'grid.right',
    GRID_BOTTOM_LEFT = 'grid.bottom_left',
    GRID_BOTTOM = 'grid.bottom',
    GRID_BOTTOM_RIGHT = 'grid.bottom_right',
    MORE = 'more',
}

local grid_ids = {
    Region.GRID_TOP_LEFT,
    Region.GRID_TOP,
    Region.GRID_TOP_RIGHT,
    Region.GRID_LEFT,
    Region.GRID_MIDDLE,
    Region.GRID_RIGHT,
    Region.GRID_BOTTOM_LEFT,
    Region.GRID_BOTTOM,
    Region.GRID_BOTTOM_RIGHT,
}

local definitions = {
    [Region.MAIN_TITLE_BAR] = {
        id = Region.MAIN_TITLE_BAR,
        cardinality = 'single',
        extension = false,
    },
    [Region.MAIN_TIMELINE] = {
        id = Region.MAIN_TIMELINE,
        cardinality = 'single',
        extension = false,
    },
    [Region.MAIN_BOTTOM] = {
        id = Region.MAIN_BOTTOM,
        cardinality = 'single',
        extension = false,
    },
    [Region.MAIN_LEFT] = {
        id = Region.MAIN_LEFT,
        cardinality = 'single',
        extension = true,
    },
    [Region.MAIN_RIGHT] = {
        id = Region.MAIN_RIGHT,
        cardinality = 'single',
        extension = true,
    },
    [Region.MORE] = {
        id = Region.MORE,
        cardinality = 'multi',
        extension = true,
    },
}

for _, id in ipairs(grid_ids) do
    definitions[id] = {
        id = id,
        cardinality = 'single',
        extension = true,
    }
end

--- Return whether `value` is one of the stable public region IDs.
---@param value any
---@return boolean
function M.is_region(value)
    return type(value) == 'string' and definitions[value] ~= nil
end

--- Return a defensive copy of a region definition.
---@param id RegionId
---@return RegionDefinition?
function M.definition(id)
    local definition = definitions[id]
    if not definition then
        return nil
    end
    return {
        id = definition.id,
        cardinality = definition.cardinality,
        extension = definition.extension,
    }
end

--- Return the nine grid IDs in their fixed visual order.
---@return RegionId[]
function M.grid_ids()
    local result = {}
    for index, id in ipairs(grid_ids) do
        result[index] = id
    end
    return result
end

--- Return all region definitions in stable declaration order.
---@return RegionDefinition[]
function M.definitions()
    local result = {}
    local ids = {
        Region.MAIN_TITLE_BAR,
        Region.MAIN_TIMELINE,
        Region.MAIN_BOTTOM,
        Region.MAIN_LEFT,
        Region.MAIN_RIGHT,
    }
    for _, id in ipairs(grid_ids) do
        ids[#ids + 1] = id
    end
    ids[#ids + 1] = Region.MORE
    for _, id in ipairs(ids) do
        result[#result + 1] = M.definition(id)
    end
    return result
end

M.Region = Region
M.REGION = Region

return M
