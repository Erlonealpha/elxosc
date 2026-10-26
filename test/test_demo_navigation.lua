-- Exercise the demo through its mounted buttons, pointer routing and host ESC.
---@diagnostic disable: undefined-field, need-check-nil, generic-constraint-mismatch

local F = require 'framework'
local mp_stub = require 'mp_stub'
mp_stub.install()

local app_mod = require 'host.mpv_app'
local main_layout = require 'main_layout'
local demo_mod = require 'demo'
local geometry = require 'foundation.geometry'

local App = app_mod.App
local Demo = demo_mod.Demo
local Offset = geometry.Offset
local fake = mp_stub.fake

local function find_element(element, predicate)
    if predicate(element) then
        return element
    end
    for _, child in ipairs(element:element_children()) do
        local found = find_element(child, predicate)
        if found then
            return found
        end
    end
end

local function mount_demo()
    mp_stub.reset()
    local app = App(main_layout.build_app(nil, demo_mod.initial_pages()))
    app:render()
    local element = find_element(app.binding.root_element, function(candidate)
        return candidate.widget.__class == Demo
    end)
    assert(element, 'demo home must be mounted')
    return app, element.state
end

local function interactive_rect(app, key)
    local element = find_element(app.binding.root_element, function(candidate)
        return candidate.widget.key == key
    end)
    assert(element, 'missing demo control: ' .. key)
    local node = element:first_render_object()
    -- A card's decoration is below its GestureDetector; a Button starts at it.
    while node do
        for _, region in ipairs(app.owner:pointer_regions()) do
            if region.node == node then
                return region.rect
            end
        end
        node = node.parent
    end
    error('demo control has no visible input region: ' .. key)
end

local function click_at(app, point)
    app.owner:dispatch_pointer('down', point, 'left')
    app.owner:dispatch_pointer('up', point, 'left')
    app:render()
end

local function click(app, key)
    local rect = interactive_rect(app, key)
    click_at(app, Offset((rect.left + rect.right) / 2, (rect.top + rect.bottom) / 2))
end

local function escape(app)
    assert(fake.bindings_enabled_sections['elxosc-navigation'], 'ESC must be claimed')
    fake.binding_sections['elxosc-navigation'].list[1][2]()
    app:render()
end

F.section('demo: N3 navigation')

F.test('Page button returns a result and preserves the home State and renderer', function()
    local app, home = mount_demo()
    local owner, presenter, overlay = app.owner, app.presenter, fake.overlay
    local navigator = home.widget.navigator
    F.contains(overlay.data, 'Navigation', 'navigation controls are rendered')
    F.eq(#navigator.routes, 1, 'demo uses the initial WindowLayer Page')
    F.eq(fake.bindings_enabled_sections['elxosc-navigation'], nil, 'home leaves ESC to the host')
    fake.log['elxosc-demo']()
    app:render()
    click(app, 'demo-open-page')
    F.contains(overlay.data, 'Page + Route', 'details page is visible')
    F.ok(not overlay.data:find('Anchor', 1, true), 'opaque Page hides the home demo')
    F.ok(home:is_mounted(), 'home State is maintained while covered')
    click(app, 'demo-page-back')
    F.eq(home.navigation_result, 'Page: done', 'returned value reaches the demo')
    F.eq(home.navigation_returns, 1, 'result is delivered once')
    F.eq(home.count, 1, 'home counter is retained')
    F.contains(overlay.data, 'Result: Page: done', 'returned result is painted')
    F.contains(overlay.data, 'Anchor', 'home content is visible again')
    F.eq(app.owner, owner, 'same render owner')
    F.eq(app.presenter, presenter, 'same presenter')
    ---@diagnostic disable-next-line: preferred-local-alias
    F.eq(fake.overlay, overlay, 'same host overlay')
    F.eq(fake.bindings_enabled_sections['elxosc-navigation'], nil, 'return releases ESC')
    app:shutdown()
end)

F.test('Popup buttons, card and barrier have distinct outcomes', function()
    local app, home = mount_demo()
    click(app, 'demo-open-popup')
    F.contains(fake.overlay.data, 'PopupRoute', 'popup is rendered')
    F.contains(fake.overlay.data, 'Anchor', 'home remains visible below popup')
    local card = interactive_rect(app, 'demo-navigation-card')
    click_at(app, Offset(card.left + 5, card.top + 5))
    F.eq(#home.widget.navigator.routes, 2, 'clicking card padding does not dismiss')
    click(app, 'demo-popup-confirm')
    F.contains(fake.overlay.data, 'Result: Popup: confirmed', 'confirmation result is shown')
    click(app, 'demo-open-popup')
    click(app, 'demo-popup-cancel')
    F.contains(fake.overlay.data, 'Result: Popup: cancelled', 'cancel result is shown')
    click(app, 'demo-open-popup')
    click_at(app, Offset(2, 2))
    F.contains(fake.overlay.data, 'Result: Popup: dismissed', 'barrier dismissal is shown')
    F.eq(home.navigation_returns, 3, 'each popup completes exactly once')
    F.eq(home.count, 0, 'barrier does not activate the underlying demo controls')
    app:shutdown()
end)

F.test('ESC and demo commands share the live Navigator and clean up on shutdown', function()
    local app, home = mount_demo()
    fake.log['elxosc-demo']('page')
    fake.log['elxosc-demo']('page')
    app:render()
    F.eq(#home.widget.navigator.routes, 2, 'repeated command does not duplicate a route')
    escape(app)
    F.contains(fake.overlay.data, 'Result: Page: dismissed', 'ESC returns to home without a value')
    fake.log['elxosc-demo']('popup')
    app:render()
    escape(app)
    F.contains(fake.overlay.data, 'Result: Popup: dismissed', 'ESC dismisses the popup')
    F.eq(home.navigation_returns, 2, 'one result per ESC')
    F.eq(fake.bindings_enabled_sections['elxosc-navigation'], nil, 'home releases ESC again')
    fake.log['elxosc-demo']('unknown')
    F.eq(home.count, 0, 'unknown commands do not mutate the demo')
    fake.log['elxosc-demo']('popup')
    app:render()
    app:shutdown()
    F.eq(fake.log['elxosc-demo'], nil, 'demo message is unregistered')
    F.eq(home.result_unsubscribe, nil, 'pending result subscription is released')
    F.eq(fake.bindings_enabled_sections['elxosc-navigation'], nil, 'shutdown releases ESC')
end)
