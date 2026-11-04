"""Move/click only inside a window owned by the isolated host process tree."""

import ctypes
import os
import time
from ctypes import wintypes


class _ProcessEntry(ctypes.Structure):
    _fields_ = [("size", wintypes.DWORD), ("usage", wintypes.DWORD),
               ("pid", wintypes.DWORD), ("heap", ctypes.c_size_t),
               ("module", wintypes.DWORD), ("threads", wintypes.DWORD),
               ("parent", wintypes.DWORD), ("priority", wintypes.LONG),
               ("flags", wintypes.DWORD), ("exe", wintypes.WCHAR * 260)]


def _descendants(root):
    kernel = ctypes.WinDLL("kernel32", use_last_error=True)
    kernel.CreateToolhelp32Snapshot.restype = wintypes.HANDLE
    kernel.Process32FirstW.argtypes = [wintypes.HANDLE, ctypes.POINTER(_ProcessEntry)]
    kernel.Process32NextW.argtypes = kernel.Process32FirstW.argtypes
    kernel.CloseHandle.argtypes = [wintypes.HANDLE]
    snapshot = kernel.CreateToolhelp32Snapshot(2, 0)
    if snapshot == ctypes.c_void_p(-1).value:
        raise ctypes.WinError(ctypes.get_last_error())
    parents = {}
    entry = _ProcessEntry()
    entry.size = ctypes.sizeof(entry)
    try:
        found = kernel.Process32FirstW(snapshot, ctypes.byref(entry))
        while found:
            parents[entry.pid] = entry.parent
            found = kernel.Process32NextW(snapshot, ctypes.byref(entry))
    finally:
        kernel.CloseHandle(snapshot)
    owned = {root}
    while True:
        extended = owned | {pid for pid, parent in parents.items() if parent in owned}
        if extended == owned:
            return owned
        owned = extended


class WindowInput:
    def __init__(self, process, client):
        self.process, self.client = process, client
        self.user = None
        self.hwnd = None
        if os.name == "nt":
            self.user = ctypes.WinDLL("user32", use_last_error=True)
            self.user.SetProcessDpiAwarenessContext.argtypes = [wintypes.HANDLE]
            self.user.SetProcessDpiAwarenessContext(ctypes.c_void_p(-4))
            self.user.GetWindowThreadProcessId.argtypes = [wintypes.HWND, ctypes.POINTER(wintypes.DWORD)]
            self.user.IsWindowVisible.argtypes = [wintypes.HWND]
            self.user.GetClientRect.argtypes = [wintypes.HWND, ctypes.POINTER(wintypes.RECT)]
            self.user.ClientToScreen.argtypes = [wintypes.HWND, ctypes.POINTER(wintypes.POINT)]
            self.user.SetForegroundWindow.argtypes = [wintypes.HWND]
            self.user.GetClassNameW.argtypes = [wintypes.HWND, wintypes.LPWSTR, ctypes.c_int]
            self.original_cursor = wintypes.POINT()
            self.user.GetCursorPos(ctypes.byref(self.original_cursor))
            owned = _descendants(process.pid)
            candidates = []
            callback_type = ctypes.WINFUNCTYPE(wintypes.BOOL, wintypes.HWND, wintypes.LPARAM)

            def visit(hwnd, _):
                pid = wintypes.DWORD()
                self.user.GetWindowThreadProcessId(hwnd, ctypes.byref(pid))
                rect = wintypes.RECT()
                window_class = ctypes.create_unicode_buffer(256)
                self.user.GetClassNameW(hwnd, window_class, len(window_class))
                if pid.value in owned and self.user.IsWindowVisible(hwnd):
                    self.user.GetClientRect(hwnd, ctypes.byref(rect))
                    area = (rect.right - rect.left) * (rect.bottom - rect.top)
                    if area > 10000 and window_class.value != 'ConsoleWindowClass':
                        candidates.append((area, hwnd))
                return True

            self.user.EnumWindows(callback_type(visit), 0)
            if not candidates:
                raise RuntimeError("isolated host has no visible owned window")
            self.hwnd = max(candidates)[1]
            self.user.SetForegroundWindow(self.hwnd)

    def move(self, x, y):
        if self.process.poll() is not None:
            raise RuntimeError("host exited before pointer input")
        if self.user:
            pid = wintypes.DWORD()
            self.user.GetWindowThreadProcessId(self.hwnd, ctypes.byref(pid))
            if pid.value not in _descendants(self.process.pid):
                raise RuntimeError("window no longer belongs to the isolated host")
            rect = wintypes.RECT()
            self.user.GetClientRect(self.hwnd, ctypes.byref(rect))
            if not (0 <= x < rect.right and 0 <= y < rect.bottom):
                raise ValueError("pointer position lies outside the owned client area")
            point = wintypes.POINT(int(x), int(y))
            self.user.ClientToScreen(self.hwnd, ctypes.byref(point))
            if not self.user.SetCursorPos(point.x, point.y):
                raise ctypes.WinError(ctypes.get_last_error())
        else:
            self.client.command("mouse", int(x), int(y))

    def click(self, x, y):
        self.move(x, y)
        time.sleep(0.1)
        if self.user:
            self.user.mouse_event(2, 0, 0, 0, 0)
            time.sleep(0.02)
            self.user.mouse_event(4, 0, 0, 0, 0)
        else:
            self.client.command("keydown", "MBTN_LEFT")
            self.client.command("keyup", "MBTN_LEFT")

    def __enter__(self):
        return self

    def __exit__(self, *_):
        if self.user:
            self.user.SetCursorPos(self.original_cursor.x, self.original_cursor.y)
