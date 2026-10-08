-- Scheduler: the frame-clock contract, the two-phase pipeline and tickers.

-- See the note in test_widget.lua: the `std.class` / optional-ownership
-- diagnostics are disabled across the suite.
---@diagnostic disable: undefined-field, inject-field, need-check-nil, generic-constraint-mismatch, preferred-local-alias, unused

local F = require('framework')
local std = require('elxlibs.std')

local frame_clock = require('scheduler.frame_clock')
local scheduler_mod = require('scheduler.scheduler')
local ticker_mod = require('scheduler.ticker')

local FrameClock = frame_clock.FrameClock
local Scheduler = scheduler_mod.Scheduler
local Ticker = ticker_mod.Ticker

-- Manual clock: frames are delivered on demand by `tick`.
local ManualClock = std.class.new('test.ManualClock', { FrameClock })
function ManualClock:__init(time)
    self._time = time or 0
    self.pending = false
    self.requests = 0
end
function ManualClock:now()
    return self._time
end
function ManualClock:request_frame()
    self.pending = true
    self.requests = self.requests + 1
end
function ManualClock:tick(dt)
    self._time = self._time + (dt or 0)
    if self.pending then
        self.pending = false
        self:_emit()
    end
end

F.section('scheduler: FrameClock')

F.test('the base clock requires a host backend', function()
    local c = FrameClock()
    F.raises(function() c:now() end, 'NotImplementedError', 'now')
    F.raises(function() c:request_frame() end, 'NotImplementedError', 'request_frame')
    F.ok(not c:has_handler(), 'no handler initially')
end)

F.section('scheduler: Scheduler')

F.test('runs persistent callbacks on a requested frame only', function()
    local clock = ManualClock(0)
    local sched = Scheduler(clock)
    local frames = 0
    sched:add_persistent(function() frames = frames + 1 end)
    F.eq(frames, 0, 'nothing runs without a frame')
    sched:schedule_frame()
    F.eq(clock.requests, 1, 'frame requested')
    F.eq(frames, 0, 'still not run')
    clock:tick(0.016)
    F.eq(frames, 1, 'ran on frame')
    F.eq(clock.pending, false, 'idle again (no tickers)')
end)

F.test('coalesces repeated frame requests', function()
    local clock = ManualClock(0)
    local sched = Scheduler(clock)
    sched:add_persistent(function() end)
    sched:schedule_frame()
    sched:schedule_frame()
    sched:schedule_frame()
    F.eq(clock.requests, 1, 'one request for three schedule calls')
end)

F.test('post-frame callbacks run once, after the frame', function()
    local clock = ManualClock(0)
    local sched = Scheduler(clock)
    local order = {}
    sched:add_persistent(function() order[#order + 1] = 'frame' end)
    sched:add_post_frame(function() order[#order + 1] = 'post' end)
    sched:schedule_frame()
    clock:tick(0)
    F.eq(#order, 2, 'both ran')
    F.eq(order[1], 'frame', 'frame first')
    F.eq(order[2], 'post', 'post after')
end)

F.test('removing a persistent callback stops it', function()
    local clock = ManualClock(0)
    local sched = Scheduler(clock)
    local n = 0
    local cb = function() n = n + 1 end
    sched:add_persistent(cb)
    sched:schedule_frame()
    clock:tick(0)
    sched:remove_persistent(cb)
    sched:schedule_frame()
    clock:tick(0)
    F.eq(n, 1, 'only ran while registered')
end)

F.section('scheduler: Ticker')

F.test('keeps the clock alive while active and reports deltas', function()
    local clock = ManualClock(0)
    local sched = Scheduler(clock)
    local dts = {}
    local ticker = Ticker(sched, function(dt) dts[#dts + 1] = dt end)
    F.ok(not ticker:is_active(), 'idle initially')
    ticker:start()
    F.ok(ticker:is_active(), 'active after start')
    F.eq(clock.requests, 1, 'start requests a frame')
    clock:tick(0.1)
    F.eq(#dts, 1, 'ticked once')
    F.close(dts[1], 0, 'first delta is 0')
    F.eq(clock.pending, true, 'keeps requesting while active')
    clock:tick(0.1)
    F.eq(#dts, 2, 'ticked twice')
    F.close(dts[2], 0.1, 'delta measured between frames')
    ticker:stop()
    F.ok(not ticker:is_active(), 'stopped')
    clock:tick(0.1)
    F.eq(#dts, 2, 'no ticks after stop')
    F.eq(clock.pending, false, 'clock goes idle once tickers stop')
end)
