"""Smoke test for loading the real elxosc entry point in mpv.net."""

from pathlib import Path

import pytest


@pytest.mark.real_host
def test_elxosc_script_loads_and_accepts_demo_message(real_host_factory):
    script = Path(__file__).parents[2] / "main.lua"
    with real_host_factory(f"--script={script}") as (client, _, process, log):
        # The command must be accepted while the script is loaded. The Lua
        # handler increments DemoState; the host remaining alive is the
        # portable observable result available through mpv IPC.
        assert client.command("script-message", "elxosc-demo") is None
        assert process.poll() is None
        try:
            count = client.command("get_property", "user-data/elxosc-demo-count")
        except AssertionError as error:
            pytest.fail(f"elxosc did not register its demo state; host log:\n"
                        f"{log.read_text(errors='replace')}\n{error}")
        assert count == "1"
        dimensions = client.command("get_property", "osd-dimensions")
        assert dimensions is not None
