-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- A small, host-independent Navigator runtime.
--
-- Page is an immutable description. Route owns the runtime entry handles and
-- result lifecycle. NavigatorState reconciles Page values and renders the
-- resulting entries through one Theatre; it does not create a second render
-- owner or a second content mount.

local std = require 'elxlibs.std'
local color_mod = require 'foundation.color'
local widget_mod = require 'widget.widget'
local state_mod = require 'widget.state'
local overlay_mod = require 'widget.overlay'
local basic_widgets = require 'widget.widgets.basic'
local container_mod = require 'widget.widgets.container'

local Widget = widget_mod.Widget
local StatefulWidget = widget_mod.StatefulWidget
local InheritedWidget = widget_mod.InheritedWidget
local StatelessWidget = widget_mod.StatelessWidget
local State = state_mod.State
local Theatre = overlay_mod.Theatre
local OverlayEntry = overlay_mod.OverlayEntry
local GestureDetector = basic_widgets.GestureDetector
local Container = container_mod.Container
local raise = std.raise
local Color = color_mod.Color

local M = {}

local function copy_array(values)
    local result = {}
    for index, value in ipairs(values or {}) do
        result[index] = value
    end
    return result
end

--== immutable page descriptions ============================================

---@class _PageOptions
---@field key any required stable identity within a Navigator
---@field name string?
---@field builder fun(context: BuildContext): Widget?
---@field opaque boolean? defaults to true
---@field maintain_state boolean? defaults to true
---@field on_pop fun(route: Route, value: any?)?
---@field on_dispose fun(route: Route)?

---@class Page : std.object
---@field key any
---@field name string?
---@field builder fun(context: BuildContext): Widget?
---@field opaque boolean
---@field maintain_state boolean
---@field on_pop fun(route: Route, value: any?)?
---@field on_dispose fun(route: Route)?
---@overload fun(options: _PageOptions): self
local Page = std.class.new('Page', {})

function Page:__init(options)
    if type(options) ~= 'table' then
        raise(std.TypeError('Page expects an options table'))
    end
    if options.key == nil then
        raise(std.ValueError('Page.key is required'))
    end
    if type(options.builder) ~= 'function' then
        raise(std.TypeError('Page.builder must be a function'))
    end
    if options.name ~= nil and type(options.name) ~= 'string' then
        raise(std.TypeError('Page.name must be a string'))
    end
    if options.on_pop ~= nil and type(options.on_pop) ~= 'function' then
        raise(std.TypeError('Page.on_pop must be a function'))
    end
    if options.on_dispose ~= nil and type(options.on_dispose) ~= 'function' then
        raise(std.TypeError('Page.on_dispose must be a function'))
    end
    self.key = options.key
    self.name = options.name
    self.builder = options.builder
    self.opaque = options.opaque ~= false
    self.maintain_state = options.maintain_state ~= false
    self.on_pop = options.on_pop
    self.on_dispose = options.on_dispose
end

---@param context BuildContext
---@return Widget?
function Page:build(context)
    local child = self.builder(context)
    if child ~= nil and not std.isinstance(child, Widget) then
        raise(std.TypeError('Page.builder must return a Widget or nil'))
    end
    return child
end

local function page_matches(left, right)
    return left.__class == right.__class and left.key == right.key
end

local function validate_page(page)
    if not std.isinstance(page, Page) then
        raise(std.TypeError('Navigator pages must be Page values'))
    end
end

---@param pages Page[]
local function validate_pages(pages)
    if type(pages) ~= 'table' then
        raise(std.TypeError('Navigator.pages must be an array'))
    end
    for index, page in ipairs(pages) do
        validate_page(page)
        for previous = 1, index - 1 do
            local previous_page = pages[previous]
            if previous_page ~= nil and previous_page.key == page.key then
                raise(std.ValueError('Navigator.pages cannot contain duplicate keys'))
            end
        end
    end
end

---@class _PopupPageOptions : _PageOptions
---@field barrier_color Color?
---@field barrier_dismissible boolean?

---@class PopupPage : Page
---@field barrier_color Color?
---@field barrier_dismissible boolean
---@overload fun(options: _PopupPageOptions): self
local PopupPage = std.class.new('PopupPage', { Page })

function PopupPage:__init(options)
    if type(options) ~= 'table' then
        raise(std.TypeError('PopupPage expects an options table'))
    end
    local page_options = {}
    for key, value in pairs(options) do
        page_options[key] = value
    end
    page_options.opaque = false
    std.super(PopupPage, self, Page).__init(self, page_options)
    if options.barrier_color ~= nil and not std.isinstance(options.barrier_color, Color) then
        raise(std.TypeError('PopupPage.barrier_color must be a Color or nil'))
    end
    if options.barrier_dismissible ~= nil and type(options.barrier_dismissible) ~= 'boolean' then
        raise(std.TypeError('PopupPage.barrier_dismissible must be a boolean'))
    end
    self.barrier_color = options.barrier_color
    self.barrier_dismissible = options.barrier_dismissible ~= false
end

--== modal barrier ==========================================================

---@class _ModalBarrierOptions
---@field color Color?
---@field dismissible boolean?
---@field on_dismiss fun()?
---@field key any?

---@class ModalBarrier : StatelessWidget
---@field color Color?
---@field dismissible boolean
---@field on_dismiss fun()?
---@overload fun(options?: _ModalBarrierOptions): self
local ModalBarrier = std.class.new('ModalBarrier', { StatelessWidget })

function ModalBarrier:__init(options)
    options = options or {}
    self.key = options.key
    self.color = options.color
    if self.color ~= nil and not std.isinstance(self.color, Color) then
        raise(std.TypeError('ModalBarrier.color must be a Color or nil'))
    end
    self.dismissible = options.dismissible ~= false
    self.on_dismiss = options.on_dismiss
    if self.on_dismiss ~= nil and type(self.on_dismiss) ~= 'function' then
        raise(std.TypeError('ModalBarrier.on_dismiss must be a function'))
    end
end

function ModalBarrier:build()
    local handlers = {
        on_down = function() end,
        on_up = function() end,
    }
    if self.dismissible then
        local on_dismiss = self.on_dismiss
        handlers.on_click = function()
            if on_dismiss then
                on_dismiss()
            end
        end
    end
    return GestureDetector(Container({ color = self.color }), handlers)
end

--== result ================================================================

---@class RouteResult : std.object
---@field complete boolean
---@field value any?
---@field _listeners table<fun(value: any?), true>
---@overload fun(): self
local RouteResult = std.class.new('RouteResult', {})

function RouteResult:__init()
    self.complete = false
    self.value = nil
    self._listeners = {}
end

---@param callback fun(value: any?)
---@return fun(): boolean
function RouteResult:add_listener(callback)
    if type(callback) ~= 'function' then
        raise(std.TypeError('RouteResult listener must be a function'))
    end
    if self.complete then
        callback(self.value)
        return function()
            return false
        end
    end
    self._listeners[callback] = true
    local active = true
    return function()
        if not active then
            return false
        end
        active = false
        self._listeners[callback] = nil
        return true
    end
end

---@param value any?
---@return boolean
function RouteResult:finish(value)
    if self.complete then
        return false
    end
    self.complete = true
    self.value = value
    local listeners = {}
    for callback in pairs(self._listeners) do
        listeners[#listeners + 1] = callback
    end
    self._listeners = {}
    for _, callback in ipairs(listeners) do
        callback(value)
    end
    return true
end

--== routes ================================================================

---@class Route : std.object
---@field page Page
---@field navigator NavigatorState
---@field result RouteResult
---@field content_entry OverlayEntry
---@field status 'active'|'popping'|'popped'|'disposed'
---@field _pop_value any?
---@field _finalized table<OverlayEntry, true>
---@field _entry_count integer
---@overload fun(page: Page, navigator: NavigatorState): self
local Route = std.class.new('Route', {})

function Route:__init(page, navigator)
    validate_page(page)
    self.page = page
    self.navigator = navigator
    self.result = RouteResult()
    self.status = 'active'
    self._pop_value = nil
    self._finalized = {}
    self._entry_count = 1
    self.content_entry = OverlayEntry({
        key = self,
        opaque = page.opaque,
        maintain_state = page.maintain_state,
        on_dispose = function()
            self:_entry_finalized(self.content_entry)
        end,
        builder = function(context)
            return self.page:build(context)
        end,
    })
end

---@return boolean
function Route:is_current()
    return self.status == 'active' and self.navigator:current_route() == self
end

---@return boolean
function Route:is_active()
    return self.status == 'active'
end

---@return OverlayEntry[]
function Route:entries()
    return { self.content_entry }
end

---@param page Page
function Route:update_page(page)
    validate_page(page)
    self.page = page
    self.content_entry:set_opaque(page.opaque)
    self.content_entry:set_maintain_state(page.maintain_state)
    self.content_entry:mark_needs_build()
end

---@param value any?
---@return boolean
function Route:begin_pop(value)
    if self.status ~= 'active' then
        return false
    end
    self.status = 'popping'
    self._pop_value = value
    if not self.content_entry:is_attached() and not self.content_entry:is_mounted() then
        self:_finish_pop()
    end
    return true
end

---@param entry OverlayEntry
function Route:_entry_finalized(entry)
    self._finalized[entry] = true
    if self.status == 'popping' then
        local all_done = true
        for _, current in ipairs(self:entries()) do
            if not self._finalized[current] then
                all_done = false
                break
            end
        end
        if all_done then
            self:_finish_pop()
        end
    end
end

function Route:_finish_pop()
    if self.status ~= 'popping' then
        return
    end
    self.status = 'popped'
    local value = self._pop_value
    if self.page.on_pop then
        self.page.on_pop(self, value)
    end
    self.result:finish(value)
    if self.page.on_dispose then
        self.page.on_dispose(self)
    end
    self.status = 'disposed'
end

---@return boolean
function Route:dispose()
    return self:begin_pop(nil)
end

---@class PopupRoute : Route
---@field page PopupPage
---@field barrier_entry OverlayEntry
---@overload fun(page: PopupPage, navigator: NavigatorState): self
local PopupRoute = std.class.new('PopupRoute', { Route })

function PopupRoute:__init(page, navigator)
    if not std.isinstance(page, PopupPage) then
        raise(std.TypeError('PopupRoute.page must be a PopupPage'))
    end
    std.super(PopupRoute, self, Route).__init(self, page, navigator)
    self._entry_count = 2
    self.barrier_entry = OverlayEntry({
        key = {},
        opaque = false,
        maintain_state = false,
        on_dispose = function()
            self:_entry_finalized(self.barrier_entry)
        end,
        builder = function()
            return ModalBarrier({
                color = self.page.barrier_color,
                dismissible = self.page.barrier_dismissible,
                on_dismiss = function()
                    self.navigator:pop()
                end,
            })
        end,
    })
end

function PopupRoute:entries()
    return { self.barrier_entry, self.content_entry }
end

function PopupRoute:update_page(page)
    if not std.isinstance(page, PopupPage) then
        raise(std.TypeError('PopupRoute.page must remain a PopupPage'))
    end
    Route.update_page(self, page)
    self.barrier_entry:mark_needs_build()
end

--== navigator scope =========================================================

---@class _NavigatorScopeOptions
---@field state NavigatorState
---@field child Widget?
---@field key any?

---@class NavigatorScope : InheritedWidget
---@field state NavigatorState
---@field child Widget?
---@overload fun(options: _NavigatorScopeOptions): self
local NavigatorScope = std.class.new('NavigatorScope', { InheritedWidget })
local NavigatorScopeClass = NavigatorScope --[[@as std.Class]]

function NavigatorScope:__init(options)
    options = options or {}
    self.key = options.key
    self.state = options.state
    self.child = options.child
    if self.state == nil then
        raise(std.TypeError('NavigatorScope.state is required'))
    end
end

function NavigatorScope:update_should_notify(old_widget)
    return self.state ~= old_widget.state
end

---@param context BuildContext
---@return NavigatorState
function NavigatorScope.of(context)
    if context == nil or type(context.depend_on_inherited_widget_of_exact_type) ~= 'function' then
        raise(std.TypeError('Navigator lookup expects a BuildContext'))
    end
    local scope = context:depend_on_inherited_widget_of_exact_type(NavigatorScopeClass)
    if scope == nil then
        raise(std.RuntimeError('no Navigator ancestor was found'))
    end
    return scope.state
end

--== Navigator ===============================================================

---@class _NavigatorOptions
---@field pages Page[]?
---@field key any?

---@class Navigator : StatefulWidget
---@field pages Page[]
---@overload fun(options?: _NavigatorOptions): self
local Navigator = std.class.new('Navigator', { StatefulWidget })

function Navigator:__init(options)
    options = options or {}
    self.key = options.key
    self.pages = copy_array(options.pages)
    validate_pages(self.pages)
end

---@class NavigatorState : State
---@field routes Route[]
---@field pages Page[]
---@overload fun(): self
local NavigatorState = std.class.new('NavigatorState', { State })

function NavigatorState:__init()
    std.super(NavigatorState, self, State).__init(self)
    self.routes = {}
    self.pages = {}
end

function NavigatorState:_create_route(page)
    if std.isinstance(page, PopupPage) then
        return PopupRoute(page, self)
    end
    return Route(page, self)
end

---@param pages Page[]
---@param schedule boolean
function NavigatorState:_reconcile(pages, schedule)
    validate_pages(pages)
    local previous = self.routes
    local used = {}
    local next_routes = {}
    for index, page in ipairs(pages) do
        local route = nil
        if previous[index] and page_matches(previous[index].page, page) then
            route = previous[index]
        else
            for old_index, candidate in ipairs(previous) do
                if not used[candidate] and page_matches(candidate.page, page) then
                    route = candidate
                    used[candidate] = true
                    break
                end
            end
        end
        if route then
            used[route] = true
            route:update_page(page)
        else
            route = self:_create_route(page)
        end
        next_routes[index] = route
    end
    for _, route in ipairs(previous) do
        if not used[route] then
            route:begin_pop(nil)
        end
    end
    self.routes = next_routes
    self.pages = copy_array(pages)
    if schedule then
        self:set_state()
    end
end

function NavigatorState:init_state()
    local navigator = self.widget --[[@as Navigator]]
    self:_reconcile(navigator.pages, false)
end

function NavigatorState:did_update_widget(old_widget)
    local navigator = self.widget --[[@as Navigator]]
    self:_reconcile(navigator.pages, false)
end

---@return Route?
function NavigatorState:current_route()
    return self.routes[#self.routes]
end

---@return boolean
function NavigatorState:can_pop()
    return #self.routes > 1 and self:current_route() ~= nil
end

---@param page Page
---@return Route
function NavigatorState:push(page)
    if not self:is_mounted() then
        raise(std.RuntimeError('Navigator.push requires a mounted Navigator'))
    end
    validate_page(page)
    for _, current in ipairs(self.pages) do
        if current.key == page.key then
            raise(std.ValueError('Navigator.push cannot reuse an existing Page key'))
        end
    end
    local route = self:_create_route(page)
    self.routes[#self.routes + 1] = route
    self.pages[#self.pages + 1] = page
    self:set_state()
    return route
end

---@param page PopupPage
---@return PopupRoute
function NavigatorState:push_popup(page)
    if not std.isinstance(page, PopupPage) then
        raise(std.TypeError('Navigator.push_popup expects a PopupPage'))
    end
    return self:push(page) --[[@as PopupRoute]]
end

---@param value any?
---@return boolean
function NavigatorState:pop(value)
    if not self:can_pop() then
        return false
    end
    local index = #self.routes
    local route = self.routes[index]
    if route == nil then
        return false
    end
    table.remove(self.routes, index)
    table.remove(self.pages, index)
    route:begin_pop(value)
    self:set_state()
    return true
end

---@param value any?
---@return boolean
function NavigatorState:maybe_pop(value)
    return self:pop(value)
end

---@param pages Page[]
function NavigatorState:set_pages(pages)
    if not self:is_mounted() then
        raise(std.RuntimeError('Navigator.set_pages requires a mounted Navigator'))
    end
    self:_reconcile(copy_array(pages), true)
end

---@return Page[]
function NavigatorState:pages_snapshot()
    return copy_array(self.pages)
end

---@param event KeyEvent|string
---@return boolean
function NavigatorState:handle_key(event)
    local key = type(event) == 'string' and event or event and event.key
    local event_type = type(event) == 'table' and event.type or 'press'
    if (key == 'ESC' or key == 'ESCAPE' or key == 'escape')
        and (event_type == 'down' or event_type == 'press') then
        return self:maybe_pop()
    end
    return false
end

function NavigatorState:build()
    local entries = {}
    for _, route in ipairs(self.routes) do
        for _, entry in ipairs(route:entries()) do
            entries[#entries + 1] = entry
        end
    end
    return NavigatorScope({
        state = self,
        child = Theatre({
            key = 'navigator-theatre',
            initial_entries = entries,
        }),
    })
end

function NavigatorState:dispose()
    for _, route in ipairs(self.routes) do
        route:begin_pop(nil)
    end
    self.routes = {}
    self.pages = {}
end

function Navigator:create_state()
    return NavigatorState()
end

---@param context BuildContext
---@return NavigatorState
function Navigator.of(context)
    return NavigatorScope.of(context)
end

M.Page = Page
M.PopupPage = PopupPage
M.RouteResult = RouteResult
M.Route = Route
M.PopupRoute = PopupRoute
M.ModalBarrier = ModalBarrier
M.NavigatorScope = NavigatorScope
M.Navigator = Navigator
M.NavigatorState = NavigatorState

return M
