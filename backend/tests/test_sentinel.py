"""Tests for the sniffer loop (packet capture is mocked; nothing touches the network)."""

import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import edutrace_ultimate as et  # noqa: E402


class _DonguyuDurdur(Exception):
    """Raised from the mocked time.sleep to break out of the infinite loop."""


def test_npcap_eksikken_motor_cokmez(monkeypatch):
    def npcap_yok(_sure):
        raise OSError("Npcap/WinPcap is not installed")

    def dur(_saniye):
        raise _DonguyuDurdur

    gonderilen = []
    monkeypatch.setattr(et, "ag_ronto_cek", npcap_yok)
    monkeypatch.setattr(et, "_last_npcap_warn", 0.0)
    monkeypatch.setattr(et.socketio, "emit", lambda olay, veri=None, **_k: gonderilen.append((olay, veri)))
    monkeypatch.setattr(et.time, "sleep", dur)

    # The loop must survive the capture error and reach the 5 s retry sleep.
    with pytest.raises(_DonguyuDurdur):
        et.edutrace_sentinel_motoru()

    assert gonderilen and gonderilen[0][0] == "islem_bildirimi"
    assert "Npcap" in gonderilen[0][1]["mesaj"]
