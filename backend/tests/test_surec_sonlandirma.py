"""Manual process kill and block: the engine must not trust the client's claims."""

import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import edutrace_ultimate as et  # noqa: E402


@pytest.fixture
def ortam(monkeypatch):
    sonlandirilan, olaylar = [], []
    adlar = {600: "lsass.exe", 4321: "oyun.exe", 999: "gizli.exe"}

    class Surec:
        def __init__(self, pid):
            self.pid = pid

        def name(self):
            return adlar[self.pid]

        def terminate(self):
            sonlandirilan.append(self.pid)

    monkeypatch.setattr(et.psutil, "Process", Surec)
    monkeypatch.setattr(et.socketio, "emit", lambda olay, veri=None, **_k: olaylar.append((olay, veri)))
    monkeypatch.setattr(et, "_aktif_pidler", {600, 4321})
    return sonlandirilan, olaylar


def test_istemcinin_yalan_adi_korunan_sureci_oldurmez(ortam):
    sonlandirilan, _ = ortam
    # Client claims a harmless name for lsass.exe's PID
    et.surec_sonlandir.__wrapped__({"ad": "oyun.exe", "pids": [600]})
    assert sonlandirilan == []


def test_listede_olmayan_pid_sonlandirilmaz(ortam):
    sonlandirilan, olaylar = ortam
    et.surec_sonlandir.__wrapped__({"ad": "gizli.exe", "pids": [999]})
    assert sonlandirilan == []
    assert olaylar[-1][1]["durum"] == "hata"


def test_listedeki_normal_surec_sonlandirilir(ortam):
    sonlandirilan, olaylar = ortam
    et.surec_sonlandir.__wrapped__({"ad": "oyun.exe", "pids": [4321]})
    assert sonlandirilan == [4321]
    assert olaylar[-1][1]["durum"] == "basarili"


@pytest.mark.parametrize("veri", [None, "x", {"pids": "600"}, {"pids": ["abc", None]}])
def test_bozuk_istek_cokmez(ortam, veri):
    sonlandirilan, _ = ortam
    et.surec_sonlandir.__wrapped__(veri)
    assert sonlandirilan == []


def test_basarisiz_engel_ip_yi_algilamadan_cikarmaz(monkeypatch):
    monkeypatch.setattr(et, "ENGELLENEN_IPLER", set())
    monkeypatch.setattr(et.socketio, "emit", lambda *a, **k: None)
    monkeypatch.setattr(et.firewall, "ip_engelle", lambda ip: et.firewall.FirewallResult(False, "hata"))
    et.ip_manuel_engelle.__wrapped__({"ip": "198.51.100.9"})
    et.ip_manuel_engelle.__wrapped__({"ip": "not-an-ip"})
    et.ip_manuel_engelle.__wrapped__(None)
    assert et.ENGELLENEN_IPLER == set()


@pytest.mark.parametrize("deger,beklenen", [
    ("127.0.0.1", "127.0.0.1"), ("::1", "::1"),
    ("0.0.0.0", "127.0.0.1"), ("192.168.1.5", "127.0.0.1"), ("localhost", "127.0.0.1"), ("", "127.0.0.1"),
])
def test_motor_yalnizca_yerel_adreste_dinler(deger, beklenen):
    assert et.sunucu_adresi_sec(deger) == beklenen


def test_dns_sunucusu_manuel_engellenmez(monkeypatch):
    cagrilar = []
    monkeypatch.setattr(et.socketio, "emit", lambda *a, **k: None)
    monkeypatch.setattr(et.firewall, "ip_engelle", lambda ip: cagrilar.append(ip))
    et.ip_manuel_engelle.__wrapped__({"ip": "8.8.8.8"})
    assert cagrilar == []
