-- The entry-point scaffold is a stable, bindable three-by-three grid.

---@diagnostic disable: undefined-field, inject-field, need-check-nil, unused, generic-constraint-mismatch

local F = require('framework')
local std = require('elxlibs.std')

local constraints_mod = require('layout.constraints')
local text_layout = require('text.text_layout')
local render_owner = require('render.render_owner')
local binding_mod = require('widget.binding')
local basic_widgets = require('widget.widgets.basic')
local bind_mod = require('widget.bind')
local main_layout = require('main_layout')

local Constraints = constraints_mod.Constraints
local RenderOwner = render_owner.RenderOwner
local WidgetBinding = binding_mod.WidgetBinding
local Text = basic_widgets.Text
local BindRegistry = bind_mod.BindRegistry

local FixedLayout = std.class.new('test.mainlayout.FixedLayout', { text_layout.TextLayout })
function FixedLayout:line_width(line, style)
    return #line * style.font_size * 0.5
end
text_layout.set_default(FixedLayout())

local mp_stub = require('mp_stub')
mp_stub.install()

local function mount(binds)
    local owner = RenderOwner()
    WidgetBinding.ensure_initialized():attach(main_layout.build_scaffold(Text('demo')), owner, binds)
    owner:set_viewport(Constraints.tight(300, 180))
    owner:layout()
    return owner
end

local function global_offset(render_object)
    local x = 0
    local y = 0
    local node = render_object
    while node do
        local offset = node.parent_data and node.parent_data.offset
        if offset then
            x = x + offset.x
            y = y + offset.y
        end
        node = node.parent
    end
    return x, y
end

F.section('main layout: nine-region scaffold')

F.test('the scaffold fills a three-by-three grid', function()
    mp_stub.reset()
    local owner = mount()
    local rows = owner.root:children()

    F.eq(#rows, 3, 'three rows')
    for row_index, row in ipairs(rows) do
        F.eq(row.size.width, 300, 'row width')
        F.eq(row.size.height, 60, 'row height')
        F.eq(#row:children(), 3, 'three cells per row')
        F.eq(row.parent_data.offset.y, (row_index - 1) * 60, 'row y offset')

        for cell_index, cell in ipairs(row:children()) do
            F.eq(cell.size.width, 100, 'cell width')
            F.eq(cell.size.height, 60, 'cell height')
            F.eq(cell.parent_data.offset.x, (cell_index - 1) * 100, 'cell x offset')
        end
    end
end)

F.test('all nine region ids bind without changing their positions', function()
    mp_stub.reset()
    local binds = BindRegistry()
    local ids = {
        'top_left', 'top', 'top_right',
        'left', 'middle', 'right',
        'bottom_left', 'bottom', 'bottom_right',
    }
    for index = #ids, 1, -1 do
        binds:add(ids[index], Text(ids[index]))
    end

    local owner = mount(binds)
    local rows = owner.root:children()
    for row_index, row in ipairs(rows) do
        for cell_index, cell in ipairs(row:children()) do
            local x, y = global_offset(cell)
            F.eq(x, (cell_index - 1) * 100, 'bound cell x position')
            F.eq(y, (row_index - 1) * 60, 'bound cell y position')
            F.eq(cell:children()[1].paragraph.text, ids[(row_index - 1) * 3 + cell_index], 'bound id order')
        end
    end
end)
