-- Host-independent declaration-to-runtime navigation for player composition.
--
-- Page is a descriptor. Route is the runtime record. NavigatorState owns the
-- one mutable page list and reconciles it into Route records; route builders
-- are reached only from the mounted RouteContent widget below.

local std = require 'elxlibs.std'
local stack_mod = require 'widget.widgets.stack'
local state_mod = require 'widget.state'
local widget_mod = require 'widget.widget'

local raise = std.raise
local Stack = stack_mod.Stack
local State = state_mod.State
local StatelessWidget = widget_mod.StatelessWidget
local StatefulWidget = widget_mod.StatefulWidget

local M = {}
local ROUTE_CONTENT_TOKEN = {}

---@alias RouteKind
---| 'page'
---| 'popup'

---@alias RouteLifecycle
---| 'created'
---| 'installed'
---| 'active'
---| 'current'
---| 'inactive'
---| 'popping'
---| 'removed'
---| 'disposed'

---@class PageOptions
---@field key any?
---@field name string?
---@field arguments any?
---@field builder fun(context: BuildContext): Widget?
---@field route_kind RouteKind?
---@field opaque boolean?
---@field barrier_config table?
---@field surface_policy any?
---@field transition_policy any?
---@field maintain_state boolean?
---@field input_policy PageInputPolicy?
---@field can_pop (boolean|fun(route: Route): boolean?)?
---@field on_pop (fun(route: Route, result: any?): boolean?)?
---@field on_did_install fun(route: Route)?
---@field on_did_push fun(route: Route)?
---@field on_did_pop fun(route: Route, result: any?)?
---@field on_did_pop_next fun(route: Route)?
---@field on_did_change_next fun(route: Route, next_route: Route?)?
---@field on_did_change_previous fun(route: Route, previous_route: Route?)?
---@field on_did_replace fun(route: Route, old_page: Page)?
---@field on_dispose fun(route: Route)?

---@class Page : std.object
---@field key any?
---@field name string?
---@field arguments any?
---@field builder fun(context: BuildContext): Widget?
---@field route_kind RouteKind
---@field opaque boolean
---@field barrier_config table?
---@field surface_policy any?
---@field transition_policy any?
---@field maintain_state boolean?
---@field input_policy PageInputPolicy?
---@field can_pop (boolean|fun(route: Route): boolean?)?
---@field on_pop (fun(route: Route, result: any?): boolean?)?
---@field on_did_install fun(route: Route)?
---@field on_did_push fun(route: Route)?
---@field on_did_pop fun(route: Route, result: any?)?
---@field on_did_pop_next fun(route: Route)?
---@field on_did_change_next fun(route: Route, next_route: Route?)?
---@field on_did_change_previous fun(route: Route, previous_route: Route?)?
---@field on_did_replace fun(route: Route, old_page: Page)?
---@field on_dispose fun(route: Route)?
---@overload fun(options: PageOptions): self
local Page = std.class.new('Page', {})

---@alias PageInputPolicy
---| 'passive'
---| 'interactive'
---| 'exclusive'

---@param value any
---@return any
local function copy_descriptor_value(value)
    if type(value) ~= 'table' then
        return value
    end
    local result = {}
    for key, item in pairs(value) do
        result[key] = item
    end
    return result
end

---@param options PageOptions
function Page:__init(options)
    if type(options) ~= 'table' then
        raise(std.TypeError('Page expects an options table'))
    end
    if type(options.builder) ~= 'function' then
        raise(std.TypeError('Page.builder must be a function'))
    end
    if options.key == nil then
        raise(std.ValueError('Page.key must be provided'))
    end
    if options.name ~= nil and type(options.name) ~= 'string' then
        raise(std.TypeError('Page.name must be a string'))
    end
    local route_kind = options.route_kind or 'page'
    if route_kind ~= 'page' and route_kind ~= 'popup' then
        raise(std.ValueError('Page.route_kind must be page or popup'))
    end
    if options.opaque ~= nil and type(options.opaque) ~= 'boolean' then
        raise(std.TypeError('Page.opaque must be a boolean'))
    end
    if options.maintain_state ~= nil and type(options.maintain_state) ~= 'boolean' then
        raise(std.TypeError('Page.maintain_state must be a boolean'))
    end
    if options.input_policy ~= nil and options.input_policy ~= 'passive'
        and options.input_policy ~= 'interactive' and options.input_policy ~= 'exclusive' then
        raise(std.ValueError('Page.input_policy must be passive, interactive or exclusive'))
    end
    if options.can_pop ~= nil and type(options.can_pop) ~= 'boolean'
        and type(options.can_pop) ~= 'function' then
        raise(std.TypeError('Page.can_pop must be a boolean or function'))
    end
    for _, callback_name in ipairs({
        'on_pop',
        'on_did_install',
        'on_did_push',
        'on_did_pop',
        'on_did_pop_next',
        'on_did_change_next',
        'on_did_change_previous',
        'on_did_replace',
        'on_dispose',
    }) do
        if options[callback_name] ~= nil and type(options[callback_name]) ~= 'function' then
            raise(std.TypeError('Page.' .. callback_name .. ' must be a function'))
        end
    end

    self.key = options.key
    self.name = options.name
    self.arguments = copy_descriptor_value(options.arguments)
    self.builder = options.builder
    self.route_kind = route_kind --[[@as RouteKind]]
    self.opaque = options.opaque ~= false
    self.barrier_config = copy_descriptor_value(options.barrier_config)
    self.surface_policy = copy_descriptor_value(options.surface_policy)
    self.transition_policy = copy_descriptor_value(options.transition_policy)
    self.maintain_state = options.maintain_state
    self.input_policy = options.input_policy
    self.can_pop = options.can_pop
    self.on_pop = options.on_pop
    self.on_did_install = options.on_did_install
    self.on_did_push = options.on_did_push
    self.on_did_pop = options.on_did_pop
    self.on_did_pop_next = options.on_did_pop_next
    self.on_did_change_next = options.on_did_change_next
    self.on_did_change_previous = options.on_did_change_previous
    self.on_did_replace = options.on_did_replace
    self.on_dispose = options.on_dispose
end

---@param other Page
---@return boolean
function Page:identity_matches(other)
    return other ~= nil and self.__class == other.__class and self.key == other.key
        and self.route_kind == other.route_kind
end

---@class RouteResult : std.object
---@field _complete boolean
---@field _value any
---@field _callbacks fun(value: any)[]
---@overload fun(): self
local RouteResult = std.class.new('RouteResult', {})

function RouteResult:__init()
    self._complete = false
    self._value = nil
    self._callbacks = {}
end

---@return boolean
function RouteResult:is_complete()
    return self._complete
end

---@return any
function RouteResult:value()
    return self._value
end

---@param callback fun(value: any)
---@return RouteResult
function RouteResult:on_complete(callback)
    if type(callback) ~= 'function' then
        raise(std.TypeError('RouteResult callback must be a function'))
    end
    if self._complete then
        callback(self._value)
    else
        self._callbacks[#self._callbacks + 1] = callback
    end
    return self
end

---@param value any
function RouteResult:_complete_with(value)
    if self._complete then
        return
    end
    self._complete = true
    self._value = value
    local callbacks = self._callbacks
    self._callbacks = {}
    for _, callback in ipairs(callbacks) do
        callback(value)
    end
end

---@class Route : std.object
---@field page Page
---@field navigator NavigatorState?
---@field lifecycle RouteLifecycle
---@field is_active boolean
---@field is_current boolean
---@field is_first boolean
---@field result RouteResult
---@field content_mounted boolean
---@field _dispose_requested boolean
---@field _pop_result any
---@field _pop_result_set boolean
---@overload fun(page: Page): self
local Route = std.class.new('Route', {})

local function require_page(value, name)
    if not std.isinstance(value, Page) then
        raise(std.TypeError(name .. ' must be a Page'))
    end
end

function Route:__init(page)
    require_page(page, 'Route.page')
    self.page = page
    self.navigator = nil
    self.lifecycle = 'created'
    self.is_active = false
    self.is_current = false
    self.is_first = false
    self.result = RouteResult()
    self.content_mounted = false
    self._dispose_requested = false
    self._pop_result = nil
    self._pop_result_set = false
end

---@param callback_name string
---@param ... any
function Route:_invoke_page_callback(callback_name, ...)
    local callback = self.page[callback_name]
    if callback then
        callback(self, ...)
    end
end

function Route:did_install()
    self:_invoke_page_callback('on_did_install')
end

function Route:did_push()
    self:_invoke_page_callback('on_did_push')
end

---@param result any
function Route:did_pop(result)
    self:_invoke_page_callback('on_did_pop', result)
end

function Route:did_pop_next()
    self:_invoke_page_callback('on_did_pop_next')
end

---@param next_route Route?
function Route:did_change_next(next_route)
    self:_invoke_page_callback('on_did_change_next', next_route)
end

---@param previous_route Route?
function Route:did_change_previous(previous_route)
    self:_invoke_page_callback('on_did_change_previous', previous_route)
end

---@param old_page Page
function Route:did_replace(old_page)
    self:_invoke_page_callback('on_did_replace', old_page)
end

---@param navigator NavigatorState
function Route:install(navigator)
    if self.lifecycle ~= 'created' then
        return false
    end
    self.navigator = navigator
    self.lifecycle = 'installed'
    self:did_install()
    return true
end

---@param page Page
function Route:update_page(page)
    require_page(page, 'Route.page')
    if self.page == page then
        return
    end
    local old_page = self.page
    self.page = page
    self:did_replace(old_page)
end

---@param result any
---@param invoke_on_pop boolean
---@return boolean
function Route:_transition_to_popping(result, invoke_on_pop)
    if self.lifecycle == 'popping' or self.lifecycle == 'removed'
        or self.lifecycle == 'disposed' then
        return false
    end
    if invoke_on_pop and self.page.on_pop then
        local accepted = self.page.on_pop(self, result)
        if accepted == false then
            return false
        end
    end
    self._pop_result = result
    self._pop_result_set = true
    self.lifecycle = 'popping'
    self:did_pop(result)
    return true
end

---@param result any
---@return boolean
function Route:begin_pop(result)
    if self.lifecycle ~= 'current' and self.lifecycle ~= 'inactive'
        and self.lifecycle ~= 'active' then
        return false
    end
    local can_pop = self.page.can_pop
    if type(can_pop) == 'function' then
        can_pop = can_pop(self)
    end
    if can_pop == false then
        return false
    end
    return self:_transition_to_popping(result, true)
end

function Route:mark_removed()
    if self.lifecycle == 'disposed' then
        return
    end
    self.is_active = false
    self.is_current = false
    self.is_first = false
    self.lifecycle = 'removed'
    self._dispose_requested = true
    self:_try_dispose()
end

function Route:_try_dispose()
    if not self._dispose_requested or self.content_mounted then
        return
    end
    self:dispose()
end

function Route:_content_mounted()
    if self.lifecycle == 'disposed' then
        return
    end
    self.content_mounted = true
end

function Route:_content_unmounted()
    self.content_mounted = false
    self:_try_dispose()
end

function Route:dispose()
    if self.lifecycle == 'disposed' then
        return false
    end
    if self.content_mounted then
        self._dispose_requested = true
        return false
    end
    self._dispose_requested = false
    self.lifecycle = 'disposed'
    self.is_active = false
    self.is_current = false
    self.is_first = false
    self:_invoke_page_callback('on_dispose')
    local result = self._pop_result_set and self._pop_result or nil
    self.result:_complete_with(result)
    return true
end

---@param context BuildContext
---@param token table?
---@return Widget?
function Route:build_content(context, token)
    if token ~= ROUTE_CONTENT_TOKEN or type(context) ~= 'table' or not context.mounted
        or context._lifecycle_phase ~= 'build' then
        raise(std.RuntimeError(
            'Route.builder requires a mounted route-content BuildContext'))
    end
    if self.lifecycle == 'removed' or self.lifecycle == 'disposed'
        or self.lifecycle == 'popping' then
        raise(std.RuntimeError('cannot build content for a removed Route'))
    end
    local content = self.page.builder(context)
    if content ~= nil and (type(content) ~= 'table'
        or type(content.create_element) ~= 'function') then
        raise(std.TypeError('Page.builder must return a Widget or nil'))
    end
    return content
end

---@class _RouteDisposerState : State
---@overload fun(): self
local RouteDisposerState = std.class.new('_RouteDisposerState', { State })

function RouteDisposerState:__init()
    std.super(RouteDisposerState, self, State).__init(self)
end

function RouteDisposerState:build()
    return nil
end

function RouteDisposerState:init_state()
    local widget = self.widget --[[@as _RouteDisposer]]
    widget.route:_content_mounted()
end

function RouteDisposerState:dispose()
    local widget = self.widget --[[@as _RouteDisposer]]
    widget.route:_content_unmounted()
end

---@class _RouteDisposer : StatefulWidget
---@field route Route
---@overload fun(options: _RouteDisposerOptions): self
local RouteDisposer = std.class.new('_RouteDisposer', { StatefulWidget })

---@class _RouteDisposerOptions
---@field route Route
---@field key any?

---@param options _RouteDisposerOptions
function RouteDisposer:__init(options)
    if type(options) ~= 'table' then
        raise(std.TypeError('_RouteDisposer expects an options table'))
    end
    if not std.isinstance(options.route, Route) then
        raise(std.TypeError('_RouteDisposer.route must be a Route'))
    end
    self.key = options.key
    self.route = options.route
end

function RouteDisposer:create_state()
    return RouteDisposerState()
end

---@class _RouteBoundary : StatelessWidget
---@field route Route
---@field child Widget?
---@overload fun(options: _RouteBoundaryOptions): self
local RouteBoundary = std.class.new('_RouteBoundary', { StatelessWidget })

---@class _RouteBoundaryOptions
---@field route Route
---@field child Widget?
---@field key any?

---@param options _RouteBoundaryOptions
function RouteBoundary:__init(options)
    if type(options) ~= 'table' then
        raise(std.TypeError('_RouteBoundary expects an options table'))
    end
    if not std.isinstance(options.route, Route) then
        raise(std.TypeError('_RouteBoundary.route must be a Route'))
    end
    self.key = options.key
    self.route = options.route
    self.child = options.child
end

function RouteBoundary:build()
    local children = {}
    if self.child ~= nil then
        children[#children + 1] = self.child
    end
    -- Element unmounts children in render order. Keeping this after the page
    -- child makes route disposal happen after the page State subtree disposes.
    children[#children + 1] = RouteDisposer({
        key = self.route,
        route = self.route,
    })
    return Stack({ children = children })
end

---@class _RouteContent : StatelessWidget
---@field route Route
---@overload fun(options: _RouteContentOptions): self
local RouteContent = std.class.new('_RouteContent', { StatelessWidget })

---@class _RouteContentOptions
---@field route Route
---@field key any?

---@param options _RouteContentOptions
function RouteContent:__init(options)
    if type(options) ~= 'table' then
        raise(std.TypeError('_RouteContent expects an options table'))
    end
    if not std.isinstance(options.route, Route) then
        raise(std.TypeError('_RouteContent.route must be a Route'))
    end
    self.key = options.key
    self.route = options.route
end

---@param context BuildContext
---@return Widget
function RouteContent:build(context)
    -- This is the only call site of Route:build_content. The context is the
    -- mounted Element for this route-content widget and is never retained.
    local child = self.route:build_content(context, ROUTE_CONTENT_TOKEN)
    return RouteBoundary({ route = self.route, child = child })
end

---@class NavigatorState : State
---@field pages Page[] authoritative mutable page list
---@field routes Route[] ordered runtime records
---@overload fun(): self
local NavigatorState = std.class.new('NavigatorState', { State })

---@class _NavigatorOptions
---@field pages Page[]?
---@field key any?

---@class Navigator : StatefulWidget
---@field pages Page[] immutable input snapshot
---@overload fun(options?: _NavigatorOptions): self
local Navigator = std.class.new('Navigator', { StatefulWidget })

---@param pages any
---@return Page[]
local function copy_pages(pages)
    if pages == nil then
        return {}
    end
    if type(pages) ~= 'table' then
        raise(std.TypeError('Navigator.pages must be a Page array'))
    end
    local result = {}
    local keys = {}
    for index, page in ipairs(pages) do
        require_page(page, 'Navigator.pages[' .. index .. ']')
        if keys[page.key] then
            raise(std.ValueError('Navigator.pages keys must be unique'))
        end
        keys[page.key] = true
        result[index] = page
    end
    return result
end

---@param options _NavigatorOptions?
function Navigator:__init(options)
    options = options or {}
    if type(options) ~= 'table' then
        raise(std.TypeError('Navigator expects an options table'))
    end
    self.key = options.key
    self.pages = copy_pages(options.pages)
end

function Navigator:create_state()
    return NavigatorState()
end

function NavigatorState:__init()
    std.super(NavigatorState, self, State).__init(self)
    self.pages = {}
    self.routes = {}
end

---@param page Page
---@param old_routes Route[]
---@param used table<Route, boolean>
---@return Route?
local function find_matching_route(page, old_routes, used)
    for _, old_route in ipairs(old_routes) do
        if not used[old_route] and old_route.page:identity_matches(page) then
            return old_route
        end
    end
    return nil
end

---@param page Page
---@return Route
local function create_route(page)
    if page.route_kind == 'popup' then
        -- Lazy loading keeps the Stage-4 navigation module independent from
        -- the overlay module during module initialization.  PopupRoute is a
        -- Route subclass; it does not introduce a second route protocol.
        local overlay_mod = require 'player.overlay'
        return overlay_mod.PopupRoute(page)
    end
    return Route(page)
end

---@param routes Route[]
---@return table<Route, Route?>, table<Route, Route?>
local function neighbors(routes)
    local previous = {}
    local next_route = {}
    for index, route in ipairs(routes) do
        previous[route] = routes[index - 1]
        next_route[route] = routes[index + 1]
    end
    return previous, next_route
end

---@param pages Page[]
---@return Route?
function NavigatorState:_reconcile(pages)
    local old_routes = self.routes
    local old_previous, old_next = neighbors(old_routes)
    local used = {}
    local new_routes = {}
    local created = {}

    for index, page in ipairs(pages) do
        local route = find_matching_route(page, old_routes, used)
        if route then
            used[route] = true
            route:update_page(page)
        else
            route = create_route(page)
            route:install(self)
            created[#created + 1] = route
        end
        new_routes[index] = route
    end

    for _, route in ipairs(old_routes) do
        if not used[route] then
            if route.lifecycle ~= 'popping' then
                route:_transition_to_popping(nil, false)
            end
            route:mark_removed()
        end
    end

    self.pages = copy_pages(pages)
    self.routes = new_routes

    local new_previous, new_next = neighbors(new_routes)
    for _, route in ipairs(new_routes) do
        route.is_active = true
        route.is_first = route == new_routes[1]
        route.is_current = route == new_routes[#new_routes]
        route.lifecycle = route.is_current and 'current' or 'inactive'

        if old_next[route] ~= new_next[route] then
            route:did_change_next(new_next[route])
            if old_next[route] and not used[old_next[route]] then
                route:did_pop_next()
            end
        end
        if old_previous[route] ~= new_previous[route] then
            route:did_change_previous(new_previous[route])
        end
    end
    for _, route in ipairs(created) do
        route:did_push()
    end

    return new_routes[#new_routes]
end

function NavigatorState:init_state()
    local widget = self.widget --[[@as Navigator]]
    self:_reconcile(copy_pages(widget.pages))
end

---@param old_widget StatefulWidget
function NavigatorState:did_update_widget(old_widget)
    local widget = self.widget --[[@as Navigator]]
    self:_reconcile(copy_pages(widget.pages))
end

---@param context BuildContext
---@return Widget
function NavigatorState:build(context)
    local children = {}
    for _, route in ipairs(self.routes) do
        if route.lifecycle ~= 'removed' and route.lifecycle ~= 'disposed' then
            children[#children + 1] = RouteContent({
                key = route,
                route = route,
            })
        end
    end
    return Stack({ children = children })
end

---@param pages Page[]
---@return boolean
function NavigatorState:set_pages(pages)
    if not self:is_mounted() then
        return false
    end
    local snapshot = copy_pages(pages)
    return self:set_state(function()
        self:_reconcile(snapshot)
    end)
end

---@param page Page
---@return RouteResult
function NavigatorState:push(page)
    require_page(page, 'NavigatorState.push page')
    if not self:is_mounted() then
        raise(std.RuntimeError('NavigatorState.push requires a mounted Navigator'))
    end
    local route_result = nil
    self:set_state(function()
        local pages = copy_pages(self.pages)
        pages[#pages + 1] = page
        local route = self:_reconcile(pages)
        route_result = route and route.result or nil
    end)
    return route_result --[[@as RouteResult]]
end

---@param result any
---@return boolean
function NavigatorState:pop(result)
    if not self:is_mounted() then
        return false
    end
    local route = self.routes[#self.routes]
    if route == nil or #self.routes <= 1 or not route:begin_pop(result) then
        return false
    end
    local pages = copy_pages(self.pages)
    table.remove(pages, #pages)
    self:set_state(function()
        self:_reconcile(pages)
    end)
    return true
end

---@return Route?
function NavigatorState:current_route()
    return self.routes[#self.routes]
end

---@param index integer
---@return Route?
function NavigatorState:route_at(index)
    return self.routes[index]
end

---@return Page[]
function NavigatorState:page_list()
    return copy_pages(self.pages)
end

function NavigatorState:dispose()
    for _, route in ipairs(self.routes) do
        if route.lifecycle ~= 'removed' and route.lifecycle ~= 'disposed' then
            if route.lifecycle ~= 'popping' then
                route:_transition_to_popping(nil, false)
            end
            route:mark_removed()
        end
    end
    self.routes = {}
    self.pages = {}
end

M.Page = Page
M.Route = Route
M.RouteResult = RouteResult
M.Navigator = Navigator
M.NavigatorState = NavigatorState

return M
