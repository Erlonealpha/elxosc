-- Typed extension consumers exercise module tables without flattening imports.
local F = require 'framework'
local modules_mod = require 'extension.modules'
local foundation_package = require 'foundation'
local painting_package = require 'painting'
local text_package = require 'text'
local widget_package = require 'widget'
local player_package = require 'player'

F.section('exports: typed module consumers')

---@param values elxosc.foundation
---@param painting elxosc.painting
---@param text elxosc.text
---@param widgets elxosc.widget
---@param player elxosc.src.widget.player.components
---@return Slider, PlayerControlButton, TextStyle, Paint
local function make_controls(values, painting, text, widgets, player)
    local size = values.Size(120, 24)
    local style = text.TextStyle({ font_size = size.height / 2 })
    local brush = painting.Paint(values.Color(255, 255, 255))
    return widgets.Slider({ value = 0.5 }),
        player.PlayerControlButton({ icon = 'toggle_on' }), style, brush
end

F.test('typed descriptors retain canonical constructors and module intersections', function()
    local slider, button, style, brush = make_controls(foundation_package,
        painting_package, text_package, widget_package,
        player_package)
    F.eq(slider.__class, require('src.widget.widgets.slider').Slider, 'Slider class identity')
    F.eq(button.__class, require('src.widget.player.extension_controls').PlayerControlButton,
        'player control identity')
    F.eq(style.font_size, 12, 'text module constructor')
    F.eq(brush.color.r, 255, 'foundation and painting module constructors')
end)

---@alias TestArrayExports elxosc.src.widget.widgets.slider & {n: number} & string[]

---@param exports TestArrayExports
---@return Slider, string?
local function read_array_package(exports)
    return exports.Slider({ value = exports.n }), exports[1]
end

F.test('typed package intersections preserve named and array members', function()
    ---@type TestArrayExports
    local exports = { Slider = require('src.widget.widgets.slider').Slider, n = 0.25, 'item' }
    ---@type DefinePackage<TestArrayExports>
    local package = { name = 'array-controls', exports = exports }
    local registry = modules_mod.ModuleRegistry()
    modules_mod.register_package(registry, package)
    ---@type TestArrayExports
    local imported = registry:import_as(package.name, 'consumer')
    local slider, item = read_array_package(imported)
    F.eq(slider.value, 0.25, 'named field survives import')
    F.eq(item, 'item', 'array field survives import')
end)
