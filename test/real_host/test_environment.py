"""The baseline is a real host responding over IPC, not a stubbed mp object."""

import os
from pathlib import Path

import pytest


@pytest.mark.real_host
def test_isolated_host_responds_to_ipc(real_host):
    client, config = real_host
    version = client.command("get_property", "mpv-version")
    assert isinstance(version, str) and version.startswith("mpv")
    expanded = client.command("expand-path", "~~/")
    assert Path(expanded).resolve() == config.resolve()
    # A harmless script-message exercises the IPC dispatch path even when no
    # user scripts are installed in this deliberately empty config directory.
    assert client.command("script-message", "elxosc-real-host-probe") is None
