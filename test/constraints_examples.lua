-- Fixtures for `test_constraints_examples.lua`: the 29 examples from
-- https://docs.flutter.dev/ui/layout/constraints, expressed with elxosc's
-- widget layer.
--
-- Each entry mirrors the DartPad snippet as closely as the widget set allows.
-- The examples that use `Scaffold` (28/29) are modelled with an `Align` set to
-- the top-left, because the doc's point is that the Scaffold hands its child
-- *loose* constraints ("it can be any size it wants, but not bigger than the
-- screen").
---@diagnostic disable: undefined-field, call-non-callable, need-check-nil

local geometry = require 'foundation.geometry'
local color = require 'foundation.color'
local text_style = require 'text.text_style'
local constraints_mod = require 'layout.constraints'
---@type elxwidgets_layout
local lay = require 'widget.widgets.layout'
local basic = require 'widget.widgets.basic'

local Offset, EdgeInsets = geometry.Offset, geometry.EdgeInsets
local Color = color.Color
local TextStyle = text_style.TextStyle
local Constraints = constraints_mod.Constraints
local Center, SizedBox, Container, Row, Column, Expanded, Flexible, Align =
    lay.Center, lay.SizedBox, lay.Container, lay.Row, lay.Column, lay.Expanded,
    lay.Flexible, lay.Align
local ConstrainedBox, LimitedBox, UnconstrainedBox, OverflowBox, FittedBox =
    lay.ConstrainedBox, lay.LimitedBox, lay.UnconstrainedBox, lay.OverflowBox, lay.FittedBox
local Text = basic.Text

local red = Color.rgba255(0xFF, 0x00, 0x00)
local green = Color.rgba255(0x00, 0xFF, 0x00)
local blue = Color.rgba255(0x00, 0x00, 0xFF)

local big = function(text)
    return Text(text, { style = TextStyle({ font_size = 30 }) })
end

-- A 70..150 box, as used by examples 9-12.
local box_70_150 = function() return Constraints(70, 150, 70, 150) end

---@return { label: string, doc: string, error: boolean?, build: fun(): Widget }[]
local function examples()
    return {
        {
            label = '1', doc = 'Container(color: red)',
            build = function() return Container({ color = red }) end,
        },
        {
            label = '2', doc = 'Container(width: 100, height: 100, color: red)',
            build = function() return Container({ width = 100, height = 100, color = red }) end,
        },
        {
            label = '3', doc = 'Center(child: Container(width: 100, height: 100, color: red))',
            build = function() return Center(Container({ width = 100, height = 100, color = red })) end,
        },
        {
            label = '4', doc = 'Align(bottomRight, child: Container(100x100))',
            build = function()
                return Align(Container({ width = 100, height = 100, color = red }),
                    { alignment = Offset(1, 1) })
            end,
        },
        {
            label = '5', doc = 'Center(child: Container(width/height: infinity, color: red))',
            build = function()
                return Center(Container({ width = math.huge, height = math.huge, color = red }))
            end,
        },
        {
            label = '6', doc = 'Center(child: Container(color: red))',
            build = function() return Center(Container({ color = red })) end,
        },
        {
            label = '7', doc = 'Center(child: Container(color: red, child: Container(green, 30x30)))',
            build = function()
                return Center(Container({
                    color = red,
                    child = Container({ color = green, width = 30, height = 30 }),
                }))
            end,
        },
        {
            label = '8', doc = 'Center(child: Container(padding: 20, color: red, child: green 30x30))',
            build = function()
                return Center(Container({
                    padding = EdgeInsets.all(20),
                    color = red,
                    child = Container({ color = green, width = 30, height = 30 }),
                }))
            end,
        },
        {
            label = '9', doc = 'ConstrainedBox(70..150, child: Container(10x10))',
            build = function()
                return ConstrainedBox({
                    constraints = box_70_150(),
                    child = Container({ width = 10, height = 10, color = red }),
                })
            end,
        },
        {
            label = '10', doc = 'Center(child: ConstrainedBox(70..150, child: Container(10x10)))',
            build = function()
                return Center(ConstrainedBox({
                    constraints = box_70_150(),
                    child = Container({ width = 10, height = 10, color = red }),
                }))
            end,
        },
        {
            label = '11', doc = 'Center(child: ConstrainedBox(70..150, child: Container(1000x1000)))',
            build = function()
                return Center(ConstrainedBox({
                    constraints = box_70_150(),
                    child = Container({ width = 1000, height = 1000, color = red }),
                }))
            end,
        },
        {
            label = '12', doc = 'Center(child: ConstrainedBox(70..150, child: Container(100x100)))',
            build = function()
                return Center(ConstrainedBox({
                    constraints = box_70_150(),
                    child = Container({ width = 100, height = 100, color = red }),
                }))
            end,
        },
        {
            label = '13', doc = 'UnconstrainedBox(child: Container(20x50))',
            build = function()
                return UnconstrainedBox({ child = Container({ width = 20, height = 50, color = red }) })
            end,
        },
        {
            label = '14', doc = 'UnconstrainedBox(child: Container(4000x50)) // overflow',
            build = function()
                return UnconstrainedBox({ child = Container({ width = 4000, height = 50, color = red }) })
            end,
        },
        {
            label = '15', doc = 'OverflowBox(0..infinity, child: Container(4000x50))',
            build = function()
                return OverflowBox({
                    min_width = 0, min_height = 0,
                    max_width = math.huge, max_height = math.huge,
                    child = Container({ width = 4000, height = 50, color = red }),
                })
            end,
        },
        {
            label = '16', doc = 'UnconstrainedBox(child: Container(width: infinity, height: 100))',
            error = true,
            build = function()
                return UnconstrainedBox({ child = Container({ width = math.huge, height = 100, color = red }) })
            end,
        },
        {
            label = '17', doc = 'UnconstrainedBox(child: LimitedBox(maxWidth: 100, child: Container(inf x 100)))',
            build = function()
                return UnconstrainedBox({
                    child = LimitedBox({
                        max_width = 100,
                        child = Container({ width = math.huge, height = 100, color = red }),
                    }),
                })
            end,
        },
        {
            label = '18', doc = 'FittedBox(child: Text(some example text, 30))',
            build = function() return FittedBox(big('Some Example Text.')) end,
        },
        {
            label = '19', doc = 'Center(child: FittedBox(child: Text(some example text, 30)))',
            build = function() return Center(FittedBox(big('Some Example Text.'))) end,
        },
        {
            label = '20', doc = 'Center(child: FittedBox(child: Text(very large text, 30)))',
            build = function()
                return Center(FittedBox(big('This is some very very very large text that is too big '
                    .. 'to fit a regular screen in a single line.')))
            end,
        },
        {
            label = '21', doc = 'Center(child: Text(very large text, 30)) // soft wrap',
            build = function()
                return Center(big('This is some very very very large text that is too big '
                    .. 'to fit a regular screen in a single line.'))
            end,
        },
        {
            label = '22', doc = 'FittedBox(child: Container(width: infinity, height: 20))',
            error = true,
            build = function()
                return FittedBox(Container({ width = math.huge, height = 20, color = red }))
            end,
        },
        {
            label = '23', doc = 'Row(children: [Container(Text(Hello!)), Container(Text(Goodbye!))])',
            build = function()
                return Row({ children = {
                    Container({ color = red, child = big('Hello!') }),
                    Container({ color = green, child = big('Goodbye!') }),
                } })
            end,
        },
        {
            label = '24', doc = 'Row(children: [Container(long text), Container(Goodbye!)]) // overflow',
            build = function()
                return Row({ children = {
                    Container({ color = red, child = big("This is a very long text that won't fit the line.") }),
                    Container({ color = green, child = big('Goodbye!') }),
                } })
            end,
        },
        {
            label = '25', doc = 'Row(children: [Expanded(Center(Container(long text))), Container(Goodbye!)])',
            build = function()
                return Row({ children = {
                    Expanded(Center(Container({
                        color = red,
                        child = big("This is a very long text that won't fit the line."),
                    }))),
                    Container({ color = green, child = big('Goodbye!') }),
                } })
            end,
        },
        {
            label = '26', doc = 'Row(children: [Expanded(Container(long text)), Expanded(Container(Goodbye!))])',
            build = function()
                return Row({ children = {
                    Expanded(Container({
                        color = red,
                        child = big("This is a very long text that won't fit the line."),
                    })),
                    Expanded(Container({ color = green, child = big('Goodbye!') })),
                } })
            end,
        },
        {
            label = '27', doc = 'Row(children: [Flexible(Container(long text)), Flexible(Container(Goodbye!))])',
            build = function()
                return Row({ children = {
                    Flexible(Container({
                        color = red,
                        child = big("This is a very long text that won't fit the line."),
                    })),
                    Flexible(Container({ color = green, child = big('Goodbye!') })),
                } })
            end,
        },
        {
            label = '28', doc = 'Scaffold(child: Container(blue, child: Column(Hello!, Goodbye!)))',
            build = function()
                return Align(Container({
                    color = blue,
                    child = Column({ children = { Text('Hello!'), Text('Goodbye!') } }),
                }), { alignment = Offset(0, 0) })
            end,
        },
        {
            label = '29', doc = 'Scaffold(child: SizedBox.expand(child: Container(blue, Column)))',
            build = function()
                return Align(SizedBox.expand({
                    child = Container({
                        color = blue,
                        child = Column({ children = { Text('Hello!'), Text('Goodbye!') } }),
                    }),
                }), { alignment = Offset(0, 0) })
            end,
        },
    }
end

return { examples = examples }
