"""Auto-response hooks and undoing blocks (firewall and processes are mocked)."""

import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import edutrace_ultimate as et  # noqa: E402

IP = "198.51.100.7"


@pytest.fixture
def ortam(monkeypatch):
    engellenen, kaldirilan, sonlandirilan, olaylar = [], [], [], []
    monkeypatch.setattr(et, "ENGELLENEN_IPLER", set())
    monkeypatch.setattr(
        et.firewall, "ip_engelle",
        lambda ip: (engellenen.append(ip), et.firewall.FirewallResult(True, "engellendi"))[1],
    )
    monkeypatch.setattr(
        et.firewall, "ip_engeli_kaldir",
        lambda ip: (kaldirilan.append(ip), et.firewall.FirewallResult(True, "kaldirildi"))[1],
    )

    class Surec:
        def __init__(self, pid):
            self.pid = pid

        def terminate(self):
            sonlandirilan.append(self.pid)

    monkeypatch.setattr(et.psutil, "Process", Surec)
    monkeypatch.setattr(et.tehdit_listeleri, "kontrol_et", lambda ip: [])
    monkeypatch.setattr(et.egitici_motor, "tavsiye_uret", lambda *a, **k: "rapor")
    monkeypatch.setattr(et.socketio, "emit", lambda olay, veri=None, **_k: olaylar.append((olay, veri)))
    monkeypatch.setattr(et._background_executor, "submit", lambda f, *a: f(*a))
    return engellenen, kaldirilan, sonlandirilan, olaylar


def _saldiri(pid=None):
    et._tehdit_isle(IP, "kotu.exe", pid, "TCP SYN Flood (DoS)", "", et.KAYNAK_IMZA)


def test_ucretsiz_surumde_otomatik_mudahale_yok(ortam):
    engellenen, _, sonlandirilan, olaylar = ortam
    _saldiri(pid=1234)
    assert engellenen == [] and sonlandirilan == []
    # Still reported, but it must not claim the IP was blocked
    sonuc = next(v for o, v in olaylar if o == "islem_sonucu")
    assert "tespit edildi" in sonuc["mesaj"] or "PID" in sonuc["mesaj"]


def test_pro_kancalari_acikken_engeller_sonlandirir_ve_bildirir(ortam, sahte_pro):
    engellenen, _, sonlandirilan, _ = ortam
    eklenti = sahte_pro(firewall=True, sonlandir=True)
    _saldiri(pid=1234)
    assert engellenen == [IP] and sonlandirilan == [1234]
    assert et.engel_kayitlari.al(IP)["neden"] == "TCP SYN Flood (DoS)"
    assert eklenti.bildirilen and eklenti.bildirilen[0][0] == IP


def test_korunan_surec_pro_da_sonlandirilmaz(ortam, sahte_pro):
    _, _, sonlandirilan, _ = ortam
    sahte_pro(sonlandir=True)
    et._tehdit_isle(IP, "lsass.exe", 600, "TCP SYN Flood (DoS)", "", et.KAYNAK_IMZA)
    assert sonlandirilan == []


def test_beyaz_listedeki_ip_yok_sayilir(ortam, sahte_pro):
    engellenen, _, _, olaylar = ortam
    sahte_pro(firewall=True, beyaz_liste={IP})
    _saldiri()
    assert engellenen == [] and olaylar == []


def test_engel_geri_alinir_ve_ip_tekrar_izlenir(ortam, sahte_pro):
    _, kaldirilan, _, olaylar = ortam
    sahte_pro(firewall=True)
    _saldiri()
    assert IP in et.ENGELLENEN_IPLER

    et.engeli_kaldir.__wrapped__({"ip": IP})
    assert kaldirilan == [IP]
    assert IP not in et.ENGELLENEN_IPLER
    assert et.engel_kayitlari.al(IP) is None
    assert olaylar[-1] == ("engellenenler", [])


def test_edutracein_engellemedigi_ip_kaldirilamaz(ortam):
    _, kaldirilan, _, olaylar = ortam
    et.engeli_kaldir.__wrapped__({"ip": "8.8.8.8"})
    assert kaldirilan == []
    assert olaylar[-1][1]["durum"] == "hata"


def test_manuel_engel_kaydedilir_ve_ucretsiz_kaldirilir(ortam):
    engellenen, kaldirilan, _, _ = ortam
    et.ip_manuel_engelle.__wrapped__({"ip": IP})
    assert engellenen == [IP] and et.engel_kayitlari.al(IP)["neden"] == "Manuel engelleme"
    et.engeli_kaldir.__wrapped__({"ip": IP})
    assert kaldirilan == [IP]
