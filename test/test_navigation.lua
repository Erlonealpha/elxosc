-- Stage-4 declaration-driven Page/Route/Navigator runtime tests.

---@diagnostic disable: undefined-field, inject-field, need-check-nil, generic-constraint-mismatch, preferred-local-alias, unused, call-non-callable

local F = require('framework')
local std = require('elxlibs.std')

local constraints_mod = require('layout.constraints')
local render_owner_mod = require('render.render_owner')
local binding_mod = require('widget.binding')
local widget_mod = require('widget.widget')
local navigation_mod = require('player.navigation')
local player = require('player')
local pages_api = require('player.pages')

local Constraints = constraints_mod.Constraints
local RenderOwner = render_owner_mod.RenderOwner
local WidgetBinding = binding_mod.WidgetBinding
local State = require('widget.state').State
local StatefulWidget = widget_mod.StatefulWidget
local Page = navigation_mod.Page
local Route = navigation_mod.Route
local RouteResult = navigation_mod.RouteResult
local Navigator = navigation_mod.Navigator
local NavigatorState = navigation_mod.NavigatorState

local function mount(widget)
    local owner = RenderOwner()
    local binding = WidgetBinding(widget, owner)
    owner:set_viewport(Constraints.tight(400, 240))
    owner:layout()
    return owner, binding
end

local function first_content_state(navigator_state)
    local navigator_stack = navigator_state.context.child
    local route_content = navigator_stack.children[1]
    local boundary = route_content.child
    local content_stack = boundary.child
    return content_stack.children[1].state
end

local ProbeState = std.class.new('test.NavigationProbeState', { State })
function ProbeState:__init()
    ---@diagnostic disable-next-line: param-type-mismatch
    std.super(ProbeState, self, State).__init(self)
    self.dispose_count = 0
end

function ProbeState:build()
    return nil
end

function ProbeState:dispose()
    self.dispose_count = self.dispose_count + 1
    if self.widget.on_dispose then
        self.widget.on_dispose(self)
    end
end

local Probe = std.class.new('test.NavigationProbe', { StatefulWidget })
function Probe:__init(options)
    options = options or {}
    self.key = options.key
    self.on_dispose = options.on_dispose
end

function Probe:create_state()
    return ProbeState()
end

local AlternatePage = std.class.new('test.AlternatePage', { Page })

F.section('navigation: Page, Route and Navigator runtime')

F.test('aggregates preserve exact navigation class identities', function()
    F.eq(player.Page, Page, 'player Page identity')
    F.eq(player.Route, Route, 'player Route identity')
    F.eq(player.RouteResult, RouteResult, 'player RouteResult identity')
    F.eq(player.Navigator, Navigator, 'player Navigator identity')
    F.eq(player.NavigatorState, NavigatorState, 'player NavigatorState identity')
    F.eq(pages_api.Page, Page, 'pages Page identity')
    F.eq(pages_api.Route, Route, 'pages Route identity')
    F.eq(pages_api.Navigator, Navigator, 'pages Navigator identity')
end)

F.test('Page construction is descriptor-only and copies descriptor tables', function()
    local arguments = { section = 'audio' }
    local barrier = { dismissible = true }
    local builder_calls = 0
    local page = Page({
        key = 'settings',
        name = '/settings',
        arguments = arguments,
        barrier_config = barrier,
        builder = function()
            builder_calls = builder_calls + 1
            return nil
        end,
    })
    arguments.section = 'changed'
    barrier.dismissible = false
    F.eq(builder_calls, 0, 'Page construction does not execute builder')
    F.eq(page.arguments.section, 'audio', 'arguments copied')
    F.eq(page.barrier_config.dismissible, true, 'barrier config copied')
    F.eq(page.route_kind, 'page', 'default route kind')
    F.eq(page.opaque, true, 'default opaque setting')
    F.raises(function()
        Page({ builder = function() return nil end })
    end, 'Page.key must be provided', 'Page requires a stable key')
end)

F.test('Navigator rejects duplicate Page keys', function()
    local first = Page({ key = 'duplicate', builder = function() return nil end })
    local second = Page({ key = 'duplicate', builder = function() return nil end })
    F.raises(function()
        Navigator({ pages = { first, second } })
    end, 'Navigator.pages keys must be unique', 'duplicate Page key')
end)

F.test('route builder runs only in a mounted route-content build context', function()
    local observed_context = nil
    local observed_phase = nil
    local page = Page({
        key = 'home',
        builder = function(context)
            observed_context = context
            observed_phase = context._lifecycle_phase
            return nil
        end,
    })
    local route = Route(page)
    F.raises(function()
        ---@diagnostic disable-next-line: param-type-mismatch
        route:build_content({ mounted = true, _lifecycle_phase = 'idle' })
    end, 'mounted route-content BuildContext', 'builder rejects non-build context')
    F.eq(observed_context, nil, 'invalid direct build did not call builder')

    local _, binding = mount(Navigator({ pages = { page } }))
    F.ok(observed_context ~= nil, 'mounted route-content called builder')
    F.ok(observed_context.mounted, 'builder context is mounted')
    F.eq(observed_phase, 'build', 'builder context is in build phase')
    binding:dispose()
end)

F.test('same Page class and key reuses Route and page State', function()
    local builds = 0
    local function make_page(key)
        return Page({
            key = key,
            builder = function()
                builds = builds + 1
                return Probe({ key = 'content' })
            end,
        })
    end
    local first_page = make_page('same')
    local _, binding = mount(Navigator({ pages = { first_page } }))
    local state = binding.root_element.state --[[@as NavigatorState]]
    local old_route = state.routes[1]
    local content_state = first_content_state(state)
    F.eq(builds, 1, 'initial builder call')

    binding:set_root_widget(Navigator({ pages = { make_page('same') } }))
    local new_route = state.routes[1]
    F.ok(old_route == new_route, 'matching Page identity reuses Route')
    F.ok(content_state == first_content_state(state),
        'matching route content reuses State')
    F.eq(builds, 2, 'updated descriptor rebuilds content')
    F.eq(old_route.lifecycle, 'current', 'reused route remains current')
    binding:dispose()
end)

F.test('Page key or class changes dispose the old Route before replacement survives', function()
    local disposed = 0
    local function page_of(page_class, key)
        return page_class({
            key = key,
            builder = function()
                return Probe({
                    key = 'content',
                    on_dispose = function()
                        disposed = disposed + 1
                    end,
                })
            end,
        })
    end
    local _, binding = mount(Navigator({ pages = { page_of(Page, 'first') } }))
    local state = binding.root_element.state --[[@as NavigatorState]]
    local old_route = state.routes[1]

    binding:set_root_widget(Navigator({ pages = { page_of(Page, 'second') } }))
    F.ok(state.routes[1] ~= old_route, 'key change creates a new Route')
    F.eq(old_route.lifecycle, 'disposed', 'key change disposes old Route')
    F.eq(disposed, 1, 'old page State disposed once')

    local class_old = state.routes[1]
    binding:set_root_widget(Navigator({ pages = { page_of(AlternatePage, 'second') } }))
    F.ok(state.routes[1] ~= class_old, 'Page class change creates a new Route')
    F.eq(class_old.lifecycle, 'disposed', 'class change disposes old Route')
    F.eq(disposed, 2, 'class replacement disposes one page State')
    binding:dispose()
end)

F.test('route removal disposes page State before Route and completes its result', function()
    local events = {}
    local page = Page({
        key = 'removable',
        builder = function()
            return Probe({
                on_dispose = function()
                    events[#events + 1] = 'state.dispose'
                end,
            })
        end,
        on_did_pop = function()
            events[#events + 1] = 'route.did_pop'
        end,
        on_dispose = function()
            events[#events + 1] = 'route.dispose'
        end,
    })
    local _, binding = mount(Navigator({ pages = { page } }))
    local state = binding.root_element.state --[[@as NavigatorState]]
    local route = state.routes[1]
    local result = route.result
    binding:set_root_widget(Navigator({ pages = {} }))

    F.eq(events[1], 'route.did_pop', 'pop callback precedes removal')
    F.eq(events[2], 'state.dispose', 'page State disposes before Route')
    F.eq(events[3], 'route.dispose', 'Route disposes after page subtree')
    F.eq(route.lifecycle, 'disposed', 'removed Route reaches disposed lifecycle')
    F.ok(result:is_complete(), 'removed Route completes result handle')
    F.eq(result:value(), nil, 'declarative removal completes with nil')
    binding:dispose()
end)

F.test('push and pop mutate one authoritative page list and return route result', function()
    local home = Page({ key = 'home', builder = function() return nil end })
    local pushed = Page({ key = 'pushed', builder = function() return nil end })
    local navigator = Navigator({ pages = { home } })
    local _, binding = mount(navigator)
    local state = binding.root_element.state --[[@as NavigatorState]]
    local home_route = state:current_route()
    F.eq(#navigator.pages, 1, 'Navigator descriptor remains immutable')

    local completed = nil
    local result = state:push(pushed)
    result:on_complete(function(value)
        completed = value
    end)
    F.eq(#state.pages, 2, 'push updates state page list')
    F.ok(state:current_route() ~= home_route, 'push creates current Route')
    F.ok(state.routes[1].is_first, 'first route flag')
    F.ok(not state.routes[1].is_current, 'previous route becomes inactive')
    F.ok(state.routes[2].is_current, 'pushed route is current')
    binding:flush_build()

    F.ok(state:pop('selected'), 'pop accepts current Route')
    F.eq(#state.pages, 1, 'pop removes from state page list')
    F.ok(not result:is_complete(), 'result waits for content disposal')
    binding:flush_build()
    F.ok(result:is_complete(), 'pop result completes after removal')
    F.eq(result:value(), 'selected', 'result stores route-specific value')
    F.eq(completed, 'selected', 'result callback receives only its value')
    F.ok(state:current_route() == home_route, 'home Route remains mounted and current')
    F.ok(not state:pop(), 'the first Route cannot be popped')
    binding:dispose()
end)
