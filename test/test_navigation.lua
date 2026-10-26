-- N3 Page/Route/Navigator: one Theatre, reconciliation, result and popup barrier.

---@diagnostic disable: undefined-field, inject-field, need-check-nil, unused, generic-constraint-mismatch

local F = require('framework')
local std = require('elxlibs.std')

local constraints_mod = require('layout.constraints')
local text_layout = require('text.text_layout')
local render_owner = require('render.render_owner')
local binding_mod = require('widget.binding')
local widget_mod = require('widget.widget')
local basic_widgets = require('widget.widgets.basic')
local navigation_mod = require('widget.navigation')

local Constraints = constraints_mod.Constraints
local TextLayout = text_layout.TextLayout
local RenderOwner = render_owner.RenderOwner
local WidgetBinding = binding_mod.WidgetBinding
local StatefulWidget = widget_mod.StatefulWidget
local State = require('widget.state').State
local Text = basic_widgets.Text
local Page = navigation_mod.Page
local PopupPage = navigation_mod.PopupPage
local Navigator = navigation_mod.Navigator
local NavigatorScope = navigation_mod.NavigatorScope
local FixedLayout = std.class.new('test.navigation.FixedLayout', { TextLayout })

function FixedLayout:line_width(line, style)
    return #line * style.font_size * 0.5
end

text_layout.set_default(FixedLayout())

local function mount(widget)
    local owner = RenderOwner()
    local binding = WidgetBinding.ensure_initialized():attach(widget, owner)
    owner:set_viewport(Constraints.tight(320, 180))
    owner:layout()
    return owner, binding
end

local function find_widget_element(element, widget_class)
    if element == nil then
        return nil
    end
    if element.widget and element.widget.__class == widget_class then
        return element
    end
    for _, child in ipairs(element:element_children()) do
        local found = find_widget_element(child, widget_class)
        if found then
            return found
        end
    end
    return nil
end

local function route_page(key, text, options)
    options = options or {}
    options.key = key
    options.builder = function()
        return Text(text)
    end
    return Page(options)
end

F.section('navigation: Page and Route')

F.test('Page construction is lazy and validates stable identity', function()
    local builds = 0
    local page = Page({
        key = 'home',
        builder = function()
            builds = builds + 1
            return Text('home')
        end,
    })
    F.eq(builds, 0, 'Page construction does not run builder')
    F.eq(page.opaque, true, 'normal Page is opaque')
    F.eq(page.maintain_state, true, 'normal Page maintains state')
    F.raises(function()
        Page({ builder = function() return Text('bad') end })
    end, 'Page.key', 'Page requires a key')
end)

F.test('Navigator mounts initial Page content once in one Theatre', function()
    local builds = 0
    local navigator_from_context
    local page = Page({
        key = 'home',
        builder = function(context)
            builds = builds + 1
            navigator_from_context = Navigator.of(context)
            return Text('home')
        end,
    })
    local owner, binding = mount(Navigator({ pages = { page } }))
    F.eq(builds, 1, 'initial route builder runs once')
    local navigator_element = find_widget_element(binding.root_element, Navigator)
    F.ok(navigator_element ~= nil, 'Navigator is mounted')
    if navigator_element == nil then
        return
    end
    local state = navigator_element.state
    F.eq(navigator_from_context, state, 'Page builder receives Navigator context')
    F.eq(#state.routes, 1, 'one initial route exists')
    F.ok(state.routes[1].content_entry:is_mounted(), 'route content is mounted')
    F.eq(owner.root ~= nil, true, 'Navigator uses the existing render root')
end)

F.test('push and pop preserve the lower route and complete result once', function()
    local disposed = 0
    local home = route_page('home', 'home', { on_dispose = function() disposed = disposed + 1 end })
    local owner, binding = mount(Navigator({ pages = { home } }))
    local navigator_element = find_widget_element(binding.root_element, Navigator)
    local state = navigator_element.state
    local route = state:push(route_page('details', 'details'))
    binding:flush_build()
    owner:layout()
    F.eq(#state.routes, 2, 'push adds one route')
    local result_value
    local result_calls = 0
    route.result:add_listener(function(value)
        result_calls = result_calls + 1
        result_value = value
    end)
    F.ok(state:pop('done'), 'pop accepts a current route')
    F.eq(route.status, 'popping', 'route waits for entry disposal')
    binding:flush_build()
    owner:layout()
    F.eq(route.status, 'disposed', 'route disposes after content unmount')
    F.eq(result_calls, 1, 'result completes once')
    F.eq(result_value, 'done', 'result carries pop value')
    F.eq(disposed, 0, 'stable lower route is not disposed')
    F.eq(#state.routes, 1, 'pop leaves the lower route')
end)

F.test('same Page class and key reconciles without remounting State', function()
    local mounts = 0
    local ProbeState = std.class.new('test.navigation.ProbeState', { State })
    function ProbeState:init_state()
        mounts = mounts + 1
    end
    function ProbeState:build()
        return Text(self.widget.label)
    end
    local Probe = std.class.new('test.navigation.Probe', { StatefulWidget })
    function Probe:__init(options)
        self.key = options.key
        self.label = options.label
    end
    function Probe:create_state()
        return ProbeState()
    end

    local function probe_page(label)
        return Page({ key = 'stable', builder = function() return Probe({ key = 'probe', label = label }) end })
    end
    local owner, binding = mount(Navigator({ pages = { probe_page('one') } }))
    local navigator_element = find_widget_element(binding.root_element, Navigator)
    local state = navigator_element.state
    local first_probe = find_widget_element(binding.root_element, Probe)
    state:set_pages({ probe_page('two') })
    binding:flush_build()
    owner:layout()
    local second_probe = find_widget_element(binding.root_element, Probe)
    F.eq(mounts, 1, 'matching route and content State are reused')
    F.eq(first_probe, second_probe, 'content Element remains mounted')
    F.eq(second_probe.widget.label, 'two', 'matching Page updates its content')
end)

F.test('duplicate Page keys and empty pop are rejected or ignored', function()
    local first = route_page('same', 'one')
    F.raises(function()
        Navigator({ pages = { first, route_page('same', 'two') } })
    end, 'duplicate keys', 'duplicate initial keys fail')
    local _, binding = mount(Navigator({ pages = { first } }))
    local navigator_element = find_widget_element(binding.root_element, Navigator)
    F.ok(not navigator_element.state:pop(), 'root route cannot be popped')
end)

F.test('ESC pops a route and ignores input when no route can pop', function()
    local _, binding = mount(Navigator({ pages = {
        route_page('home', 'home'),
        route_page('child', 'child'),
    } }))
    local navigator_element = find_widget_element(binding.root_element, Navigator)
    local state = navigator_element.state
    F.ok(state:handle_key({ key = 'ESC', type = 'down' }), 'ESC pops the current route')
    binding:flush_build()
    F.eq(#state.routes, 1, 'ESC removed the child route')
    F.ok(not state:handle_key({ key = 'ESC', type = 'down' }),
        'ESC is ignored with no route to pop')
end)

F.test('PopupPage creates barrier/content entries and dismisses through barrier', function()
    local popup = PopupPage({
        key = 'popup',
        barrier_dismissible = true,
        builder = function()
            return Text('popup')
        end,
    })
    local owner, binding = mount(Navigator({ pages = { route_page('home', 'home') } }))
    local navigator_element = find_widget_element(binding.root_element, Navigator)
    local state = navigator_element.state
    local route = state:push_popup(popup)
    binding:flush_build()
    owner:layout()
    F.ok(route.barrier_entry:is_mounted(), 'popup barrier is mounted')
    F.ok(route.content_entry:is_mounted(), 'popup content is mounted')
    F.eq(#route:entries(), 2, 'popup owns a barrier/content pair')
    local barrier_element = find_widget_element(binding.root_element, navigation_mod.ModalBarrier)
    F.ok(barrier_element ~= nil, 'barrier is a real Widget')
    if barrier_element then
        F.ok(barrier_element.widget.dismissible, 'barrier is dismissible')
        barrier_element.widget.on_dismiss()
    end
    binding:flush_build()
    owner:layout()
    F.eq(#state.routes, 1, 'barrier dismissal pops the popup')
    F.eq(route.status, 'disposed', 'popup route is disposed')
end)

F.test('Navigator aggregate exports preserve direct class identity', function()
    local widgets = require 'widget'
    F.eq(widgets.Navigator, Navigator, 'Navigator identity')
    F.eq(widgets.Page, Page, 'Page identity')
    F.eq(widgets.PopupRoute, navigation_mod.PopupRoute, 'PopupRoute identity')
    F.eq(widgets.Navigator.of, Navigator.of, 'Navigator lookup identity')
end)

F.test('NavigatorState can be connected to a host key callback', function()
    local _, binding = mount(Navigator({ pages = {
        route_page('home', 'home'),
        route_page('child', 'child'),
    } }))
    local navigator_element = find_widget_element(binding.root_element, Navigator)
    local state = navigator_element.state
    local handled = state:handle_key({ key = 'ESC', type = 'press' })
    F.ok(handled, 'host ESC callback is handled while a child route exists')
    binding:flush_build()
    F.ok(not state:handle_key({ key = 'ESC', type = 'press' }),
        'host ESC callback is not handled after returning to root')
end)
