"""Real mpv coverage for named PresentationHost surfaces."""

from pathlib import Path

import pytest

from test_elxosc import wait_for_property


@pytest.mark.real_host
def test_real_presentation_surfaces_publish_ass_and_policy(real_host_factory):
    script = Path(__file__).parent / "presentation_host.lua"
    with real_host_factory(f"--script={script}") as (client, _, process, log):
        wait_for_property(client, process, log, "user-data/elxosc-presentation-state",
                         "default,extension,popup")
        ass_lengths = client.command("get_property", "user-data/elxosc-presentation-ass")
        assert all(int(value) > 0 for value in ass_lengths.split(',')), ass_lengths
        assert client.command("get_property", "user-data/elxosc-presentation-z") == "100,200,300"

        assert client.command("script-message", "elxosc-presentation-hide-popup") is None
        wait_for_property(client, process, log, "user-data/elxosc-presentation-ass",
                         ",".join((ass_lengths.split(',')[0], ass_lengths.split(',')[1], "0")))
        assert process.poll() is None
