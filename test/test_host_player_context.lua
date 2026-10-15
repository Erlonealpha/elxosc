-- mpv PlayerStore bridge, with the host API stubbed out.

---@diagnostic disable: undefined-field, inject-field, need-check-nil, generic-constraint-mismatch, preferred-local-alias, unused

local F = require('framework')

local mp_stub = require('mp_stub')
mp_stub.install()

local player_context = require('widget.player_context')
local mpv_player_context = require('host.mpv_player_context')

local PlayerStore = player_context.PlayerStore
local MpPlayerContext = mpv_player_context.MpPlayerContext

local fake = mp_stub.fake

F.section('host player context')

F.test('a property update replaces the current snapshot', function()
    mp_stub.reset()
    local store = PlayerStore({ pause = false })
    local context = MpPlayerContext(store)
    local subscription = context:observe('pause')

    F.ok(subscription:is_active(), 'property observer is active')
    F.eq(#fake.events, 1, 'one property observer is registered')
    fake.events[1].cb('pause', true)
    F.eq(store:get().pause, true, 'property value reaches the store')
    F.eq(store:get().pause, true, 'property update is visible')
end)

F.test('property observers clean up and duplicate names are rejected', function()
    mp_stub.reset()
    local store = PlayerStore()
    local context = MpPlayerContext(store)
    local subscription = context:observe('pause')

    F.raises(function()
        context:observe('pause')
    end, 'RuntimeError', 'duplicate property observer')
    F.ok(context:dispose(), 'context disposes')
    F.ok(not context:dispose(), 'context disposal is idempotent')
    F.ok(not subscription:is_active(), 'property subscription is inactive')
    F.eq(fake.unobserved[1] ~= nil, true, 'mpv observer is removed')
end)

F.test('a disposed property can be observed again', function()
    mp_stub.reset()
    local context = MpPlayerContext(PlayerStore())
    local first = context:observe('pause')
    first:dispose()
    local second = context:observe('pause')
    F.ok(second:is_active(), 're-observer starts active')
    context:dispose()
end)

F.test('a queued property callback is inert after dispose', function()
    mp_stub.reset()
    local store = PlayerStore({ pause = false })
    local context = MpPlayerContext(store)
    local subscription = context:observe('pause')
    local callback = fake.events[1].cb
    subscription:dispose()
    callback('pause', true)
    F.eq(store:get().pause, false, 'disposed callback cannot update the store')
end)

F.test('custom property transforms can reject an update', function()
    mp_stub.reset()
    local errors = 0
    local store = PlayerStore({ value = 1 })
    local context = MpPlayerContext(store, {
        on_error = function() errors = errors + 1 end,
    })
    context:observe('value', function()
        error('bad property')
    end)
    fake.events[1].cb('value', 2)
    F.eq(store:get().value, 1, 'rejected update leaves the store unchanged')
    F.eq(errors, 1, 'transform errors are reported')
end)
