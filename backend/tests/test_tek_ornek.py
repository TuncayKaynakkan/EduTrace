"""Only one engine may run; a second one must not touch auth.token."""

import subprocess
import sys
import uuid
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import edutrace_ultimate as et  # noqa: E402

pytestmark = pytest.mark.skipif(sys.platform != "win32", reason="Windows mutex")

KILIT_KODU = """
import ctypes, sys, time
from ctypes import wintypes
k = ctypes.WinDLL("kernel32", use_last_error=True)
k.CreateMutexW.restype = wintypes.HANDLE
k.CreateMutexW(None, False, "Global\\\\" + sys.argv[1])
print("hazir", flush=True)
time.sleep(30)
"""


def test_baska_motor_kilidi_tutarken_ikinci_kopya_calismaz(monkeypatch):
    ad = f"EduTraceTest-{uuid.uuid4().hex}"
    monkeypatch.setattr(et, "_tek_ornek_tutamaci", None)
    diger = subprocess.Popen([sys.executable, "-c", KILIT_KODU, ad], stdout=subprocess.PIPE, text=True)
    try:
        assert diger.stdout.readline().strip() == "hazir"
        assert et.tek_ornek_kilidi_al(ad) is False
    finally:
        diger.kill()
        diger.wait()


def test_kilit_bosken_alinir_ve_tutulur(monkeypatch):
    ad = f"EduTraceTest-{uuid.uuid4().hex}"
    monkeypatch.setattr(et, "_tek_ornek_tutamaci", None)
    assert et.tek_ornek_kilidi_al(ad) is True
    assert et._tek_ornek_tutamaci  # kept open for the engine's lifetime
