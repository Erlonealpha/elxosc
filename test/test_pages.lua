-- Offline Pages/PlayerScaffold composition and initialization diagnostics.

---@diagnostic disable: undefined-field, inject-field, need-check-nil, generic-constraint-mismatch, preferred-local-alias, unused, call-non-callable

local F = require('framework')
local std = require('elxlibs.std')

local constraints_mod = require('layout.constraints')
local render_owner = require('render.render_owner')
local text_layout = require('text.text_layout')
local binding_mod = require('widget.binding')
local basic_widgets = require('widget.widgets.basic')
local player = require('player')
local region_mod = require('player.region')
local registry_mod = require('player.registry')
local scaffold_mod = require('player.scaffold')

local Constraints = constraints_mod.Constraints
local RenderOwner = render_owner.RenderOwner
local WidgetBinding = binding_mod.WidgetBinding
local Text = basic_widgets.Text
local Region = region_mod.Region
local PageContribution = registry_mod.PageContribution
local PagesRegistry = registry_mod.PagesRegistry
local PlayerScaffold = scaffold_mod.PlayerScaffold
local ExtensionGrid = scaffold_mod.ExtensionGrid
local Extension = scaffold_mod.Extension

local FixedLayout = std.class.new('test.pages.FixedLayout', { text_layout.TextLayout })
function FixedLayout:line_width(line, style)
    return #line * style.font_size * 0.5
end
text_layout.set_default(FixedLayout())

local function mount(widget)
    local owner = RenderOwner()
    WidgetBinding(widget, owner)
    owner:set_viewport(Constraints.tight(300, 180))
    owner:layout()
    return owner
end

local function grid_render(owner)
    local root = owner.root
    local extension = root:children()[2]
    return extension:children()[1]:children()[1]
end

F.section('pages: public regions and operations')

F.test('the aggregate and direct modules share class identities', function()
    F.eq(player.PagesRegistry, PagesRegistry, 'registry identity')
    F.eq(player.PageContribution, PageContribution, 'contribution identity')
    F.eq(player.PlayerScaffold, PlayerScaffold, 'scaffold identity')
    F.eq(player.ExtensionGrid, ExtensionGrid, 'ExtensionGrid identity')
    F.eq(player.Grid, ExtensionGrid, 'Grid compatibility identity')
    F.eq(player.Extension, Extension, 'Extension identity')
    F.eq(#region_mod.grid_ids(), 9, 'nine stable grid ids')
end)

F.test('all grid regions and more accept their intended operations', function()
    local pages = PagesRegistry()
    for _, region in ipairs(region_mod.grid_ids()) do
        pages:fill(region, Text(region), { key = region, scope_id = 'grid' })
    end
    pages:fill(Region.MAIN_LEFT, Text('left'), { key = 'left', scope_id = 'main' })
    pages:fill(Region.MAIN_RIGHT, Text('right'), { key = 'right', scope_id = 'main' })
    pages:append(Region.MORE, Text('more'), { key = 'more', order = 1, scope_id = 'more' })
    F.eq(#pages:entries(), 12, 'all contributions recorded')
end)

F.test('add infers single and multi operations', function()
    local pages = PagesRegistry()
    pages:add(Region.GRID_TOP, Text('top'), { key = 'top' }, 'one')
    pages:add(Region.MORE, Text('more'), { key = 'more' }, 'two')
    F.eq(pages:entries()[1].operation, 'fill', 'single add becomes fill')
    F.eq(pages:entries()[2].operation, 'append', 'multi add becomes append')
end)

F.test('invalid regions and operation/cardinality combinations are rejected', function()
    local pages = PagesRegistry()
    F.raises(function()
        ---@diagnostic disable-next-line: param-type-mismatch
        pages:fill('popup', Text('x'), { key = 'popup' }, 'bad')
    end, 'unknown region', 'unknown region')
    F.raises(function()
        pages:fill(Region.MORE, Text('x'), { key = 'more' }, 'bad')
    end, 'multi-child regions only accept append', 'fill on more')
    F.raises(function()
        pages:append(Region.GRID_TOP, Text('x'), { key = 'top' }, 'bad')
    end, 'single-child regions only accept fill', 'append on grid')
    F.raises(function()
        pages:fill(Region.MAIN_TITLE_BAR, Text('x'), { key = 'title' }, 'bad')
    end, 'not an extension slot', 'player-owned region')
    F.raises(function()
        pages:append(Region.MORE, Text('x'), {}, 'bad')
    end, 'require a key', 'missing multi key')
end)

F.test('single conflicts include scope, region, operation, key and diagnostics', function()
    local pages = PagesRegistry()
    pages:fill(Region.GRID_TOP, Text('first'), { key = 'first' }, 'first-scope')
    F.raises(function()
        pages:fill(Region.GRID_TOP, Text('second'), { key = 'second' }, 'second-scope')
    end, "scope 'second-scope'", 'single conflict scope')
    local diagnostics = pages:diagnostics()
    F.eq(#diagnostics, 1, 'one diagnostic')
    F.eq(diagnostics[1].region, Region.GRID_TOP, 'diagnostic region')
    F.eq(diagnostics[1].operation, 'fill', 'diagnostic operation')
    F.eq(diagnostics[1].key, 'second', 'diagnostic key')
    F.eq(diagnostics[1].scope_id, 'second-scope', 'diagnostic scope')
    F.eq(diagnostics[1].conflict_sequence, 1, 'diagnostic conflict sequence')
end)

F.test('returned contributions cannot mutate the registry-owned declaration', function()
    local pages = PagesRegistry()
    local contribution = pages:fill(Region.GRID_TOP, Text('original'), { key = 'top' })
    contribution.widget = Text('changed')
    contribution.region = Region.GRID_BOTTOM
    local root = pages:assemble()
    F.eq(root.grid.region_widgets[Region.GRID_TOP].text, 'original',
        'scaffold stores assembled copy only')
    local owner = mount(root)
    local grid = grid_render(owner)
    F.eq(grid:children()[1]:children()[2]:children()[1].paragraph.text,
        'original', 'returned mutation does not change assembly')
end)

F.test('duplicate multi keys are rejected without removing valid entries', function()
    local pages = PagesRegistry()
    pages:append(Region.MORE, Text('first'), { key = 'same', order = 20 }, 'first-scope')
    F.raises(function()
        pages:append(Region.MORE, Text('duplicate'), { key = 'same', order = 1 }, 'second-scope')
    end, 'duplicate key', 'duplicate key')
    F.eq(#pages:entries(Region.MORE), 1, 'valid contribution remains')
end)

F.test('ordered append uses order then registration sequence', function()
    local pages = PagesRegistry()
    pages:append(Region.MORE, Text('late'), { key = 'late', order = 20 })
    pages:append(Region.MORE, Text('first'), { key = 'first', order = 10 })
    pages:append(Region.MORE, Text('second'), { key = 'second', order = 10 })
    pages:append(Region.MORE, Text('un-ordered'), { key = 'last' })
    local entries = pages:entries(Region.MORE)
    F.eq(entries[1].sequence, 1, 'first registration sequence')
    F.eq(entries[4].sequence, 4, 'last registration sequence')
    local root = pages:assemble()
    F.eq(root.more.children[1].text, 'first', 'lowest order first')
    F.eq(root.more.children[2].text, 'second', 'equal order keeps registration sequence')
    F.eq(root.more.children[3].text, 'late', 'later explicit order')
    F.eq(root.more.children[4].text, 'un-ordered', 'missing order last')
end)

F.test('scope facade records its scope and options are copied', function()
    local pages = PagesRegistry()
    local options = { key = 'weather', order = 4 }
    pages:scope('weather'):append(Region.MORE, Text('weather'), options)
    options.key = 'changed'
    options.order = 100
    local entry = pages:entries()[1]
    F.eq(entry.scope_id, 'weather', 'facade scope')
    F.eq(entry.key, 'weather', 'copied key')
    F.eq(entry.order, 4, 'copied order')
end)

F.test('freeze seals the registry and assemble returns a fresh root', function()
    local pages = PagesRegistry()
    pages:fill(Region.GRID_TOP, Text('top'), { key = 'top' })
    local snapshot = pages:freeze()
    F.eq(pages:is_frozen(), true, 'frozen')
    F.eq(#snapshot.contributions, 1, 'snapshot contribution')
    F.raises(function()
        pages:add(Region.GRID_LEFT, Text('late'), { key = 'late' }, 'late')
    end, 'frozen', 'registration after freeze')
    local first = pages:assemble()
    local second = pages:assemble()
    F.ok(first ~= second, 'assemble creates a new scaffold instance')
    F.ok(first.grid ~= second.grid, 'assemble creates a new grid instance')
end)

F.test('the scaffold keeps the 3x3 geometry and default middle fallback', function()
    local middle = Text('demo')
    local top_left = Text('top-left')
    local pages = PagesRegistry()
    pages:fill(Region.GRID_TOP_LEFT, top_left, { key = 'top-left' })
    local root = pages:assemble({ middle_child = middle })
    F.eq(root.__class, PlayerScaffold, 'root class')
    F.eq(root.main.__class, scaffold_mod.Main, 'main class')
    F.eq(root.main.grid, nil, 'Main does not own the Extension grid')
    F.eq(root.grid.__class, ExtensionGrid, 'grid class')
    F.eq(root.more.__class, scaffold_mod.More, 'more class')
    F.eq(root.extension.__class, Extension, 'extension class')
    F.eq(root.extension.grid, root.grid, 'Extension owns the grid')
    F.eq(root.extension.more, root.more, 'More is under Extension')
    F.ok(root.main ~= root.extension, 'Main and Extension are siblings')
    F.eq(root.grid.middle_child, middle, 'middle fallback')
    F.eq(top_left.id, nil, 'contribution widget was not mutated')
    F.eq(middle.id, nil, 'fallback widget was not mutated')

    local owner = mount(root)
    local grid = grid_render(owner)
    local rows = grid:children()
    F.eq(#rows, 3, 'three rows')
    for row_index, row in ipairs(rows) do
        F.eq(row.size.width, 300, 'row width')
        F.eq(row.size.height, 60, 'row height')
        F.eq(#row:children(), 3, 'three cells')
        F.eq(row.parent_data.offset.y, (row_index - 1) * 60, 'row offset')
        for cell_index, cell in ipairs(row:children()) do
            F.eq(cell.size.width, 100, 'cell width')
            F.eq(cell.size.height, 60, 'cell height')
            F.eq(cell.parent_data.offset.x, (cell_index - 1) * 100, 'cell offset')
        end
    end
    F.eq(rows[1]:children()[1]:children()[1].paragraph.text, 'top-left', 'grid contribution')
    F.eq(rows[2]:children()[2]:children()[1].paragraph.text, 'demo', 'default middle')
end)

F.test('assembling does not mutate an already constructed scaffold', function()
    local child = Text('old')
    local old = PlayerScaffold({ middle_child = child })
    local pages = PagesRegistry()
    pages:fill(Region.GRID_RIGHT, Text('new'), { key = 'new' })
    pages:assemble({ middle_child = Text('assembled') })
    F.eq(old.grid.middle_child, child, 'old scaffold child remains')
    F.eq(old.grid.region_widgets[Region.GRID_RIGHT], nil, 'old scaffold has no new slot')
    F.eq(child.id, nil, 'old child remains unchanged')
end)
