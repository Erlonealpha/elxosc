"""Process and IPC helpers for tests against an actual (isolated) mpv host."""

import ctypes
import json
import os
import shutil
import socket
import subprocess
import time
import uuid
from contextlib import contextmanager
from pathlib import Path

import pytest

from lifecycle import OwnedProcess


ELXOSC_SOURCE_DIRS = ("animation", "backends", "foundation", "host", "layout", "libs",
                       "painting", "render", "scheduler", "text", "widget")

# Top-level runtime modules `main.lua` requires next to the package dirs.
ELXOSC_ROOT_MODULES = ("main_layout.lua", "demo.lua")


def _stage_lua_tree(source, destination):
    """Copy runtime Lua modules only, never checkout metadata or local secrets."""
    if not source.is_dir():
        return
    for file in source.rglob("*.lua"):
        if any(part.startswith(".") for part in file.relative_to(source).parts):
            continue
        target = destination / file.relative_to(source)
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(file, target)


def _stage_elxosc(source, destination, include_main=True):
    destination.mkdir(parents=True, exist_ok=True)
    for directory in ELXOSC_SOURCE_DIRS:
        _stage_lua_tree(source / directory, destination / directory)
    for module in ELXOSC_ROOT_MODULES:
        shutil.copy2(source / module, destination / module)
    if include_main:
        shutil.copy2(source / "main.lua", destination / "main.lua")
        shutil.copy2(source / "elxlib_load.lua", destination / "elxlib_load.lua")


def find_host():
    """An explicit override wins; an invalid override must not fall back."""
    override = os.environ.get("ELXOSC_MPV_BINARY")
    if override:
        return shutil.which(override)
    for name in ("mpvnet.com", "mpv.com", "mpv.exe"):
        executable = shutil.which(name)
        if executable:
            return executable
    return None


class IpcClient:
    def __init__(self, address):
        self.address = address
        self.request_id = 0

    def command(self, *args, timeout=5):
        self.request_id += 1
        payload = (json.dumps({"command": list(args), "request_id": self.request_id}) + "\n").encode()
        if os.name == "nt":
            response = self._windows_request(payload, timeout)
        else:
            with socket.socket(socket.AF_UNIX) as conn:
                conn.settimeout(timeout)
                conn.connect(self.address)
                conn.sendall(payload)
                response = b""
                while not self._contains_reply(response):
                    chunk = conn.recv(65536)
                    if not chunk:
                        raise ConnectionError("mpv IPC closed before replying")
                    response += chunk
        # mpv may send unsolicited events before the command reply.
        message = None
        for line in response.splitlines():
            candidate = json.loads(line)
            if candidate.get("request_id") == self.request_id:
                message = candidate
                break
        if message is None:
            raise RuntimeError(f"mpv IPC reply missing request_id {self.request_id}: {response!r}")
        assert message["error"] == "success", message
        return message.get("data")

    def _contains_reply(self, response):
        for line in response.splitlines():
            try:
                if json.loads(line).get("request_id") == self.request_id:
                    return True
            except json.JSONDecodeError:
                continue
        return False

    def _windows_request(self, payload, timeout):
        # mpv uses Windows named pipes here; Python's socket module cannot open them.
        kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
        kernel32.CreateFileW.argtypes = [ctypes.c_wchar_p, ctypes.c_uint32, ctypes.c_uint32,
                                         ctypes.c_void_p, ctypes.c_uint32, ctypes.c_uint32,
                                         ctypes.c_void_p]
        kernel32.CreateFileW.restype = ctypes.c_void_p
        kernel32.WriteFile.argtypes = [ctypes.c_void_p, ctypes.c_void_p, ctypes.c_uint32,
                                       ctypes.POINTER(ctypes.c_uint32), ctypes.c_void_p]
        kernel32.PeekNamedPipe.argtypes = [ctypes.c_void_p, ctypes.c_void_p, ctypes.c_uint32,
                                           ctypes.c_void_p, ctypes.POINTER(ctypes.c_uint32),
                                           ctypes.c_void_p]
        kernel32.ReadFile.argtypes = kernel32.WriteFile.argtypes
        kernel32.ReadFile.restype = ctypes.c_int
        kernel32.CloseHandle.argtypes = [ctypes.c_void_p]
        kernel32.CloseHandle.restype = ctypes.c_int
        handle = kernel32.CreateFileW(self.address, 0xC0000000, 0, None, 3, 0, None)
        if handle == ctypes.c_void_p(-1).value:
            raise OSError(ctypes.get_last_error(), "opening mpv named pipe")
        try:
            written = ctypes.c_uint32()
            buffer = ctypes.create_string_buffer(payload)
            if not kernel32.WriteFile(handle, buffer, len(payload), ctypes.byref(written), None):
                raise OSError(ctypes.get_last_error(), "writing mpv named pipe")
            assert written.value == len(payload)
            deadline = time.monotonic() + timeout
            response = b""
            while not self._contains_reply(response):
                available = ctypes.c_uint32()
                if not kernel32.PeekNamedPipe(handle, None, 0, None, ctypes.byref(available), None):
                    raise OSError(ctypes.get_last_error(), "reading mpv named pipe")
                if available.value:
                    chunk = ctypes.create_string_buffer(min(available.value, 65536))
                    count = ctypes.c_uint32()
                    if not kernel32.ReadFile(handle, chunk, len(chunk), ctypes.byref(count), None):
                        raise OSError(ctypes.get_last_error(), "reading mpv named pipe")
                    response += chunk.raw[:count.value]
                elif time.monotonic() >= deadline:
                    raise TimeoutError("mpv IPC reply timed out")
                else:
                    time.sleep(0.02)
            return response
        finally:
            kernel32.CloseHandle(handle)


@contextmanager
def _running_host(tmp_path, extra_args=()):
    executable = find_host()
    if not executable:
        pytest.skip("no mpvnet.com/mpv executable available (ELXOSC_MPV_BINARY may override)")

    config = tmp_path / "config"
    config.mkdir()
    # elxlib_load.lua resolves the shared runtime from the isolated config's
    # scripts directory. Stage only the runtime modules (and native modules),
    # excluding the sibling checkout's tests, metadata and unrelated files.
    source_elxlib = Path(__file__).parents[3] / "elxlib"
    if source_elxlib.is_dir():
        staged_elxlib = config / "scripts" / "elxlib"
        _stage_lua_tree(source_elxlib / "elxlibs", staged_elxlib / "elxlibs")
        for name in ("init.lua", "main.lua", "version.lua"):
            shutil.copy2(source_elxlib / name, staged_elxlib / name)
        for file in (source_elxlib / "bin").rglob("*.dll"):
            target = staged_elxlib / "bin" / file.relative_to(source_elxlib / "bin")
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(file, target)
    staged_args = []
    for argument in extra_args:
        if argument.startswith("--script="):
            script = Path(argument.removeprefix("--script="))
            source_elxosc = Path(__file__).parents[2]
            if script.is_file() and (script == source_elxosc / "main.lua" or
                                     script in {Path(__file__).parent / "button_input.lua",
                                                 Path(__file__).parent / "text_anchor.lua",
                                                 Path(__file__).parent / "scale.lua",
                                                 Path(__file__).parent / "transform.lua"}):
                staged_elxosc = config / "scripts" / "elxosc"
                _stage_elxosc(source_elxosc, staged_elxosc, include_main=script.name == "main.lua")
                if script.name in {"button_input.lua", "text_anchor.lua", "scale.lua", "transform.lua"}:
                    fixture = staged_elxosc / "main.lua"
                    shutil.copy2(script, fixture)
                # Load the directory package, matching portable_config/scripts/elxosc.
                # Loading main.lua as a standalone file omits the package search
                # path and makes mp.get_script_directory() return nil.
                argument = f"--script={staged_elxosc}"
        staged_args.append(argument)
    if os.name == "nt":
        address = rf"\\.\pipe\elxosc-test-{uuid.uuid4().hex}"
    else:
        address = str(tmp_path / "ipc.sock")
    log = tmp_path / "host.log"
    with log.open("wb") as output:
        process = subprocess.Popen(
            [executable, f"--config-dir={config}", "--idle=yes", "--force-window=no", "--load-scripts=no",
             f"--input-ipc-server={address}", *staged_args],
            stdin=subprocess.DEVNULL, stdout=output, stderr=subprocess.STDOUT,
            start_new_session=(os.name != "nt"),
        )
        owned = OwnedProcess(process)
        client = IpcClient(address)
        try:
            deadline = time.monotonic() + 10
            while time.monotonic() < deadline:
                if process.poll() is not None:
                    break
                try:
                    client.command("get_property", "mpv-version", timeout=0.5)
                    break
                except (OSError, ConnectionError, TimeoutError, RuntimeError):
                    time.sleep(0.1)
            else:
                pytest.fail(f"host IPC did not become available; log: {log.read_text(errors='replace')[-2000:]}")
            if process.poll() is not None:
                pytest.fail(f"host exited ({process.returncode}); log: {log.read_text(errors='replace')[-2000:]}")
            yield client, config, process, log
        finally:
            owned.cleanup(lambda: client.command("quit", timeout=2), timeout=5)


@pytest.fixture
def real_host(tmp_path):
    with _running_host(tmp_path) as (client, config, _, _):
        yield client, config


@pytest.fixture
def real_host_factory(tmp_path):
    """Start an isolated host with extra command-line options when needed."""
    def start(*extra_args):
        return _running_host(tmp_path, extra_args)
    return start
