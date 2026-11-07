# Memory investigation — 2026-11-07

Snapshot fix: `ee06341`; measurements captured at `242ad73` plus the working changes.

Confirmed and fixed: `widget/player_context.lua` forward readonly caches kept
discarded snapshots/nested data alive under LuaJIT's non-ephemeron weak-key semantics.
Forward caches now weaken both keys and values; reverse maps own backing data
only while a caller retains the view. No production GC policy changed.

| Final batch / scenario | Before fix survivors | After fix survivors |
| --- | ---: | ---: |
| 5,000 readonly snapshots | 5,000 | 0 |
| 5,000 nested views | 5,000 | 0 |
| 5,000 live-store replacements | 5,000 | 0 |
| 5,000 ordinary class instances | 0 | 0 |
| 5,000 dynamic classes (external elxlib) | 5,000 | 5,000 |
| 500 Main reconciliations, old root Widgets | 0 | 0 |
| 500 mount/dispose cycles, trees/Elements/RenderObjects | 0 | 0 |

The dynamic-class leak belongs to the current modified external dependency:
registry metadata strongly reaches its weak class key through `__mro[1]`. It was
not changed here. Production modules declare classes at load time; this probe
does not establish per-frame dynamic-class creation.

| Isolated playing scenario, 30 seconds | Post-GC Lua delta KiB | Private delta MiB | Post-GC old-view survivors |
| --- | ---: | ---: | ---: |
| No UI | 0.00 | -8.42 | 0 |
| Legacy snapshot module, hidden Main | 18,602.20 | 79.15 | 128 |
| Legacy snapshot module, visible Main | 17,863.71 | 102.92 | 128 |
| Fixed module, hidden Main | 196.36 | -15.20 | 0 |
| Fixed module, visible Main | 235.43 | 16.20 | 0 |

Only the snapshot module differs in the legacy comparison. Generated 720p/60 H.264,
software decode, GPU VO, no audio, Demo/debug off; actual OSD 2276×1280. Five-second
warmup plus initialization wait, five-second samples, initial/final full GC.
Hidden/continuous display are explicitly controlled in staging and verified at
every sample. Native memory is read from the owned window process, not its launcher.

Residual process growth is unresolved. Over 60 seconds, normal Main and Main with
ASS submission disabled grew by 118.04/115.86 MiB private bytes while post-GC Lua
grew only 97.96/226.14 KiB. Simple static/changing ASS labels at 60 Hz grew only
2.35/3.34 MiB. Stopping presentation, waiting five seconds and collecting again
reduced Main private bytes from 411.71/413.65 to 287.56/298.89 MiB. This combines
overlay removal, another GC and elapsed time; it does not isolate a native allocator.

The extra full-GC-every-five-seconds control still grew by 112.88/120.18 MiB,
then fell from 411.18/415.31 to 303.80/297.51 MiB after presentation stopped and
302.04/292.07 MiB after App shutdown. Raising GC frequency is not supported as a
production fix. Native allocation stacks and separate removal/wait/frame/input
interventions are needed before attributing this residual to libass or a leak.

Data:

- [Lua current](memory-lua-current-2026-11-07.json) / [Lua legacy](memory-lua-legacy-2026-11-07.json)
- [Host snapshot comparison](memory-host-snapshot-2026-11-07.json)
- [Host ASS controls](memory-host-controls-2026-11-07.json)
- [Host periodic-GC controls](memory-host-gc-2026-11-07.json)

Reproduction commands and diagnostic interventions are in
[tools/README.md](../../tools/README.md). Short runs do not establish long-term
native stability. User private media/configuration, ModernX, Linux and long-duration
tests were not reproduced. Manual results lacked explicit memory units/time meaning
and were treated as clues, without extrapolating a leak rate.

Validation: five new Lua ownership tests/12 assertions and one real-host collector
test; complete Python **44 passed**, EmmyLua **zero diagnostics**. Normal full Lua
suite has **158 failures / 2172 passes** with the current external elxlib; identical
158 failures occur before the snapshot fix. The dependency overwrites subclass
`__tostring` with its default object formatter, hiding exception messages. A fresh
diagnostic process restoring that dispatch passed all **2330** assertions, but it
does not replace the failed normal-suite result. The external dependency was not edited.
