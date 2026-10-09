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
    if os.name == "nt":
        address = rf"\\.\pipe\elxosc-test-{uuid.uuid4().hex}"
    else:
        address = str(tmp_path / "ipc.sock")
    log = tmp_path / "host.log"
    with log.open("wb") as output:
        process = subprocess.Popen(
            [executable, f"--config-dir={config}", "--idle=yes", "--force-window=no",
             f"--input-ipc-server={address}", *extra_args],
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
            yield client, config, process
        finally:
            owned.cleanup(lambda: client.command("quit", timeout=2), timeout=5)


@pytest.fixture
def real_host(tmp_path):
    with _running_host(tmp_path) as (client, config, _):
        yield client, config


@pytest.fixture
def real_host_factory(tmp_path):
    """Start an isolated host with extra command-line options when needed."""
    def start(*extra_args):
        return _running_host(tmp_path, extra_args)
    return start
