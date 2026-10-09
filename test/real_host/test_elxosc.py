"""Smoke test for loading the real elxosc entry point in mpv.net."""

from pathlib import Path

import pytest


@pytest.mark.real_host
def test_elxosc_script_loads_and_accepts_demo_message(real_host_factory):
    script = Path(__file__).parents[2] / "main.lua"
    with real_host_factory(f"--script={script}") as (client, _, process):
        # The command must be accepted while the script is loaded. The Lua
        # handler increments DemoState; the host remaining alive is the
        # portable observable result available through mpv IPC.
        assert client.command("script-message", "elxosc-demo") is None
        assert process.poll() is None
        dimensions = client.command("get_property", "osd-dimensions")
        assert dimensions is not None
