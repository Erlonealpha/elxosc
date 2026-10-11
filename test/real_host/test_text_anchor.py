"""A real mpv host renders the text-anchor and nominal-icon fixture."""

import time
from pathlib import Path

import pytest


def wait_for_property(client, process, log, name, expected, timeout=5):
    deadline = time.monotonic() + timeout
    last = None
    while time.monotonic() < deadline:
        assert process.poll() is None, f"host exited; log:\n{log.read_text(errors='replace')}"
        try:
            last = client.command("get_property", name, timeout=1)
        except AssertionError:
            last = None
        if last == expected:
            return
        time.sleep(0.05)
    pytest.fail(f"{name}: expected {expected!r}, last observed {last!r}; "
                f"host log:\n{log.read_text(errors='replace')}")


def read_bounds(client, index):
    values = []
    for name in ("x0", "x1", "y0", "y1"):
        value = client.command("get_property", f"user-data/elxosc-anchor-bounds-{index}-{name}")
        assert value != "missing", f"libass did not return bounds for event {index}: {name}"
        values.append(float(value))
    return values


@pytest.mark.real_host
def test_real_ass_anchor_and_icon_events_render(real_host_factory):
    script = Path(__file__).with_name("text_anchor.lua")
    with real_host_factory(f"--script={script}") as (client, _, process, log):
        wait_for_property(client, process, log, "user-data/elxosc-anchor-loaded", "yes")
        wait_for_property(client, process, log, "user-data/elxosc-anchor-ready", "yes")

        ass = client.command("get_property", "user-data/elxosc-anchor-ass")
        assert "\\an5" in ass
        assert "\\an3" in ass
        assert "\\fnMaterial Symbols Rounded" in ass
        assert "play_arrow" in ass

        for index in (1, 2, 3):
            x0, x1, y0, y1 = read_bounds(client, index)
            assert x1 > x0 and y1 > y0, f"empty computed bounds for event {index}"
