-- Benchmark tests against https://docs.flutter.dev/ui/layout/constraints.
--
-- Every example from the doc's DartPad is rebuilt with the elxosc widget layer
-- (see `test/constraints_examples.lua`), laid out on a fixed 400x670 screen and
-- painted through the ASS backend. The *whole* raw `ass-events` payload is then
-- compared verbatim against the expected string below, so a regression anywhere
-- in the constraint pipeline (constraints -> sizes -> offsets -> drawing)
-- shows up as a diff.
--
-- The expected payloads are derived from the geometry the doc states, e.g.:
--   * example 3  -> a 100x100 red box centred on 400x670: x 150..250, y 285..385
--   * example 10 -> the child wants 10x10 but is clamped to the 70 MINIMUM
--   * example 25 -> the Expanded child gets 400-120 = 280 and centres 210 inside
--   * example 28/29 -> a loose Scaffold leaves the blue box 64 wide, while
--                      SizedBox.expand forces it to the full 400.
-- ASS drawings are emitted at 8x sub-pixel, so the numbers are px * 8.

---@diagnostic disable: undefined-field, inject-field, need-check-nil, generic-constraint-mismatch, preferred-local-alias, unused

local F = require('framework')

local geometry = require 'foundation.geometry'
local constraints_mod = require 'layout.constraints'
local render_owner = require 'render.render_owner'
local binding_mod = require 'widget.binding'
local ass_canvas = require 'backends.ass_canvas'
local ass_text = require 'backends.ass_text_layout'
local text_layout = require 'text.text_layout'
local fixtures = require 'constraints_examples'

local Size = geometry.Size
local Constraints = constraints_mod.Constraints
local RenderOwner = render_owner.RenderOwner
local WidgetBinding = binding_mod.WidgetBinding
local AssCanvas = ass_canvas.AssCanvas

local W, H = 400, 670

text_layout.set_default(ass_text.AssTextLayout())

--- Expected raw `ass-events` payload per example (`false` = the doc says this
--- input must raise instead of rendering).
---@type table<string, string|false>
local EXPECTED = {
    ['1'] = [==[{\pos(0,0)\rDefault\an7\blur0\bord0\shad0\1c&H0000FF&\1a&H00&}{\p4}m 0 0 l 3200 0 l 3200 5360 l 0 5360 c{\p0}]==],
    ['2'] = [==[{\pos(0,0)\rDefault\an7\blur0\bord0\shad0\1c&H0000FF&\1a&H00&}{\p4}m 0 0 l 3200 0 l 3200 5360 l 0 5360 c{\p0}]==],
    ['3'] = [==[{\pos(0,0)\rDefault\an7\blur0\bord0\shad0\1c&H0000FF&\1a&H00&}{\p4}m 1200 2280 l 2000 2280 l 2000 3080 l 1200 3080 c{\p0}]==],
    ['4'] = [==[{\pos(0,0)\rDefault\an7\blur0\bord0\shad0\1c&H0000FF&\1a&H00&}{\p4}m 2400 4560 l 3200 4560 l 3200 5360 l 2400 5360 c{\p0}]==],
    ['5'] = [==[{\pos(0,0)\rDefault\an7\blur0\bord0\shad0\1c&H0000FF&\1a&H00&}{\p4}m 0 0 l 3200 0 l 3200 5360 l 0 5360 c{\p0}]==],
    ['6'] = [==[{\pos(0,0)\rDefault\an7\blur0\bord0\shad0\1c&H0000FF&\1a&H00&}{\p4}m 0 0 l 3200 0 l 3200 5360 l 0 5360 c{\p0}]==],
    ['7'] = [==[{\pos(0,0)\rDefault\an7\blur0\bord0\shad0\1c&H0000FF&\1a&H00&}{\p4}m 1480 2560 l 1720 2560 l 1720 2800 l 1480 2800 c{\p0}
{\pos(0,0)\rDefault\an7\blur0\bord0\shad0\1c&H00FF00&\1a&H00&}{\p4}m 1480 2560 l 1720 2560 l 1720 2800 l 1480 2800 c{\p0}]==],
    ['8'] = [==[{\pos(0,0)\rDefault\an7\blur0\bord0\shad0\1c&H0000FF&\1a&H00&}{\p4}m 1320 2400 l 1880 2400 l 1880 2960 l 1320 2960 c{\p0}
{\pos(0,0)\rDefault\an7\blur0\bord0\shad0\1c&H00FF00&\1a&H00&}{\p4}m 1480 2560 l 1720 2560 l 1720 2800 l 1480 2800 c{\p0}]==],
    ['9'] = [==[{\pos(0,0)\rDefault\an7\blur0\bord0\shad0\1c&H0000FF&\1a&H00&}{\p4}m 0 0 l 3200 0 l 3200 5360 l 0 5360 c{\p0}]==],
    ['10'] = [==[{\pos(0,0)\rDefault\an7\blur0\bord0\shad0\1c&H0000FF&\1a&H00&}{\p4}m 1320 2400 l 1880 2400 l 1880 2960 l 1320 2960 c{\p0}]==],
    ['11'] = [==[{\pos(0,0)\rDefault\an7\blur0\bord0\shad0\1c&H0000FF&\1a&H00&}{\p4}m 1000 2080 l 2200 2080 l 2200 3280 l 1000 3280 c{\p0}]==],
    ['12'] = [==[{\pos(0,0)\rDefault\an7\blur0\bord0\shad0\1c&H0000FF&\1a&H00&}{\p4}m 1200 2280 l 2000 2280 l 2000 3080 l 1200 3080 c{\p0}]==],
    ['13'] = [==[{\pos(0,0)\rDefault\an7\blur0\bord0\shad0\1c&H0000FF&\1a&H00&}{\p4}m 1520 2480 l 1680 2480 l 1680 2880 l 1520 2880 c{\p0}]==],
    ['14'] = [==[{\pos(0,0)\rDefault\an7\blur0\bord0\shad0\1c&H0000FF&\1a&H00&}{\p4}m -14400 2480 l 17600 2480 l 17600 2880 l -14400 2880 c{\p0}]==],
    ['15'] = [==[{\pos(0,0)\rDefault\an7\blur0\bord0\shad0\1c&H0000FF&\1a&H00&}{\p4}m -14400 2480 l 17600 2480 l 17600 2880 l -14400 2880 c{\p0}]==],
    ['16'] = false,
    ['17'] = [==[{\pos(0,0)\rDefault\an7\blur0\bord0\shad0\1c&H0000FF&\1a&H00&}{\p4}m 1200 2280 l 2000 2280 l 2000 3080 l 1200 3080 c{\p0}]==],
    ['18'] = [==[{\pos(0,335)\rDefault\an4\blur0\fs30\1c&HFFFFFF&\1a&H00&\bord0\shad0\fscx148\fscy148}Some Example Text.]==],
    ['19'] = [==[{\pos(65,335)\rDefault\an4\blur0\fs30\1c&HFFFFFF&\1a&H00&\bord0\shad0}Some Example Text.]==],
    ['20'] = [==[{\pos(0,335)\rDefault\an4\blur0\fs30\1c&HFFFFFF&\1a&H00&\bord0\shad0\fscx28\fscy28}This is some very very very large text that is too big to fit a regular screen in a single line.]==],
    ['21'] = [==[{\pos(20,335)\rDefault\an4\blur0\fs30\1c&HFFFFFF&\1a&H00&\bord0\shad0}This is some very very\Nvery large text that is\Ntoo big to fit a regular\Nscreen in a single line.]==],
    ['22'] = false,
    ['23'] = [==[{\pos(0,0)\rDefault\an7\blur0\bord0\shad0\1c&H0000FF&\1a&H00&}{\p4}m 0 2536 l 720 2536 l 720 2824 l 0 2824 c{\p0}
{\pos(0,335)\rDefault\an4\blur0\fs30\1c&HFFFFFF&\1a&H00&\bord0\shad0}Hello!
{\pos(0,0)\rDefault\an7\blur0\bord0\shad0\1c&H00FF00&\1a&H00&}{\p4}m 720 2536 l 1680 2536 l 1680 2824 l 720 2824 c{\p0}
{\pos(90,335)\rDefault\an4\blur0\fs30\1c&HFFFFFF&\1a&H00&\bord0\shad0}Goodbye!]==],
    ['24'] = [==[{\pos(0,0)\rDefault\an7\blur0\bord0\shad0\1c&H0000FF&\1a&H00&}{\p4}m 0 2536 l 5880 2536 l 5880 2824 l 0 2824 c{\p0}
{\pos(0,335)\rDefault\an4\blur0\fs30\1c&HFFFFFF&\1a&H00&\bord0\shad0}This is a very long text that won't fit the line.
{\pos(0,0)\rDefault\an7\blur0\bord0\shad0\1c&H00FF00&\1a&H00&}{\p4}m 5880 2536 l 6840 2536 l 6840 2824 l 5880 2824 c{\p0}
{\pos(735,335)\rDefault\an4\blur0\fs30\1c&HFFFFFF&\1a&H00&\bord0\shad0}Goodbye!]==],
    ['25'] = [==[{\pos(0,0)\rDefault\an7\blur0\bord0\shad0\1c&H0000FF&\1a&H00&}{\p4}m 280 2104 l 1960 2104 l 1960 3256 l 280 3256 c{\p0}
{\pos(35,335)\rDefault\an4\blur0\fs30\1c&HFFFFFF&\1a&H00&\bord0\shad0}This is a very\Nlong text that\Nwon't fit the\Nline.
{\pos(0,0)\rDefault\an7\blur0\bord0\shad0\1c&H00FF00&\1a&H00&}{\p4}m 2240 2536 l 3200 2536 l 3200 2824 l 2240 2824 c{\p0}
{\pos(280,335)\rDefault\an4\blur0\fs30\1c&HFFFFFF&\1a&H00&\bord0\shad0}Goodbye!]==],
    ['26'] = [==[{\pos(0,0)\rDefault\an7\blur0\bord0\shad0\1c&H0000FF&\1a&H00&}{\p4}m 0 1960 l 1600 1960 l 1600 3400 l 0 3400 c{\p0}
{\pos(0,335)\rDefault\an4\blur0\fs30\1c&HFFFFFF&\1a&H00&\bord0\shad0}This is a\Nvery long\Ntext that\Nwon't fit the\Nline.
{\pos(0,0)\rDefault\an7\blur0\bord0\shad0\1c&H00FF00&\1a&H00&}{\p4}m 1600 2536 l 3200 2536 l 3200 2824 l 1600 2824 c{\p0}
{\pos(200,335)\rDefault\an4\blur0\fs30\1c&HFFFFFF&\1a&H00&\bord0\shad0}Goodbye!]==],
    ['27'] = [==[{\pos(0,0)\rDefault\an7\blur0\bord0\shad0\1c&H0000FF&\1a&H00&}{\p4}m 0 1960 l 1560 1960 l 1560 3400 l 0 3400 c{\p0}
{\pos(0,335)\rDefault\an4\blur0\fs30\1c&HFFFFFF&\1a&H00&\bord0\shad0}This is a\Nvery long\Ntext that\Nwon't fit the\Nline.
{\pos(0,0)\rDefault\an7\blur0\bord0\shad0\1c&H00FF00&\1a&H00&}{\p4}m 1560 2536 l 2520 2536 l 2520 2824 l 1560 2824 c{\p0}
{\pos(195,335)\rDefault\an4\blur0\fs30\1c&HFFFFFF&\1a&H00&\bord0\shad0}Goodbye!]==],
    ['28'] = [==[{\pos(0,0)\rDefault\an7\blur0\bord0\shad0\1c&HFF0000&\1a&H00&}{\p4}m 0 0 l 512 0 l 512 5360 l 0 5360 c{\p0}
{\pos(8,10)\rDefault\an4\blur0\fs16\1c&HFFFFFF&\1a&H00&\bord0\shad0}Hello!
{\pos(0,29)\rDefault\an4\blur0\fs16\1c&HFFFFFF&\1a&H00&\bord0\shad0}Goodbye!]==],
    ['29'] = [==[{\pos(0,0)\rDefault\an7\blur0\bord0\shad0\1c&HFF0000&\1a&H00&}{\p4}m 0 0 l 3200 0 l 3200 5360 l 0 5360 c{\p0}
{\pos(176,10)\rDefault\an4\blur0\fs16\1c&HFFFFFF&\1a&H00&\bord0\shad0}Hello!
{\pos(168,29)\rDefault\an4\blur0\fs16\1c&HFFFFFF&\1a&H00&\bord0\shad0}Goodbye!]==],
}

--- Lay `widget` out on the fixed screen and paint it into an ASS canvas.
---@param widget Widget
---@return string raw_ass
---@return Size root_size
local function render(widget)
    local owner = RenderOwner()
    WidgetBinding.ensure_initialized():attach(widget, owner)
    owner:set_viewport(Constraints.tight(W, H))
    owner:layout()
    local canvas = AssCanvas()
    owner:paint(canvas)
    return canvas:text(), owner.root.size
end

F.section('flutter/constraints examples: raw ASS vs expected')

local rendered = {}

for _, ex in ipairs(fixtures.examples()) do
    local label = ex.label
    if ex.error then
        F.raises(function() render(ex.build()) end, 'infinite',
            string.format('example %s (%s) must error', label, ex.doc))
    else
        local ok, text, size = pcall(render, ex.build())
        if not ok then
            F.fail(string.format('example %s (%s) raised %s', label, ex.doc, tostring(text)))
        else
            rendered[label] = text
            F.ok(size == Size(W, H), string.format('example %s: screen is %s', label, tostring(size)))
            F.eq(text, EXPECTED[label], string.format('example %s: %s', label, ex.doc))
        end
    end
end

F.section('flutter/constraints examples: shape of the result')

F.test('the doc examples cover the whole file', function()
    F.eq(#fixtures.examples(), 29, 'all 29 examples are present')
    for label, expected in pairs(EXPECTED) do
        F.ok(expected ~= nil, 'example ' .. label .. ' has an expectation')
    end
end)

F.test('Scaffold gives loose constraints, SizedBox.expand forces the size', function()
    -- Example 28: the child sizes itself (blue is only as wide as the Column).
    F.contains(rendered['28'], 'l 512 0', 'example 28 blue box is 64 * 8 wide')
    -- Example 29: SizedBox.expand forces the child to fill the screen.
    F.contains(rendered['29'], 'l 3200 0', 'example 29 blue box is 400 * 8 wide')
end)

F.test('Expanded and Flexible size themselves differently', function()
    -- Both get an equal allocation, but Flexible shrink-wraps to the text.
    F.contains(rendered['26'], 'm 0 1960 l 1600 1960', 'example 26 red is 200 * 8 wide')
    F.contains(rendered['27'], 'm 0 1960 l 1560 1960', 'example 27 red is 195 * 8 wide')
end)
