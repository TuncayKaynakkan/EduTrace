"""Forged-source floods must not grow memory forever; a poisoned list must not block everything."""

import json
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import edutrace_ultimate as et  # noqa: E402
from threat_intel import spamhaus_ayristir  # noqa: E402
from threat_rules import ThreatSignatureEngine  # noqa: E402


def test_bir_kez_gorulen_ip_pencere_dolunca_silinir(monkeypatch):
    motor = ThreatSignatureEngine(window_seconds=60)
    for i in range(100):
        motor.kayit_ekle(f"198.51.100.{i}", 80, "UDP", 0)
    assert len(motor._history) == 100
    gercek = time.time
    monkeypatch.setattr(time, "time", lambda: gercek() + 120)
    motor.eskileri_temizle()
    assert motor._history == {}


def test_engine_tablolari_temizlenir(monkeypatch):
    now = time.time()
    monkeypatch.setattr(et, "_last_traffic_emit", {"1.2.3.4": now - 500, "5.6.7.8": now})
    monkeypatch.setattr(et, "_last_threat_time", {"1.2.3.4": now - 500, "5.6.7.8": now})
    et.eski_kayitlari_temizle()
    assert list(et._last_traffic_emit) == ["5.6.7.8"]
    assert list(et._last_threat_time) == ["5.6.7.8"]


def test_zehirli_liste_tum_interneti_kapsayamaz():
    satirlar = "\n".join(json.dumps(k) for k in (
        {"cidr": "0.0.0.0/0", "sblid": "SBLX"},
        {"cidr": "::/0", "sblid": "SBLY"},
        {"cidr": "64.0.0.0/4", "sblid": "SBLZ"},
        {"cidr": "203.0.113.0/24", "sblid": "SBL1"},
    ))
    assert [str(ag) for ag, _ in spamhaus_ayristir(satirlar)] == ["203.0.113.0/24"]
