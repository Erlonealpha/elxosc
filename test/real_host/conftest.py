"""Process and IPC helpers for tests against an actual (isolated) mpv host."""

import ctypes
import json
import os
import shutil
import socket
import subprocess
import time
import uuid
from pathlib import Path

import pytest


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
                while b"\n" not in response:
                    chunk = conn.recv(65536)
                    if not chunk:
                        raise ConnectionError("mpv IPC closed before replying")
                    response += chunk
        message = json.loads(response.split(b"\n", 1)[0])
        assert message["request_id"] == self.request_id, message
        assert message["error"] == "success", message
        return message.get("data")

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
            while b"\n" not in response:
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


@pytest.fixture
def real_host(tmp_path):
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
             f"--input-ipc-server={address}"],
            stdin=subprocess.DEVNULL, stdout=output, stderr=subprocess.STDOUT,
        )
        client = IpcClient(address)
        try:
            deadline = time.monotonic() + 10
            while time.monotonic() < deadline:
                if process.poll() is not None:
                    break
                try:
                    client.command("get_property", "mpv-version", timeout=0.5)
                    break
                except (OSError, ConnectionError, TimeoutError):
                    time.sleep(0.1)
            else:
                pytest.skip(f"host IPC did not become available; log: {log.read_text(errors='replace')[-2000:]}")
            if process.poll() is not None:
                pytest.skip(f"host exited ({process.returncode}); log: {log.read_text(errors='replace')[-2000:]}")
            yield client, config
        finally:
            if process.poll() is None:
                process.terminate()
                try:
                    process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait(timeout=5)
