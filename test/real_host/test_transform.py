"""A real mpv host consumes both finite scale box variants."""

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


@pytest.mark.real_host
def test_real_transform_boxes_render(real_host_factory):
    script = Path(__file__).with_name("transform.lua")
    with real_host_factory(f"--script={script}") as (client, _, process, log):
        wait_for_property(client, process, log, "user-data/elxosc-transform-loaded", "yes")
        wait_for_property(client, process, log, "user-data/elxosc-transform-ready", "yes")

        ass = client.command("get_property", "user-data/elxosc-transform-ass")
        assert "real host transform" in ass
        assert "real host layout scale" in ass
        assert "\\fscx" in ass and "\\fscy" in ass
        assert "\\clip" in ass

        values = []
        for name in ("x0", "x1", "y0", "y1"):
            value = client.command("get_property", f"user-data/elxosc-transform-bounds-{name}")
            assert value != "missing", f"libass did not return a bound for {name}"
            values.append(float(value))
        x0, x1, y0, y1 = values
        assert x1 > x0 and y1 > y0
