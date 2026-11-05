"""Smoke test for loading the real elxosc entry point in mpv.net."""

from pathlib import Path
import time
import wave
from window_input import WindowInput

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
    with real_host_factory(f"--script={script}", "--force-window=yes",
                           "--geometry=1280x720") as (client, _, process, log):
        # The command must be accepted while the script is loaded. The Lua
        # handler increments DemoState; the host remaining alive is the
        # portable observable result available through mpv IPC.
        wait_for_property(client, process, log, "user-data/elxosc-demo-open", "false")
        client.command("script-message", "elxosc-demo-open")
        wait_for_property(client, process, log, "user-data/elxosc-demo-count", "0")
        assert client.command("script-message", "elxosc-demo") is None
        assert process.poll() is None
        wait_for_property(client, process, log, "user-data/elxosc-demo-count", "1")
        count = client.command("get_property", "user-data/elxosc-demo-count")
        assert count == "1"
        dimensions = client.command("get_property", "osd-dimensions")
        assert dimensions is not None


def wait_for_navigation_key(client, process, log, enabled, timeout=5):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        assert process.poll() is None, log.read_text(errors="replace")
        bindings = client.command("get_property", "input-bindings")
        claimed = any(binding.get("section") == "elxosc-navigation"
                      and binding.get("key") == "ESC"
                      and binding.get("priority", -1) >= 0 for binding in bindings)
        if claimed == enabled:
            return
        time.sleep(0.05)
    pytest.fail(f"navigation ESC enabled={enabled} not reached; "
                f"host log:\n{log.read_text(errors='replace')}")


@pytest.mark.real_host
def test_define_demo_button_opens_closes_and_reopens(real_host_factory, tmp_path):
    script = Path(__file__).parents[2] / "main.lua"
    media = tmp_path / "demo-controls.wav"
    with wave.open(str(media), "wb") as stream:
        stream.setparams((1, 2, 48000, 0, "NONE", "not compressed"))
        stream.writeframes(bytes(48000 * 2 * 12))
    with real_host_factory(f"--script={script}", "--force-window=yes",
                           "--geometry=1280x720") as (client, _, process, log):
        wait_for_property(client, process, log, "user-data/elxosc-demo-open", "false")
        client.command("set_property", "pause", True)
        client.command("loadfile", str(media))
        wait_for_property(client, process, log, "idle-active", False)
        dimensions = client.command("get_property", "osd-dimensions")
        width, height = dimensions["w"], dimensions["h"]
        with WindowInput(process, client) as pointer:
            x, y = int(width - 127 * 1.5), int(height - 40 * 1.5)
            pointer.move(x, y)
            deadline = time.monotonic() + 5
            while True:
                bindings = client.command("get_property", "input-bindings")
                if any(binding.get("section", "").startswith("elxosc-input")
                       and binding.get("key") == "MBTN_LEFT"
                       and binding.get("priority", -1) >= 0 for binding in bindings):
                    break
                assert time.monotonic() < deadline, "Main input sections were not enabled"
                time.sleep(0.05)
            pointer.click(x, y)
            wait_for_property(client, process, log, "user-data/elxosc-demo-open", "true")
            wait_for_property(client, process, log, "user-data/elxosc-demo-count", "0")
            client.command("script-message", "elxosc-demo")
            wait_for_property(client, process, log, "user-data/elxosc-demo-count", "1")
            pointer.click(width - 72, 80)
            wait_for_property(client, process, log, "user-data/elxosc-demo-open", "false")
            wait_for_navigation_key(client, process, log, False)
            pointer.click(x, y)
            wait_for_property(client, process, log, "user-data/elxosc-demo-open", "true")
            wait_for_property(client, process, log, "user-data/elxosc-demo-count", "0")


@pytest.mark.real_host
def test_autohide_clears_thumbfast_without_a_pointer_leave(real_host_factory, tmp_path):
    script = Path(__file__).parents[2] / "main.lua"
    # Protocol peer proves the production script-message-to boundary. It does
    # not replace the external decoder or claim pixel-level thumbnail evidence.
    peer = tmp_path / "thumbfast.lua"
    peer.write_text(
        "local mp = require 'mp'\n"
        "local requests, clears = 0, 0\n"
        "mp.register_script_message('announce', function()\n"
        "    mp.commandv('script-message', 'thumbfast-info', "
        "'{\"width\":320,\"height\":180,\"available\":true,\"disabled\":false}')\n"
        "end)\n"
        "mp.register_script_message('thumb', function()\n"
        "    requests = requests + 1\n"
        "    mp.set_property('user-data/elxosc-test-thumb-state', 'visible')\n"
        "    mp.set_property('user-data/elxosc-test-thumb-requests', tostring(requests))\n"
        "end)\n"
        "mp.register_script_message('clear', function()\n"
        "    clears = clears + 1\n"
        "    mp.set_property('user-data/elxosc-test-thumb-state', 'cleared')\n"
        "    mp.set_property('user-data/elxosc-test-thumb-clears', tostring(clears))\n"
        "end)\n"
        "mp.set_property('user-data/elxosc-test-thumb-state', 'ready')\n",
        encoding="utf-8",
    )
    media = tmp_path / "thumb-controls.wav"
    with wave.open(str(media), "wb") as stream:
        stream.setparams((1, 2, 48000, 0, "NONE", "not compressed"))
        stream.writeframes(bytes(48000 * 2 * 12))
    with real_host_factory(f"--script={script}", "--force-window=yes",
                           "--geometry=1280x720") as (client, _, process, log):
        wait_for_property(client, process, log, "user-data/elxosc-demo-open", "false")
        client.command("load-script", str(peer))
        wait_for_property(client, process, log, "user-data/elxosc-test-thumb-state", "ready")
        client.command("set_property", "pause", True)
        client.command("loadfile", str(media))
        wait_for_property(client, process, log, "idle-active", False)
        client.command("script-message-to", "thumbfast", "announce")
        time.sleep(0.3)
        dimensions = client.command("get_property", "osd-dimensions")
        width, height = dimensions["w"], dimensions["h"]
        with WindowInput(process, client) as pointer:
            x, y = int(width * 0.3), int(height - 100 * 1.5)
            pointer.move(x, y)
            wait_for_property(client, process, log, "user-data/elxosc-test-thumb-state", "visible")
            requests = client.command("get_property", "user-data/elxosc-test-thumb-requests")
            wait_for_property(client, process, log, "user-data/elxosc-test-thumb-state", "cleared")
            assert client.command("get_property", "user-data/elxosc-test-thumb-clears") == "1"
            assert client.command("get_property", "user-data/elxosc-test-thumb-requests") == requests
            pointer.move(x + 30, y)
            wait_for_property(client, process, log, "user-data/elxosc-test-thumb-state", "visible")
            pointer.move(int(width / 2), int(height / 2))
            wait_for_property(client, process, log, "user-data/elxosc-test-thumb-state", "cleared")
            assert client.command("get_property", "user-data/elxosc-test-thumb-clears") == "2"


@pytest.mark.real_host
def test_demo_navigation_returns_results_and_releases_escape(real_host_factory, tmp_path):
    script = Path(__file__).parents[2] / "main.lua"
    # mpv.net supplies its own default ESC=quit binding, overriding --input-conf.
    # A separate script gives both hosts an observable, non-navigation fallback.
    fallback = tmp_path / "host_escape.lua"
    fallback.write_text(
        "local mp = require 'mp'\n"
        "mp.add_forced_key_binding('ESC', 'host-escape', function()\n"
        "    mp.set_property('user-data/elxosc-test-escape', 'host')\n"
        "end)\n"
        "mp.set_property('user-data/elxosc-test-escape', 'ready')\n",
        encoding="utf-8",
    )
    with real_host_factory(f"--script={script}", "--force-window=yes",
                           "--geometry=1280x720") as (client, _, process, log):
        wait_for_property(client, process, log, "user-data/elxosc-demo-open", "false")
        client.command("script-message", "elxosc-demo-open")
        wait_for_property(client, process, log, "user-data/elxosc-demo-route", "home")
        client.command("load-script", str(fallback))
        wait_for_property(client, process, log, "user-data/elxosc-test-escape", "ready")
        # Navigation begins after the entry point's initialization-only assembly.
        deadline = time.monotonic() + 5
        while "define window closed" not in log.read_text(errors="replace"):
            assert process.poll() is None, log.read_text(errors="replace")
            assert time.monotonic() < deadline, log.read_text(errors="replace")
            time.sleep(0.05)
        wait_for_navigation_key(client, process, log, False)
        client.command("script-message", "elxosc-demo")
        wait_for_property(client, process, log, "user-data/elxosc-demo-count", "1")
        client.command("script-message", "elxosc-demo", "page")
        wait_for_property(client, process, log, "user-data/elxosc-demo-route", "details")
        wait_for_navigation_key(client, process, log, True)
        # The covered home State and its PlayerContext message bridge stay alive.
        client.command("script-message", "elxosc-demo")
        wait_for_property(client, process, log, "user-data/elxosc-demo-count", "2")
        client.command("keypress", "ESC")
        wait_for_property(client, process, log, "user-data/elxosc-demo-result", "Page: dismissed")
        wait_for_property(client, process, log, "user-data/elxosc-demo-returns", "1")
        wait_for_property(client, process, log, "user-data/elxosc-demo-route", "home")

        client.command("script-message", "elxosc-demo", "popup")
        wait_for_property(client, process, log, "user-data/elxosc-demo-route", "popup")
        wait_for_navigation_key(client, process, log, True)
        client.command("keypress", "ESC")
        wait_for_property(client, process, log, "user-data/elxosc-demo-result", "Popup: dismissed")
        wait_for_property(client, process, log, "user-data/elxosc-demo-returns", "2")
        wait_for_navigation_key(client, process, log, False)
        client.command("keypress", "ESC")
        wait_for_property(client, process, log, "user-data/elxosc-test-escape", "host")
        assert client.command("get_property", "user-data/elxosc-demo-count") == "2"
