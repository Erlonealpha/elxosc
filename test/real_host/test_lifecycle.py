"""Regression tests for ownership-bounded real-host cleanup."""

import subprocess
import sys
import time
import os

from lifecycle import OwnedProcess


def test_cleanup_invokes_graceful_shutdown_before_waiting():
    process = subprocess.Popen([sys.executable, "-c", "import time; time.sleep(30)"],
                               start_new_session=(os.name != "nt"))
    owned = OwnedProcess(process)
    calls = []
    owned.cleanup(lambda: (calls.append("quit"), process.terminate()), timeout=1)
    assert calls == ["quit"]
    assert process.poll() is not None


def test_cleanup_falls_back_when_graceful_shutdown_does_not_end_process():
    process = subprocess.Popen([sys.executable, "-c", "import time; time.sleep(30)"],
                               start_new_session=(os.name != "nt"))
    owned = OwnedProcess(process)
    owned.cleanup(lambda: time.sleep(0.01), timeout=0.1)
    assert process.poll() is not None
