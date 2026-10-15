"""A live mpv host routes synthetic coordinates through the real Button tree."""

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
            last = None  # The script may not have registered the property yet.
        if last == expected:
            return
        time.sleep(0.05)
    pytest.fail(f"{name}: expected {expected!r}, last observed {last!r}; "
                f"host log:\n{log.read_text(errors='replace')}")


@pytest.mark.real_host
def test_button_click_and_outside_release(real_host_factory):
    script = Path(__file__).with_name("button_input.lua")
    with real_host_factory(f"--script={script}") as (client, _, process, log):
        wait_for_property(client, process, log, "user-data/elxosc-test-loaded", "yes")
        wait_for_property(client, process, log, "user-data/elxosc-test-ready", "yes")
        for event, x, y in (("down", 40, 20), ("up", 40, 20)):
            client.command("script-message", "elxosc-test-pointer", event, str(x), str(y))
        wait_for_property(client, process, log, "user-data/elxosc-test-seen", "up")
        wait_for_property(client, process, log, "user-data/elxosc-test-dispatched", "2")
        wait_for_property(client, process, log, "user-data/elxosc-test-clicks", "1")

        for event, x, y in (("down", 40, 20), ("up", 10000, 10000)):
            client.command("script-message", "elxosc-test-pointer", event, str(x), str(y))
        wait_for_property(client, process, log, "user-data/elxosc-test-dispatched", "4")
        assert client.command("get_property", "user-data/elxosc-test-clicks") == "1"


@pytest.mark.real_host
def test_real_mouse_area_claims_button_double_click_only(real_host_factory, tmp_path):
    script = Path(__file__).with_name("button_input.lua")
    input_conf = tmp_path / "input.conf"
    input_conf.write_text(
        "MBTN_LEFT_DBL cycle fullscreen\n",
        encoding="utf-8",
    )
    with real_host_factory(f"--script={script}", f"--input-conf={input_conf}") as (
        client, _, process, log
    ):
        wait_for_property(client, process, log, "user-data/elxosc-test-ready", "yes")
        client.command("set_property", "fullscreen", "no")

        # The fixture's Button occupies the upper-left area around (40, 20).
        # The actual mpv `mouse` command exercises coordinate conversion,
        # section-area selection, and the generated mbtn_left_dbl binding.
        client.command("mouse", 40, 20, 0, "double")
        wait_for_property(client, process, log, "user-data/elxosc-test-clicks", "0")
        wait_for_property(client, process, log, "fullscreen", False)

        # Outside the interactive area, the user input.conf binding must remain
        # visible through the active elxosc sections.
        client.command("mouse", 300, 300, 0, "double")
        wait_for_property(client, process, log, "fullscreen", True)
