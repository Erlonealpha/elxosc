-- mpv PlayerStore bridge, with the host API stubbed out.

---@diagnostic disable: undefined-field, inject-field, need-check-nil, preferred-local-alias, unused

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

F.test('batched property observers publish related fields in one snapshot', function()
    mp_stub.reset()
    local store = PlayerStore({ time_pos = 0, duration = 0 })
    local updates = 0
    store:subscribe(function()
        updates = updates + 1
    end)
    local context = MpPlayerContext(store)
    context:observe_batch({
        { name = 'time-pos', field = 'time_pos', normalize = tonumber },
        { name = 'duration', field = 'duration', normalize = tonumber },
    })
    local by_name = {}
    for _, event in ipairs(fake.events) do
        by_name[event.name] = event.cb
    end
    by_name['time-pos']('time-pos', 12)
    by_name.duration('duration', 120)
    F.eq(store:get().time_pos, 0, 'batch waits for the coalesced flush')
    mp_stub.pump()
    F.eq(store:get().time_pos, 12, 'batched position reaches the store')
    F.eq(store:get().duration, 120, 'batched duration reaches the store')
    F.eq(updates, 1, 'related properties publish one store update')
    context:dispose()
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

F.test('host capability updates use explicit loading/error states', function()
    mp_stub.reset()
    local store = PlayerStore()
    local context = MpPlayerContext(store)
    context:set_capability('thumbfast', 'loading', 'starting')
    F.eq(store:get():capability('thumbfast').status, 'loading', 'loading capability state')
    context:set_capability('thumbfast', 'available')
    F.eq(store:get():capability('thumbfast').status, 'available', 'available capability state')
    F.raises(function()
        context:set_capability('thumbfast', 'invalid' --[[@as CapabilityStatus]])
    end, 'status is invalid', 'invalid capability status')
    context:dispose()
end)

F.test('capability adapters publish loading, available and error states', function()
    mp_stub.reset()
    local store = PlayerStore()
    local context = MpPlayerContext(store)
    local report
    local stopped = false
    local subscription = context:observe_capability('thumbfast', {
        start = function(callback)
            report = callback
            return function()
                stopped = true
            end
        end,
    })
    F.eq(store:get():capability('thumbfast').status, 'loading', 'adapter starts loading')
    report('available', 'connected')
    F.eq(store:get():capability('thumbfast').status, 'available', 'adapter reports available')
    report('error', 'failed', 'not installed')
    local failure = store:get():capability('thumbfast')
    F.eq(failure.status, 'error', 'adapter reports error')
    F.eq(failure.error, 'not installed', 'adapter error detail is retained')
    subscription:dispose()
    F.ok(stopped, 'adapter disposable is released')
    report('available')
    F.eq(store:get():capability('thumbfast').status, 'error',
        'disposed adapter callback is ignored')
    context:dispose()
end)

F.test('capability adapter startup failures become explicit errors', function()
    mp_stub.reset()
    local store = PlayerStore()
    local context = MpPlayerContext(store)
    context:observe_capability('yt_dlp', {
        start = function()
            error('missing executable')
        end,
    })
    local capability = store:get():capability('yt_dlp')
    F.eq(capability.status, 'error', 'startup failure is visible')
    F.contains(capability.error, 'missing executable', 'startup error is retained')
    context:dispose()
end)

F.test('thumbfast capability keeps receiving info until dispose', function()
    mp_stub.reset()
    local store = PlayerStore()
    local context = MpPlayerContext(store)
    local subscription = context:observe_thumbfast()
    F.eq(store:get():capability('thumbfast').status, 'loading',
        'thumbfast starts in loading state')
    local info = fake.log['thumbfast-info']
    F.ok(info ~= nil, 'thumbfast info message is registered')
    info({ width = 320, height = 180 })
    F.eq(store:get():capability('thumbfast').status, 'available',
        'thumbfast dimensions publish availability')
    F.eq(store:get():capability('thumbfast').detail, '320x180',
        'thumbfast dimensions are retained as detail')
    info({ disabled = true, available = false, width = 0, height = 0 })
    F.eq(store:get():capability('thumbfast').status, 'unavailable',
        'thumbfast can disable itself after a media change')
    info({ width = 640, height = 360 })
    F.eq(store:get():capability('thumbfast').detail, '640x360',
        'thumbfast can publish new dimensions without re-registering')
    subscription:dispose()
    F.eq(fake.log['thumbfast-info'], nil, 'thumbfast info message is unregistered')
    context:dispose()
end)

F.test('yt-dlp capability is explicitly unavailable without async subprocess support', function()
    mp_stub.reset()
    local context = MpPlayerContext(PlayerStore())
    local subscription = context:observe_yt_dlp()
    F.eq(context.store:get():capability('yt_dlp').status, 'unavailable',
        'missing async subprocess support is visible')
    F.ok(subscription:is_active(), 'unavailable capability remains disposable')
    subscription:dispose()
    context:dispose()
end)

F.test('SponsorBlock data is isolated from chapter metadata', function()
    mp_stub.reset()
    local store = PlayerStore({ chapter_list = { { time = 0, title = 'Intro' } } })
    local context = MpPlayerContext(store)
    local subscription = context:observe_sponsorblock()
    local callback = fake.log['sponsorblock-done']
    F.ok(callback ~= nil, 'SponsorBlock message is registered')
    callback({
        { start = 10, ['end'] = 20, category = 'sponsor' },
    })
    F.eq(store:get():capability('sponsorblock').status, 'available',
        'SponsorBlock capability becomes available')
    F.eq(store:get().sponsor_segments[1].category, 'sponsor',
        'SponsorBlock segments enter their own snapshot field')
    F.eq(store:get().chapter_list[1].title, 'Intro',
        'SponsorBlock does not rewrite chapter metadata')
    subscription:dispose()
    context:dispose()
end)

F.test('registered async cancellation runs during context disposal', function()
    local context = MpPlayerContext(PlayerStore())
    local cancelled = 0
    context:register_async(function()
        cancelled = cancelled + 1
    end)
    context:dispose()
    F.eq(cancelled, 1, 'context disposal cancels owned async work')
end)
