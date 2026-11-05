# Offline tools

These tools are explicitly invoked for development. They are not loaded by the
production entry, do not change Widget/layout contracts, and do not add a Define
content entry point.

## ASS measurement

Run from the repository root with the test dependencies and a working mpv/mpv.net:

```text
uv run --group test python tools/ass_measure.py --output tmp/ass-measure.json --markdown tmp/ass-measure.md
uv run --group test python tools/ass_measure.py --input my-samples.json --repeats 3 --output tmp/custom-bounds.json
```

`--host` or `ELXOSC_MPV_BINARY` selects the executable. The tool uses the real-host
fixture's temporary config and ownership-bounded cleanup. It loads only its driver,
disables built-in OSC, and supplies the repository font directory. It waits for a
nonzero OSD viewport stable for 250 ms, rejects viewport changes during sampling,
and never retries a timed-out measurement. `--timeout` defaults to 5 seconds per
wait/IPC operation (maximum 60); fixture startup and cleanup have their own bounds.

Omitting `--input` selects six Widget/Element/RenderObject samples: Latin text, CJK
text, Material Symbols play icon, paint-only scaled text, clipped text and a composed
row. `ass_measure_samples.lua` paints to RecordCanvas, replays those drawing calls
into AssCanvas at (50, 50), and retains the logical box and operation names.

Custom input schema v1:

```json
{
  "schema_version": 1,
  "scene": "my-text",
  "scene_version": 1,
  "samples": [
    {
      "name": "label",
      "data": "{\\an7\\pos(50,50)\\fs24\\fnArial\\bord0}Label",
      "res_x": 640,
      "res_y": 360,
      "metadata": {"font_family": "Arial", "font_size": 24}
    }
  ]
}
```

Names must be unique and nonempty; 1–64 samples are allowed. `data` is a NUL-free
static `ass-events` payload and may be empty. Resolution is an integer in 1–16384;
scene version is a positive integer. Optional `metadata` and `logical` evidence
are retained without interpreting them as host metrics. Built-in requests use
640×360; actual OSD dimensions are recorded separately.

Each request allocates a hidden overlay via `host.ass_measure.AssMeasure`, requests
`compute_bounds`, then removes that ID immediately. Results distinguish `ok`,
`empty`, `unavailable`, and `error`; cleanup errors prevent success. Empty host
tables omit bounds. Nonempty bounds have `left/top/right/bottom/width/height` in ASS
request coordinates. The report keeps all repeats, stability, payload/request
SHA-256, source commit, font-file hash, platform, actual OSD, mpv/FFmpeg/Lua versions,
available libass version logs and font fallback selection. JSON is the full artifact;
Markdown is a compact table.

Exit code is 0 for stable successful/empty measurements, 1 for invalid input,
host/command/timeout/cleanup errors or unstable results, and 2 for an unavailable
host/API. Failure reports contain no fabricated bounds. A missing real-host test
executable skips; the CLI always emits an explicit unavailable report instead.

Bounds describe renderer image rectangles and may include padding. They do not
prove precise glyph ink, baseline, ascent/descent, optical centering or scan-out.
Logical boxes and painted host bounds are deliberately compared as different
quantities. Font fallback and actual viewport affect measurements. The service
does not supply runtime text measurement or update the framework estimator.

## Hover probes

`benchmark_player_hover.lua` investigates the offline Lua path;
`benchmark_real_player_hover.py` and `player_hover_probe.lua` measure real-player
input through ASS submission. Their scenarios, reports and endpoint limits are in
[TESTING.md](../dev/design/TESTING.md).

`gen_font_glyphs.py` generates glyph metadata from the bundled font.
