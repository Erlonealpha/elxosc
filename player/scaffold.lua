-- Host-independent PlayerScaffold and its fixed composition widgets.

local std = require 'elxlibs.std'
local geometry = require 'foundation.geometry'
local region_mod = require 'player.region'
local widget_mod = require 'widget.widget'
local layout_widgets = require 'widget.widgets.layout'

local Offset = geometry.Offset
local Region = region_mod.Region
local StatelessWidget = widget_mod.StatelessWidget
local Align = layout_widgets.Align
local Column = layout_widgets.Column
local Expanded = layout_widgets.Expanded
local Row = layout_widgets.Row
local SizedBox = layout_widgets.SizedBox
local Stack = layout_widgets.Stack

local M = {}

---@class _GridOptions
---@field region_widgets table<RegionId, Widget>?
---@field middle_child Widget?
---@field legacy_ids boolean?
---@field key any?

---@class _MainOptions
---@field grid Widget
---@field left Widget?
---@field right Widget?
---@field title_bar Widget?
---@field timeline Widget?
---@field bottom Widget?
---@field key any?

---@class _MoreOptions
---@field children Widget[]?
---@field key any?

---@class _PlayerScaffoldOptions
---@field grid Widget?
---@field region_widgets table<RegionId, Widget>?
---@field middle_child Widget?
---@field main Widget?
---@field main_left Widget?
---@field main_right Widget?
---@field title_bar Widget?
---@field timeline Widget?
---@field bottom Widget?
---@field more Widget?
---@field more_children Widget[]?
---@field key any?

local legacy_slot_ids = {
    [Region.GRID_TOP_LEFT] = 'top_left',
    [Region.GRID_TOP] = 'top',
    [Region.GRID_TOP_RIGHT] = 'top_right',
    [Region.GRID_LEFT] = 'left',
    [Region.GRID_MIDDLE] = 'middle',
    [Region.GRID_RIGHT] = 'right',
    [Region.GRID_BOTTOM_LEFT] = 'bottom_left',
    [Region.GRID_BOTTOM] = 'bottom',
    [Region.GRID_BOTTOM_RIGHT] = 'bottom_right',
}

local function copy_array(values)
    local result = {}
    for index, value in ipairs(values or {}) do
        result[index] = value
    end
    return result
end

local function copy_region_widgets(values)
    local result = {}
    for _, id in ipairs(region_mod.grid_ids()) do
        result[id] = values and values[id] or nil
    end
    return result
end

---@param id RegionId
---@param child Widget?
---@param legacy_ids boolean
---@return Widget
local function cell(id, child, legacy_ids)
    local target_id = legacy_ids and legacy_slot_ids[id] or id
    return Expanded(SizedBox({
        id = target_id,
        child = child or SizedBox.shrink(),
    }))
end

---@param region_widgets table<RegionId, Widget>?
---@param middle_child Widget?
---@param legacy_ids boolean
---@return Widget
local function build_grid(region_widgets, middle_child, legacy_ids)
    local children = copy_region_widgets(region_widgets)
    if middle_child ~= nil then
        children[Region.GRID_MIDDLE] = middle_child
    end

    local ids = region_mod.grid_ids()
    local function grid_row(left_id, middle_id, right_id)
        return Expanded(Row({
            main_alignment = 'start',
            main_axis_size = 'max',
            cross_alignment = 'stretch',
            children = {
                cell(left_id, children[left_id], legacy_ids),
                cell(middle_id, children[middle_id], legacy_ids),
                cell(right_id, children[right_id], legacy_ids),
            },
        }))
    end

    return Column({
        main_alignment = 'start',
        main_axis_size = 'max',
        cross_alignment = 'stretch',
        children = {
            grid_row(ids[1], ids[2], ids[3]),
            grid_row(ids[4], ids[5], ids[6]),
            grid_row(ids[7], ids[8], ids[9]),
        },
    })
end

---@class Grid : StatelessWidget
---@field region_widgets table<RegionId, Widget>
---@field middle_child Widget?
---@field legacy_ids boolean
---@overload fun(options?: _GridOptions): self
local Grid = std.class.new('Grid', { StatelessWidget })

---@param options? _GridOptions
function Grid:__init(options)
    options = options or {}
    self.key = options.key
    self.region_widgets = copy_region_widgets(options.region_widgets)
    self.middle_child = options.middle_child
    self.legacy_ids = options.legacy_ids or false
end

function Grid:build()
    return build_grid(self.region_widgets, self.middle_child, self.legacy_ids)
end

---@class Main : StatelessWidget
---@field grid Widget
---@field left Widget?
---@field right Widget?
---@overload fun(options: _MainOptions): self
local Main = std.class.new('Main', { StatelessWidget })

---@param options _MainOptions
function Main:__init(options)
    options = options or {}
    self.key = options.key
    self.grid = options.grid
    self.left = options.left
    self.right = options.right
    self.title_bar = options.title_bar or SizedBox.shrink({ id = Region.MAIN_TITLE_BAR })
    self.timeline = options.timeline or SizedBox.shrink({ id = Region.MAIN_TIMELINE })
    self.bottom = options.bottom or SizedBox.shrink({ id = Region.MAIN_BOTTOM })
end

function Main:build()
    -- Main owns the fixed shell slots. They are empty by default, but remain
    -- stable bind targets so the player can supply its controls without
    -- allowing extension Pages contributions to replace player-owned regions.
    local children = { self.grid, self.title_bar, self.timeline, self.bottom }
    if self.left then
        children[#children + 1] = Align(self.left, { alignment = Offset(0, 0.5) })
    end
    if self.right then
        children[#children + 1] = Align(self.right, { alignment = Offset(1, 0.5) })
    end
    return Stack({ children = children })
end

---@class More : StatelessWidget
---@field children Widget[]
---@overload fun(options?: _MoreOptions): self
local More = std.class.new('More', { StatelessWidget })

---@param options? _MoreOptions
function More:__init(options)
    options = options or {}
    self.key = options.key
    self.children = copy_array(options.children)
end

function More:build()
    if #self.children == 0 then
        return nil
    end
    return Column({
        main_alignment = 'start',
        main_axis_size = 'min',
        cross_alignment = 'start',
        children = copy_array(self.children),
    })
end

---@class PlayerScaffold : StatelessWidget
---@field main Widget
---@field grid Widget
---@field more Widget
---@overload fun(options?: _PlayerScaffoldOptions): self
local PlayerScaffold = std.class.new('PlayerScaffold', { StatelessWidget })

---@param options? _PlayerScaffoldOptions
function PlayerScaffold:__init(options)
    options = options or {}
    self.key = options.key

    self.grid = options.grid or Grid({
        region_widgets = options.region_widgets,
        middle_child = options.middle_child,
        legacy_ids = true,
    })
    self.main = options.main or Main({
        grid = self.grid,
        left = options.main_left,
        right = options.main_right,
        title_bar = options.title_bar,
        timeline = options.timeline,
        bottom = options.bottom,
    })
    self.more = options.more or More({ children = options.more_children })
end

function PlayerScaffold:build()
    return Stack({
        children = {
            self.main,
            self.more,
        },
    })
end

--- Build the legacy grid directly. The compatibility facade uses this to keep
--- the old render-root shape while the new PlayerScaffold exposes Main/grid/more.
---@param middle_child Widget?
---@param region_widgets table<RegionId, Widget>?
---@return Widget
function M.build_grid(middle_child, region_widgets)
    return build_grid(region_widgets, middle_child, true)
end

--- Construct the complete player composition root.
---@param options? _PlayerScaffoldOptions
---@return PlayerScaffold
function M.build_scaffold(options)
    return PlayerScaffold(options)
end

M.Grid = Grid
M.Main = Main
M.More = More
M.PlayerScaffold = PlayerScaffold
M.LEGACY_SLOT = legacy_slot_ids

return M
