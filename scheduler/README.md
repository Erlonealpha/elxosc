# Scheduler

`scheduler/` owns the host-neutral frame pipeline and time sources. It does not know
about mpv or ASS.

## Public entry points

- `frame_clock.lua` — host-provided `now`/`request_frame` contract.
- `scheduler.lua` — transient animation callbacks, persistent frame callbacks, and
  post-frame callbacks with request coalescing.
- `ticker.lua` — start/stop/dispose time source for controllers.
- `scheduler_binding.lua` — SchedulerBinding role facade over the shared concrete
  WidgetsBinding; per-tree Scheduler/FrameClock resources remain owner-scope inputs.

The normal order is transient animation sampling, Widget/build work, layout, paint,
and presentation. A ticker resets its start time for each animation so idle host time
does not skip the first sample.

See [rendering](../dev/design/RENDERING.md) and [host](../dev/design/HOST.md).
