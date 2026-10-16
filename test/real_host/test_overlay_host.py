"""Real mpv smoke coverage for multiple OverlayHost presenters."""

from pathlib import Path

import pytest

from test_elxosc import wait_for_property


@pytest.mark.real_host
def test_real_overlay_layers_create_hide_show_and_remove(real_host_factory):
    script = Path(__file__).parent / "overlay_host.lua"
    with real_host_factory(f"--script={script}") as (client, _, process, log):
        wait_for_property(client, process, log, "user-data/elxosc-overlay-state",
                         "main,extension,popup")
        assert client.command("script-message", "elxosc-overlay-hide-popup") is None
        wait_for_property(client, process, log, "user-data/elxosc-overlay-state",
                         "main,extension")
        assert client.command("script-message", "elxosc-overlay-show-popup") is None
        wait_for_property(client, process, log, "user-data/elxosc-overlay-state",
                         "main,extension,popup")
        assert client.command("script-message", "elxosc-overlay-remove-extension") is None
        wait_for_property(client, process, log, "user-data/elxosc-overlay-state",
                         "main,popup")
        assert process.poll() is None
