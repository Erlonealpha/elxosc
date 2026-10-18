-- Stage-2 application composition and ambient providers.

---@diagnostic disable: undefined-field, inject-field, need-check-nil, generic-constraint-mismatch, preferred-local-alias, unused

local F = require('framework')

local constraints_mod = require('layout.constraints')
local render_owner_mod = require('render.render_owner')
local binding_mod = require('widget.binding')
local widget_mod = require('widget.widget')
local text_style_mod = require('text.text_style')
local color_mod = require('foundation.color')
local app_mod = require('widget.app')
local theme_mod = require('widget.theme')
local display_scope_mod = require('widget.display_scope')
local default_text_style_mod = require('widget.default_text_style')
local basic_widgets = require('widget.widgets.basic')
local player_context = require('widget.player_context')

local Constraints = constraints_mod.Constraints
local RenderOwner = render_owner_mod.RenderOwner
local WidgetBinding = binding_mod.WidgetBinding
local StatelessWidget = widget_mod.StatelessWidget
local TextStyle = text_style_mod.TextStyle
local Color = color_mod.Color
local MpvApp = app_mod.MpvApp
local MaterialApp = app_mod.MaterialApp
local WidgetsApp = app_mod.WidgetsApp
local DefaultApp = app_mod.DefaultApp
local Theme = theme_mod.Theme
local ThemeData = theme_mod.ThemeData
local DisplayScope = display_scope_mod.DisplayScope
local DisplaySnapshot = display_scope_mod.DisplaySnapshot
local DefaultTextStyle = default_text_style_mod.DefaultTextStyle
local PlayerStore = player_context.PlayerStore
local PlayerProvider = player_context.PlayerProvider
local Text = basic_widgets.Text

local function mount(widget)
    local owner = RenderOwner()
    local binding = WidgetBinding(widget, owner)
    owner:set_viewport(Constraints.loose(1000, 1000))
    owner:layout()
    return owner, binding
end

local function child_of(element)
    return element:element_children()[1]
end

local function composition_chain(root_element)
    local result = { root_element }
    local current = root_element
    for _ = 1, 8 do
        current = child_of(current)
        result[#result + 1] = current
    end
    return result
end

F.section('app composition: ambient chain')

F.test('direct and aggregate modules preserve application class identity', function()
    local api = require('widget')
    F.eq(api.MpvApp, MpvApp, 'MpvApp identity')
    F.eq(api.MaterialApp, MaterialApp, 'MaterialApp identity')
    F.eq(api.WidgetsApp, WidgetsApp, 'WidgetsApp identity')
    F.eq(api.DefaultApp, DefaultApp, 'DefaultApp identity')
    F.eq(api.Theme, Theme, 'Theme identity')
    F.eq(api.DisplayScope, DisplayScope, 'DisplayScope identity')
    F.eq(api.DefaultTextStyle, DefaultTextStyle, 'DefaultTextStyle identity')
end)

F.test('DefaultApp composes main, extension and popup in order', function()
    local options = {
        main = Text('main'),
        extension = Text('extension'),
        popup = Text('popup'),
    }
    local app = DefaultApp(options)
    local children = app:child_widgets()
    local stack = app:build()
    F.eq(#children, 3, 'all application surfaces are children')
    F.eq(children[1], options.main, 'main is first')
    F.eq(children[2], options.extension, 'extension is second')
    F.eq(children[3], options.popup, 'popup is last')
    F.eq(stack.children[1].child, options.main, 'Stack keeps main first')
    F.eq(stack.children[2].child, options.extension, 'Stack keeps extension second')
    F.eq(stack.children[3].child, options.popup, 'Stack keeps popup last')
    F.ok(app:child_widgets() ~= children, 'child list is fresh')
    F.raises(function()
        DefaultApp({ main = 'not a widget' --[[@as any]] })
    end, 'TypeError', 'DefaultApp rejects invalid children')
    local binding = WidgetBinding(MpvApp({ default_app = app }), RenderOwner())
    local chain = composition_chain(binding.root_element)
    F.eq(chain[9].widget.__class, DefaultApp, 'DefaultApp is the ambient child')
end)

F.test('MpvApp mounts the documented ambient parent chain', function()
    local observed = {}
    local Probe = nil
    Probe = require('elxlibs.std').class.new('test.AppCompositionProbe', { StatelessWidget })
    function Probe:build(context)
        observed.theme = Theme.data_of(context)
        observed.player = PlayerProvider.snapshot_of(context)
        observed.display = DisplayScope.snapshot_of(context)
        observed.text_style = DefaultTextStyle.style_of(context)
        return nil
    end

    local store = PlayerStore({ value = 1 })
    local theme = ThemeData({ colors = { accent = Color.rgba255(1, 2, 3) } })
    local display = DisplaySnapshot({
        width = 640,
        height = 360,
        initialized = true,
        generation = 4,
    })
    local default_style = TextStyle({ font_size = 20 })
    local probe = Probe()
    local _, binding = mount(MpvApp({
        child = probe,
        theme = theme,
        player_store = store,
        display_snapshot = display,
        default_text_style = default_style,
    }))

    local chain = composition_chain(binding.root_element)
    F.eq(chain[1].widget.__class, MpvApp, 'MpvApp root')
    F.eq(chain[2].widget.__class, MaterialApp, 'MaterialApp child')
    F.eq(chain[3].widget.__class, WidgetsApp, 'WidgetsApp child')
    F.eq(chain[4].widget.__class, Theme, 'Theme parent')
    F.eq(chain[5].widget.__class, player_context.PlayerScope, 'PlayerScope parent')
    F.eq(chain[6].widget.__class, PlayerProvider, 'PlayerProvider implementation')
    F.eq(chain[7].widget.__class, DisplayScope, 'DisplayScope parent')
    F.eq(chain[8].widget.__class, DefaultTextStyle, 'DefaultTextStyle parent')
    F.eq(chain[9].widget.__class, DefaultApp, 'DefaultApp application child')
    F.ok(observed.theme == theme, 'Theme is inherited')
    F.eq(observed.player.value, 1, 'PlayerSnapshot is inherited')
    F.ok(observed.display == display, 'DisplaySnapshot is inherited')
    F.ok(observed.text_style == default_style, 'DefaultTextStyle is inherited')
end)

F.test('PlayerScope updates listening descendants without replacing the chain', function()
    local builds = 0
    local observed = nil
    local Probe = require('elxlibs.std').class.new('test.AppPlayerProbe', { StatelessWidget })
    function Probe:build(context)
        builds = builds + 1
        observed = PlayerProvider.snapshot_of(context).value
        return nil
    end

    local store = PlayerStore({ value = 1 })
    local _, binding = mount(MpvApp({
        child = Probe(),
        player_store = store,
        display_snapshot = DisplaySnapshot({ width = 10, height = 10 }),
    }))
    local player_element = composition_chain(binding.root_element)[5]
    store:replace({ value = 2 })
    binding:flush_build()
    F.eq(observed, 2, 'new PlayerSnapshot reached the descendant')
    F.eq(builds, 2, 'listening descendant rebuilt once')
    F.ok(binding.root_element.mounted, 'root remains mounted')
    F.ok(player_element.mounted, 'PlayerScope State remains mounted')
end)

F.test('DisplayScope replacement updates dimensions and generation', function()
    local observed = nil
    local Probe = require('elxlibs.std').class.new('test.AppDisplayProbe', { StatelessWidget })
    function Probe:build(context)
        local snapshot = DisplayScope.snapshot_of(context)
        observed = { snapshot.width, snapshot.height, snapshot.generation }
        return nil
    end

    local first = DisplaySnapshot({ width = 100, height = 50, initialized = true, generation = 1 })
    local probe = Probe()
    local _, binding = mount(MpvApp({
        child = probe,
        display_snapshot = first,
    }))
    binding:set_root_widget(MpvApp({
        child = probe,
        display_snapshot = DisplaySnapshot({
            width = 200,
            height = 80,
            initialized = true,
            generation = 2,
        }),
    }))
    binding:flush_build()
    F.eq(observed[1], 200, 'updated width')
    F.eq(observed[2], 80, 'updated height')
    F.eq(observed[3], 2, 'updated generation')
end)

F.test('ambient constructors validate options without mutating callers', function()
    local colors = { accent = Color.rgba255(1, 2, 3) }
    local theme = ThemeData({ colors = colors })
    colors.accent = Color.rgba255(4, 5, 6)
    F.eq(theme.colors.accent, Color.rgba255(1, 2, 3), 'ThemeData copies colors')
    F.raises(function()
        ThemeData({ colors = { accent = 'not a color' } --[[@as any]] })
    end, 'TypeError', 'ThemeData rejects invalid colors')
    F.raises(function()
        DisplaySnapshot({ width = -1, height = 1 })
    end, 'ValueError', 'negative display width')
    F.raises(function()
        DisplaySnapshot({ width = 1, height = 1, generation = 1.5 })
    end, 'ValueError', 'fractional display generation')
    F.raises(function()
        MpvApp({ child = nil })
    end, 'TypeError', 'missing app child')
end)
