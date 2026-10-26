-- N4 single-canvas ordering, successful-frame cache and clear lifecycle.
---@diagnostic disable: undefined-field, need-check-nil, inject-field, generic-constraint-mismatch
local F = require 'framework'
local mp_stub = require 'mp_stub'
mp_stub.install()
local backend = require 'backends.ass_canvas'
local primitives = require 'host.mpv_primitives'
local app_mod = require 'host.mpv_app'
local overlay_mod = require 'widget.overlay'
local layout = require 'widget.widgets.layout'
local geometry = require 'foundation.geometry'
local color = require 'foundation.color'
local paint = require 'painting.paint'
local owner_mod = require 'render.render_owner'
local gesture_mod = require 'render.gesture'

local AssCanvas = backend.AssCanvas
local AssPresenter = primitives.AssPresenter
local App = app_mod.App
local OverlayEntry = overlay_mod.OverlayEntry
local Theatre = overlay_mod.Theatre
local Container = layout.Container
local Rect = geometry.Rect
local Color = color.Color
local Paint = paint.Paint
local RenderOwner = owner_mod.RenderOwner
local RenderGesture = gesture_mod.RenderGesture
local fake = mp_stub.fake

local function box(width, height)
    local custom = require 'render.custom_paint'
    return custom.RenderCustomPaint(nil, { preferred_size = geometry.Size(width, height) })
end

F.section('presentation: single canvas')

F.test('RegionSnapshot is cached and protects the owner from mutation', function()
    local gesture = RenderGesture(box(20, 10), { on_tap = function() end })
    local owner = RenderOwner(gesture)
    owner:set_viewport(require('layout.constraints').Constraints.tight(40, 30))
    owner:layout()
    local first = owner:region_snapshot()
    local second = owner:region_snapshot()
    F.eq(first, second, 'unchanged input generation reuses one snapshot')
    local regions = first:regions()
    regions[1].rect = Rect(99, 99, 100, 100)
    F.ok(owner:pointer_regions()[1].rect ~= regions[1].rect, 'snapshot is immutable to callers')
    gesture:set_handlers({})
    local changed = owner:region_snapshot()
    F.ok(changed ~= first, 'input policy invalidates the snapshot')
    F.eq(#changed:regions(), 0, 'new policy has no interactive region')
end)

F.test('event boundaries preserve the physical ReadOrder mapping', function()
    local canvas = AssCanvas()
    canvas:draw_rect(Rect(0, 0, 20, 20), Paint(Color.rgba(0xFF0000FF)))
    canvas:draw_rect(Rect(5, 5, 15, 15), Paint(Color.rgba(0x0000FFFF)))
    F.eq(#canvas.events, 2, 'one drawing call per event')
    F.contains(canvas.events[1], '\\1c&H0000FF&', 'first red event')
    F.contains(canvas.events[2], '\\1c&HFF0000&', 'later blue event')
    F.raises(function()
        canvas:_push('first\nsecond')
    end, 'single non-empty', 'raw newlines cannot inject a new ReadOrder')
    F.raises(function()
        canvas:_push('first\0second')
    end, 'single non-empty', 'NUL cannot truncate a frame')
    canvas:reset()
    F.eq(canvas:text(), '', 'empty frame has no events')
end)

F.test('presenter retries failure and only caches successful submissions', function()
    mp_stub.reset()
    local presenter, canvas = AssPresenter(), AssCanvas()
    local overlay = fake.overlay
    local update = overlay.update
    overlay.update = function()
        return nil, 'test submission failure'
    end
    F.raises(function()
        presenter:present(canvas, 320, 180)
    end, 'test submission failure', 'host failure is surfaced')
    overlay.update = update
    F.ok(presenter:present(canvas, 320, 180), 'identical failed frame is retried')
    F.ok(not presenter:present(canvas, 320, 180), 'successful identical frame is deduplicated')
    F.ok(presenter:present(canvas, 640, 360), 'resolution change submits even empty text')
    F.eq(overlay.updates, 2, 'two successful submissions')
    F.ok(presenter:remove(), 'presenter removed')
    F.ok(not presenter:remove(), 'remove is idempotent')
    F.ok(not presenter:present(canvas, 640, 360), 'removed presenter cannot revive its overlay')
    F.eq(overlay.removes, 1, 'host resource removed once')
end)

F.test('hiding all entries submits empty ASS without creating a presenter', function()
    mp_stub.reset()
    local entry = OverlayEntry({ builder = function()
        return Container({ color = Color.rgba(0xFF0000FF) })
    end })
    local app = App(Theatre({ initial_entries = { entry } }))
    app:render()
    local overlay, canvas = fake.overlay, app.canvas
    F.ok(#overlay.data > 0, 'visible frame submitted')
    entry:set_visible(false)
    app:render()
    F.eq(overlay.data, '', 'hidden content clears prior output')
    local updates = overlay.updates
    app:render()
    F.eq(overlay.updates, updates, 'empty frame stays cached')
    entry:set_visible(true)
    app:render()
    F.ok(#overlay.data > 0, 'same pipeline can show content again')
    ---@diagnostic disable-next-line: preferred-local-alias
    F.eq(app.canvas, canvas, 'same canvas')
    F.eq(#fake.overlays, 1, 'one physical overlay')
    app:shutdown()
    app:shutdown()
    F.eq(overlay.removes, 1, 'shutdown removes exactly once')
end)

F.test('an empty root consumes layout and paint dirty state', function()
    local owner, canvas = RenderOwner(), AssCanvas()
    owner:set_root(nil)
    owner:layout()
    owner:paint(canvas)
    F.ok(not owner:needs_layout(), 'empty layout settles')
    F.ok(not owner:needs_paint(), 'empty paint settles')
end)
