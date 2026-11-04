"""Real player hover probe. Run with uv --group test from the repository root.

Uses generated video, production entry, real native mouse input and ASS presenter.
Instrumentation and the optional direct-input experiment exist only in staging.
Reported latency ends at ASS submission, not pixel scan-out or external thumbfast.
"""

import argparse
import itertools
import json
import math
import os
import shutil
import statistics
import subprocess
import sys
import tempfile
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "test" / "real_host"))
import conftest as host_helpers
from window_input import WindowInput


def distribution(values):
    if not values:
        return {"count": 0}
    values = sorted(values)
    return {"count": len(values), "mean_ms": statistics.mean(values) * 1000,
            "p50_ms": values[math.ceil(len(values) * 0.50) - 1] * 1000,
            "p95_ms": values[math.ceil(len(values) * 0.95) - 1] * 1000,
            "max_ms": values[-1] * 1000}


def wait_property(client, process, name, expected):
    deadline = time.monotonic() + 10
    while time.monotonic() < deadline:
        if process.poll() is not None:
            raise RuntimeError("benchmark host exited")
        try:
            if client.command("get_property", name) == expected:
                return
        except AssertionError:
            pass
        time.sleep(0.05)
    raise TimeoutError(f"host property {name} did not reach {expected!r}")


def trajectory(pointer, width, height, rate, seconds):
    motions = []
    start = time.perf_counter()
    count = int(rate * seconds)
    # Stay on the production original seekbar at Main scale 1.5, away from edges.
    y = int(height - 100 * 1.5)
    for index in range(count):
        deadline = start + index / rate
        delay = deadline - time.perf_counter()
        if delay > 0:
            time.sleep(delay)
        x = int(80 + (width - 160) * ((index % (rate * 2)) / (rate * 2 - 1)))
        sent = pointer.move(x, y)
        motions.append({"x": x, "y": y, "sent": sent,
                        "finished": time.perf_counter(), "deadline": deadline})
    return motions


def summarize(trace, motions, seconds):
    events = trace.pop("events")
    all_frames = trace.pop("frames")
    seen = set()
    frames = []
    for frame in all_frames:
        if frame["input_seq"] not in seen:
            seen.add(frame["input_seq"])
            frames.append(frame)
    elapsed = motions[-1]["finished"] - motions[0]["sent"]
    by_seq = {event["seq"]: event for event in events}
    matched = {}
    for event in events:
        candidates = [motion for motion in motions
                      if motion["sent"] <= event["time"]
                      and event["time"] - motion["sent"] < 1
                      and abs(motion["x"] - event["x"]) < 2
                      and abs(motion["y"] - event["y"]) < 2]
        if candidates:
            matched[event["seq"]] = candidates[-1]
    result = {"environment": trace, "driver_moves": len(motions), "input_events": len(events),
              "tooltip_frames": len(frames), "all_tooltip_frames": len(all_frames), "matched_events": len(matched),
              "build_dirty_frames": sum(f["build_dirty"] for f in all_frames),
              "layout_frames": sum(f["layout_needed"] for f in all_frames),
              "input_invalidated_frames": sum(f["regions_changed"] for f in all_frames),
              "driver_elapsed_seconds": elapsed, "driver_actual_hz": (len(motions) - 1) / elapsed,
              "delivered_hz": len(events) / elapsed, "tooltip_submit_hz": len(frames) / elapsed,
              "driver_lateness": distribution([max(0, m["sent"] - m["deadline"]) for m in motions]),
              "driver_cost": distribution([m["finished"] - m["sent"] for m in motions]),
              "dispatch": distribution([e["finish"] - e["time"] for e in events]),
              "input_gap": distribution([b["time"] - a["time"] for a, b in zip(events, events[1:])]),
              "frame_wait": distribution([f["start"] - by_seq[f["input_seq"]]["finish"] for f in frames]),
              "lua_frame": distribution([f["finish"] - f["start"] for f in frames]),
              "input_to_submit": distribution([f["finish"] - by_seq[f["input_seq"]]["time"] for f in frames]),
              "stages": {name: distribution([f["stages"].get(name, 0) for f in frames])
                         for name in ("build", "layout", "regions", "paint_ass", "present")}}
    if trace["qpc"]:
        result["os_move_to_input"] = distribution([by_seq[seq]["time"] - m["sent"]
                                                   for seq, m in matched.items()])
        result["os_move_to_submit"] = distribution([f["finish"] - matched[f["input_seq"]]["sent"]
                                                    for f in frames if f["input_seq"] in matched])
    return result


def run_case(temp, media, rate, mode, playback, debug, seconds):
    original_stage = host_helpers._stage_elxosc

    def stage(source, destination, include_main=True):
        original_stage(source, destination, include_main)
        entry = destination / "main.lua"
        content = entry.read_text(encoding="utf-8")
        marker = "require 'elxlib_load' -- sets up elxlibs.*"
        if marker not in content:
            raise RuntimeError("unrecognized entry bootstrap")
        content = content.replace(marker, marker + "\nrequire 'player_hover_probe'")
        content = content.replace("local debug_enabled = true", f"local debug_enabled = {debug}")
        entry.write_text(content, encoding="utf-8")
        shutil.copy2(ROOT / "tools" / "player_hover_probe.lua", destination / "player_hover_probe.lua")

    host_helpers._stage_elxosc = stage
    try:
        with host_helpers._running_host(temp, (
            f"--script={ROOT / 'main.lua'}", "--force-window=yes", "--geometry=1280x720",
            "--osc=no", "--vo=gpu", "--hwdec=no", "--audio=no",
            f"--script-opts=elxosc-bench-input={mode}",
        )) as (client, config, process, log):
            wait_property(client, process, "user-data/elxosc-demo-open", "false")
            client.command("set_property", "pause", playback == "paused")
            client.command("loadfile", str(media))
            wait_property(client, process, "idle-active", False)
            time.sleep(0.5)
            dimensions = client.command("get_property", "osd-dimensions")
            width, height = dimensions["w"], dimensions["h"]
            with WindowInput(process, client) as pointer:
                trajectory(pointer, width, height, rate, 1)
                client.command("script-message", "elxosc-bench-begin")
                motions = trajectory(pointer, width, height, rate, seconds)
                time.sleep(0.1)
                client.command("script-message", "elxosc-bench-save")
                wait_property(client, process, "user-data/elxosc-bench-saved", "yes")
            trace = json.loads((config / "scripts" / "elxosc" / "hover-trace.json").read_text())
            result = summarize(trace, motions, seconds)
            result.update(requested_hz=rate, input_mode=mode, playback=playback, debug=debug)
            return result
    finally:
        host_helpers._stage_elxosc = original_stage


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--host", default=os.environ.get("ELXOSC_MPV_BINARY"))
    parser.add_argument("--ffmpeg", default=shutil.which("ffmpeg"))
    parser.add_argument("--seconds", type=float, default=4)
    parser.add_argument("--rates", default="60,240")
    parser.add_argument("--modes", default="observe,mouse_move")
    parser.add_argument("--playback", default="paused,playing")
    parser.add_argument("--debug", choices=("true", "false"), default="false")
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    if args.seconds <= 0 or not args.ffmpeg:
        parser.error("positive duration and an installed ffmpeg are required")
    if args.host:
        os.environ["ELXOSC_MPV_BINARY"] = args.host
    modes, playback = args.modes.split(","), args.playback.split(",")
    if set(modes) - {"observe", "mouse_move"} or set(playback) - {"paused", "playing"}:
        parser.error("invalid input mode or playback state")
    rates = [int(rate) for rate in args.rates.split(",")]
    if not rates or min(rates) <= 0:
        parser.error("positive rates required")
    report = {"revision": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
              "seconds": args.seconds, "warmup_seconds": 1,
              "media": "generated 1280x720 testsrc2 H.264 at 60 fps; no audio", "cases": [],
              "limits": "ASS submission latency, excludes pixel scan-out and external thumbfast; staged instrumentation"}
    with tempfile.TemporaryDirectory(prefix="elxosc-hover-") as directory:
        temp = Path(directory)
        media = temp / "hover.mp4"
        subprocess.run([args.ffmpeg, "-v", "error", "-f", "lavfi", "-i", "testsrc2=size=1280x720:rate=60",
                        "-t", str(max(20, args.seconds + 5)), "-c:v", "libx264", "-preset", "ultrafast",
                        "-crf", "35", "-an", str(media)], check=True)
        for index, (rate, mode, state) in enumerate(itertools.product(rates, modes, playback)):
            case_dir = temp / str(index)
            case_dir.mkdir()
            print(f"case {index + 1}: {rate} Hz {mode} {state} debug={args.debug}", flush=True)
            case = run_case(case_dir, media, rate, mode, state, args.debug, args.seconds)
            report["cases"].append(case)
            print(json.dumps({key: case[key] for key in ("input_events", "tooltip_frames", "dispatch",
                                                        "frame_wait", "lua_frame", "input_to_submit")}), flush=True)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(f"report: {args.output}", flush=True)


if __name__ == "__main__":
    main()
