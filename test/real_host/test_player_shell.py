"""Real mpv smoke coverage for PlayerShell configuration and lifecycle."""

from pathlib import Path

import pytest

from test_elxosc import wait_for_property


@pytest.mark.real_host
def test_real_player_shell_mode_updates_and_pointer_notifications(real_host_factory):
    script = Path(__file__).parent / "shell.lua"
    with real_host_factory(f"--script={script}") as (client, _, process, log):
        wait_for_property(client, process, log, "user-data/elxosc-shell-mode", "auto")

        assert client.command("script-message", "elxosc-shell-mode", "always") is None
        wait_for_property(client, process, log, "user-data/elxosc-shell-mode", "always")

        assert client.command("script-message", "elxosc-shell-pointer", "move") is None
        wait_for_property(client, process, log, "user-data/elxosc-shell-pointer", "move")
        assert client.command("script-message", "elxosc-shell-pointer", "leave") is None
        wait_for_property(client, process, log, "user-data/elxosc-shell-pointer", "leave")

        assert client.command("script-message", "elxosc-shell-mode", "never") is None
        wait_for_property(client, process, log, "user-data/elxosc-shell-mode", "never")
        assert process.poll() is None
