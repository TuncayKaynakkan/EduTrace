"""A forged source address must not get a resolver or a connected host blocked."""

import sys
from pathlib import Path
from types import SimpleNamespace

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import edutrace_ultimate as et  # noqa: E402


@pytest.fixture
def ortam(monkeypatch, sahte_pro):
    engellenen, olaylar = [], []
    monkeypatch.setattr(et, "ENGELLENEN_IPLER", set())
    monkeypatch.setattr(
        et.firewall, "ip_engelle",
        lambda ip: (engellenen.append(ip), et.firewall.FirewallResult(True, "ok"))[1],
    )
    monkeypatch.setattr(et.tehdit_listeleri, "kontrol_et", lambda ip: [])
    monkeypatch.setattr(et.egitici_motor, "tavsiye_uret", lambda *a, **k: "rapor")
    monkeypatch.setattr(et.socketio, "emit", lambda olay, veri=None, **_k: olaylar.append((olay, veri)))
    monkeypatch.setattr(et._background_executor, "submit", lambda f, *a: f(*a))
    sahte_pro(firewall=True)
    return engellenen, olaylar


def _saldiri(ip):
    et._tehdit_isle(ip, "x.exe", None, "UDP Flood / DDoS", "", et.KAYNAK_IMZA)


def test_dns_sunucusu_sahte_flood_ile_engellenmez(ortam):
    engellenen, olaylar = ortam
    _saldiri("8.8.8.8")
    assert engellenen == [] and "8.8.8.8" not in et.ENGELLENEN_IPLER
    assert olaylar[-1][1]["durum"] == "bilgi"


def test_etkin_bagli_host_engellenmez(ortam, monkeypatch):
    engellenen, _ = ortam
    bagli = SimpleNamespace(status="ESTABLISHED", raddr=SimpleNamespace(ip="198.51.100.20"))
    monkeypatch.setattr(et, "_baglantilar", lambda: [bagli])
    _saldiri("198.51.100.20")
    assert engellenen == []


def test_bagli_olmayan_saldirgan_yine_engellenir(ortam):
    engellenen, _ = ortam
    _saldiri("198.51.100.77")
    assert engellenen == ["198.51.100.77"]
