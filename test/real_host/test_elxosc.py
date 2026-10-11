"""Smoke test for loading the real elxosc entry point in mpv.net."""

from pathlib import Path
import time

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
def test_elxosc_script_loads_and_accepts_demo_message(real_host_factory):
    script = Path(__file__).parents[2] / "main.lua"
    with real_host_factory(f"--script={script}") as (client, _, process, log):
        # The command must be accepted while the script is loaded. The Lua
        # handler increments DemoState; the host remaining alive is the
        # portable observable result available through mpv IPC.
        wait_for_property(client, process, log, "user-data/elxosc-demo-count", "0")
        assert client.command("script-message", "elxosc-demo") is None
        assert process.poll() is None
        wait_for_property(client, process, log, "user-data/elxosc-demo-count", "1")
        count = client.command("get_property", "user-data/elxosc-demo-count")
        assert count == "1"
        dimensions = client.command("get_property", "osd-dimensions")
        assert dimensions is not None
