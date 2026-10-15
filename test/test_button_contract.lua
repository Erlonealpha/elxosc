-- Button construction preserves the caller's configuration and public behavior.

local F = require 'framework'
local geometry = require 'foundation.geometry'
local color_mod = require 'foundation.color'
local pointer_mod = require 'foundation.pointer_event'
local key_event_mod = require 'foundation.key_event'
local base_mod = require 'widget.widgets.button_base'
local style_mod = require 'widget.widgets.button_style'
local button_mod = require 'widget.widgets.button'
local elevated_mod = require 'widget.widgets.elevated_button'
local outlined_mod = require 'widget.widgets.outlined_button'
local text_mod = require 'widget.widgets.text_button'
local icon_mod = require 'widget.widgets.icon_button'

local Offset = geometry.Offset
local EdgeInsets = geometry.EdgeInsets
local Color = color_mod.Color
local PointerEvent = pointer_mod.PointerEvent
local KeyEvent = key_event_mod.KeyEvent
local ButtonBase = base_mod.ButtonBase
local ButtonStyle = style_mod.ButtonStyle

F.section('button: construction contract')

F.test('variant constructors do not change the supplied options', function()
    local variants = {
        button_mod.Button,
        elevated_mod.ElevatedButton,
        outlined_mod.OutlinedButton,
        text_mod.TextButton,
        icon_mod.IconButton,
    }
    local icon = ButtonBase({ label = 'icon' })
    local padding = EdgeInsets.all(3)
    local options = { label = 'Play', icon = icon, padding = padding, radius = 12 }
    for _, Variant in ipairs(variants) do
        local result = Variant(options)
        F.eq(options.style, nil, 'caller style is untouched')
        F.eq(options.child, nil, 'caller child is untouched')
        F.eq(result.label, 'Play', 'label is retained')
        F.ok(result.style ~= nil, 'variant has a style')
    end
    F.eq(options.padding, padding, 'caller padding is retained')
    F.eq(options.icon, icon, 'caller icon is retained')
    F.eq(icon_mod.IconButton(options).child, icon, 'icon supplies the child')
end)

F.test('custom style and explicit child win over defaults', function()
    local style = ButtonStyle({ background_color = Color.rgba255(1, 2, 3) })
    local child = ButtonBase({ label = 'child' })
    local options = { style = style, child = child, icon = ButtonBase() }
    local icon_button = icon_mod.IconButton(options)
    F.eq(icon_button.style, style, 'custom style')
    F.eq(icon_button.child, child, 'explicit child')
    F.eq(options.style, style, 'same caller style')
    local copy = style:copy_with({ radius = 9 })
    F.eq(style.radius, 4, 'copy_with does not change the original')
    F.eq(copy.radius, 9, 'copy_with changes the copy')
end)

F.test('pointer constructors retain positional and extension fields', function()
    local point = Offset(2, 3)
    local positional = PointerEvent('down', point, 'left', { device = 'mouse' })
    F.ok(not rawequal(positional.point, point), 'positional point is copied')
    F.eq(positional.point, point, 'positional point values')
    F.eq(positional.device, 'mouse', 'extension field')

    point.x = 8
    F.eq(positional.point and positional.point.x, 2, 'copied point is independent')

    local fields_point = { x = 4, y = 5 }
    local fields = { type = 'move', point = fields_point, pressure = 0.5 }
    local from_fields = PointerEvent(fields)
    F.eq(from_fields.type, 'move', 'table event type')
    F.eq(from_fields.pressure, 0.5, 'table extension field')
    F.ok(not rawequal(from_fields.point, fields_point), 'fields point is copied')
    fields_point.y = 9
    F.eq(from_fields.point and from_fields.point.y, 5, 'fields point is independent')
end)

F.test('pointer values expose structured mouse fields and snapshots', function()
    local point = { x = 2, y = 3 }
    local buttons = { left = true, middle = false }
    local modifiers = { shift = true, ctrl = false }
    local fields = {
        type = 'double',
        point = point,
        pointer_id = 0,
        button = 'left',
        buttons = buttons,
        modifiers = modifiers,
        source = 'mouse',
        timestamp = 12.5,
        device = 'mouse',
    }
    local event = PointerEvent(fields)

    F.eq(event.click_count, 2, 'double-click count defaults to two')
    F.eq(fields.click_count, nil, 'default is not written to fields')
    F.eq(event.pointer_id, 0, 'pointer id')
    F.eq(event.source, 'mouse', 'mouse source')
    F.eq(event.device, 'mouse', 'extension field')
    F.ok(event.buttons ~= nil and event.buttons.left, 'held button set')
    F.ok(event.buttons ~= nil and not event.buttons.middle, 'false button state')
    F.ok(event.modifiers ~= nil and event.modifiers.shift, 'modifier set')
    F.ok(event.modifiers ~= nil and not event.modifiers.ctrl, 'false modifier state')

    point.x = 7
    buttons.left = false
    modifiers.shift = false
    F.eq(event.point and event.point.x, 2, 'point snapshot')
    F.ok(event.buttons ~= nil and event.buttons.left, 'button snapshot')
    F.ok(event.modifiers ~= nil and event.modifiers.shift, 'modifier snapshot')
end)

F.test('pointer accepts every known type and only omits allowed points', function()
    ---@type PointerEventType[]
    local types = { 'down', 'up', 'move', 'cancel', 'enter', 'leave', 'wheel', 'double' }
    for _, event_type in ipairs(types) do
        local point
        if event_type ~= 'cancel' and event_type ~= 'leave' then
            point = Offset(1, 2)
        end
        local event = PointerEvent(event_type, point)
        F.eq(event.type, event_type, 'known pointer type: ' .. event_type)
    end
    F.eq(PointerEvent('double', Offset(1, 2)).click_count, 2,
        'double positional default')
    F.raises(function()
        ---@diagnostic disable-next-line: param-type-mismatch
        PointerEvent({ type = 'move' })
    end, 'required', 'move requires a point')
    for _, event_type in ipairs({ 'down', 'up', 'enter', 'wheel', 'double' }) do
        F.raises(function()
            PointerEvent(event_type)
        end, 'required', event_type .. ' requires a point')
    end
    F.eq(PointerEvent('cancel').point, nil, 'cancel may omit point')
    F.eq(PointerEvent('leave').point, nil, 'leave may omit point')
end)

F.test('pointer validates structured fields and finite numeric boundaries', function()
    F.raises(function()
        ---@diagnostic disable-next-line: param-type-mismatch
        PointerEvent({ type = 'unknown', point = Offset(1, 2) })
    end, 'not supported', 'unknown pointer event')
    F.raises(function()
        ---@diagnostic disable-next-line: param-type-mismatch
        PointerEvent({ type = 'down', point = Offset(1, 2), button = 'x' })
    end, 'not supported', 'unknown pointer button')
    F.raises(function()
        ---@diagnostic disable-next-line: param-type-mismatch
        PointerEvent({ type = 'down', point = Offset(1, 2), buttons = { left = 1 } })
    end, 'boolean', 'non-boolean button state')
    F.raises(function()
        ---@diagnostic disable-next-line: param-type-mismatch
        PointerEvent({ type = 'down', point = Offset(1, 2), buttons = { extra = true } })
    end, 'unknown key', 'unknown button state')
    F.raises(function()
        ---@diagnostic disable-next-line: param-type-mismatch
        PointerEvent({ type = 'down', point = Offset(1, 2), buttons = false })
    end, 'table', 'non-table button snapshot')
    F.raises(function()
        ---@diagnostic disable-next-line: param-type-mismatch
        PointerEvent({ type = 'down', point = Offset(1, 2), modifiers = { shift = 1 } })
    end, 'boolean', 'non-boolean modifier state')
    F.raises(function()
        ---@diagnostic disable-next-line: param-type-mismatch
        PointerEvent({ type = 'down', point = Offset(1, 2), modifiers = { caps = true } })
    end, 'unknown key', 'unknown modifier state')
    F.raises(function()
        ---@diagnostic disable-next-line: param-type-mismatch
        PointerEvent({ type = 'down', point = Offset(1, 2), modifiers = false })
    end, 'table', 'non-table modifier snapshot')
    F.raises(function()
        ---@diagnostic disable-next-line: param-type-mismatch
        PointerEvent({ type = 'down', point = Offset(1, 2), pointer_id = -1 })
    end, 'non-negative', 'negative pointer id')
    F.raises(function()
        ---@diagnostic disable-next-line: param-type-mismatch
        PointerEvent({ type = 'down', point = Offset(1, 2), pointer_id = 1.5 })
    end, 'non-negative', 'fractional pointer id')
    F.raises(function()
        ---@diagnostic disable-next-line: param-type-mismatch
        PointerEvent({ type = 'down', point = Offset(1, 2), pointer_id = math.huge })
    end, 'non-negative', 'infinite pointer id')
    F.raises(function()
        ---@diagnostic disable-next-line: param-type-mismatch
        PointerEvent({ type = 'down', point = Offset(1, 2), pointer_id = 0 / 0 })
    end, 'non-negative', 'NaN pointer id')
    F.raises(function()
        ---@diagnostic disable-next-line: param-type-mismatch
        PointerEvent({ type = 'down', point = Offset(1, 2), click_count = 0 })
    end, 'positive', 'zero click count')
    F.raises(function()
        ---@diagnostic disable-next-line: param-type-mismatch
        PointerEvent({ type = 'down', point = Offset(1, 2), click_count = 1.5 })
    end, 'positive', 'fractional click count')
    F.raises(function()
        ---@diagnostic disable-next-line: param-type-mismatch
        PointerEvent({ type = 'down', point = Offset(1, 2), click_count = 0 / 0 })
    end, 'positive', 'NaN click count')
    F.raises(function()
        ---@diagnostic disable-next-line: param-type-mismatch
        PointerEvent({ type = 'move', point = Offset(1, 2), delta_x = math.huge })
    end, 'finite', 'infinite horizontal delta')
    F.raises(function()
        ---@diagnostic disable-next-line: param-type-mismatch
        PointerEvent({ type = 'wheel', point = Offset(1, 2), delta_y = 0 / 0 })
    end, 'finite', 'NaN vertical delta')
    F.raises(function()
        ---@diagnostic disable-next-line: param-type-mismatch
        PointerEvent({ type = 'move', point = { x = 0 / 0, y = 2 } })
    end, 'finite', 'NaN point coordinate')
    F.raises(function()
        ---@diagnostic disable-next-line: param-type-mismatch
        PointerEvent({ type = 'move', point = { x = 1, y = math.huge } })
    end, 'finite', 'infinite point coordinate')
    F.raises(function()
        ---@diagnostic disable-next-line: param-type-mismatch
        PointerEvent({ type = 'move', point = Offset(1, 2), timestamp = -math.huge })
    end, 'finite', 'infinite timestamp')
    F.raises(function()
        ---@diagnostic disable-next-line: param-type-mismatch
        PointerEvent({ type = 'move', point = Offset(1, 2), source = 'touch' })
    end, 'not supported', 'unsupported pointer source')
end)

F.test('pointer legacy_data preserves payloads and wheel compatibility', function()
    local point = Offset(1, 2)
    local payload = { source = 'legacy' }
    F.eq(PointerEvent('move', point, payload):legacy_data(), payload,
        'non-nil payload wins')
    F.eq(PointerEvent('down', point, false, { button = 'left' }):legacy_data(), false,
        'false payload wins')
    F.eq(PointerEvent({ type = 'down', point = point, button = 'left' }):legacy_data(), 'left',
        'down button fallback')
    F.eq(PointerEvent({ type = 'up', point = point, button = 'middle' }):legacy_data(), 'middle',
        'up button fallback')
    F.eq(PointerEvent({ type = 'double', point = point, button = 'right' }):legacy_data(), 'right',
        'double button fallback')

    F.eq(PointerEvent({ type = 'wheel', point = point, delta_y = -2 }):legacy_data(), -2,
        'vertical wheel is scalar')
    F.eq(PointerEvent({ type = 'wheel', point = point, delta_x = 0, delta_y = 3 }):legacy_data(), 3,
        'vertical wheel remains scalar with zero horizontal delta')
    F.eq(PointerEvent({ type = 'wheel', point = point, delta_x = 0 }):legacy_data(), nil,
        'zero-only wheel has no legacy payload')
    local horizontal = PointerEvent({ type = 'wheel', point = point, delta_x = 4 }):legacy_data()
    F.ok(horizontal ~= nil and horizontal.x == 4 and horizontal.y == 0,
        'horizontal wheel keeps both axes')
    local both = PointerEvent({ type = 'wheel', point = point, delta_x = 4, delta_y = 5 }):legacy_data()
    F.ok(both ~= nil and both.x == 4 and both.y == 5, 'two-axis wheel keeps both axes')
    F.eq(PointerEvent({ type = 'wheel', point = point }):legacy_data(), nil,
        'wheel without deltas has no legacy payload')
    F.eq(PointerEvent('move', point):legacy_data(), nil, 'other events have no fallback')
    local extension = PointerEvent({
        type = 'down', point = point, button = 'left', legacy_data = 'extension',
    })
    F.eq(pointer_mod.legacy_data(extension), 'left',
        'framework adapter ignores a colliding extension method')
end)

F.test('KeyEvent is a host-independent structured value', function()
    local fields = { key = 'Enter', type = 'down', modifiers = { ctrl = true, alt = false } }
    local event = KeyEvent(fields)
    fields.modifiers.ctrl = false
    F.eq(event.key, 'Enter', 'key')
    F.eq(event.type, 'down', 'key event type')
    F.ok(event.modifiers ~= nil and event.modifiers.ctrl, 'modifiers are copied')
    F.ok(event.modifiers ~= nil and not event.modifiers.alt, 'false modifier is copied')
    F.ok(not event.is_repeat, 'repeat defaults to false')

    fields = { key = 'a', type = 'press', modifiers = { shift = true }, is_repeat = true,
        timestamp = 3 }
    event = KeyEvent(fields)
    fields.modifiers.shift = false
    F.eq(event.type, 'press', 'press type')
    F.ok(event.is_repeat, 'repeat flag')
    F.eq(event.timestamp, 3, 'timestamp')
    F.ok(event.modifiers ~= nil and event.modifiers.shift, 'modifier snapshot')

    ---@type KeyEventType[]
    local types = { 'down', 'up', 'press' }
    for _, event_type in ipairs(types) do
        F.eq(KeyEvent({ key = 'x', type = event_type }).type, event_type,
            'known key type: ' .. event_type)
    end
end)

F.test('KeyEvent validates fields and finite timestamp boundaries', function()
    F.raises(function()
        ---@diagnostic disable-next-line: param-type-mismatch
        KeyEvent(nil)
    end, 'fields table', 'missing key event fields')
    F.raises(function()
        ---@diagnostic disable-next-line: param-type-mismatch
        KeyEvent({ key = '', type = 'down' })
    end, 'non-empty', 'empty key')
    F.raises(function()
        ---@diagnostic disable-next-line: param-type-mismatch
        KeyEvent({ key = 1, type = 'down' })
    end, 'non-empty', 'non-string key')
    F.raises(function()
        ---@diagnostic disable-next-line: param-type-mismatch
        KeyEvent({ key = 'a', type = 'repeat' })
    end, 'not supported', 'unknown key event type')
    F.raises(function()
        ---@diagnostic disable-next-line: param-type-mismatch
        KeyEvent({ key = 'a', type = 'down', is_repeat = 1 })
    end, 'boolean', 'non-boolean repeat')
    F.raises(function()
        ---@diagnostic disable-next-line: param-type-mismatch
        KeyEvent({ key = 'a', type = 'down', modifiers = { meta = 1 } })
    end, 'boolean', 'non-boolean key modifier')
    F.raises(function()
        ---@diagnostic disable-next-line: param-type-mismatch
        KeyEvent({ key = 'a', type = 'down', modifiers = { caps = true } })
    end, 'unknown key', 'unknown key modifier')
    F.raises(function()
        ---@diagnostic disable-next-line: param-type-mismatch
        KeyEvent({ key = 'a', type = 'down', modifiers = false })
    end, 'table', 'non-table key modifier snapshot')
    F.raises(function()
        ---@diagnostic disable-next-line: param-type-mismatch
        KeyEvent({ key = 'a', type = 'down', timestamp = math.huge })
    end, 'finite', 'infinite key timestamp')
    F.raises(function()
        ---@diagnostic disable-next-line: param-type-mismatch
        KeyEvent({ key = 'a', type = 'down', timestamp = 0 / 0 })
    end, 'finite', 'NaN key timestamp')
    F.raises(function()
        ---@diagnostic disable-next-line: param-type-mismatch
        KeyEvent({ key = 'a', type = 'down', timestamp = '3' })
    end, 'finite', 'non-numeric key timestamp')
end)
