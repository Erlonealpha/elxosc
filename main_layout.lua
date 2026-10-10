-- The application's nine-region scaffold.

local layout_widgets = require 'widget.widgets.layout'

local Column = layout_widgets.Column
local Expanded = layout_widgets.Expanded
local Row = layout_widgets.Row
local SizedBox = layout_widgets.SizedBox

local M = {}

-- Every region keeps a render node even before another script binds content.
-- This makes the scaffold a stable three-by-three grid during the define
-- window as well as after bindings have been applied.
local SLOT = {
    top_left = 'top_left',
    top = 'top',
    top_right = 'top_right',
    left = 'left',
    middle = 'middle',
    right = 'right',
    bottom_left = 'bottom_left',
    bottom = 'bottom',
    bottom_right = 'bottom_right',
}

local function cell(id, child)
    return Expanded(SizedBox({
        id = id,
        child = child or SizedBox.shrink(),
    }))
end

local function grid_row(left_id, middle_id, right_id, middle_child)
    return Expanded(Row({
        main_alignment = 'start',
        main_axis_size = 'max',
        cross_alignment = 'stretch',
        children = {
            cell(left_id),
            cell(middle_id, middle_child),
            cell(right_id),
        },
    }))
end

---@param middle_child? Widget
---@return Widget
function M.build_scaffold(middle_child)
    if not middle_child then
        local demo_mod = require 'demo'
        middle_child = demo_mod.Demo()
    end

    return Column({
        main_alignment = 'start',
        main_axis_size = 'max',
        cross_alignment = 'stretch',
        children = {
            grid_row(SLOT.top_left, SLOT.top, SLOT.top_right),
            grid_row(SLOT.left, SLOT.middle, SLOT.right, middle_child),
            grid_row(SLOT.bottom_left, SLOT.bottom, SLOT.bottom_right),
        },
    })
end

M.SLOT = SLOT

return M
