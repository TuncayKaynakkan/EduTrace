"""Tests for the block-or-report decision (VirusTotal, firewall and Gemini are mocked)."""

import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import edutrace_ultimate as et  # noqa: E402

IP = "198.51.100.7"  # RFC 5737 test address


@pytest.mark.parametrize(
    ("kaynak", "vt_skor", "beklenen"),
    [
        (et.KAYNAK_IMZA, 0, True),       # concrete attack behaviour: block even if VT is clean
        (et.KAYNAK_ESIK, 0, True),
        (et.KAYNAK_ML, 0, False),        # VT says clean: an anomaly alone is not enough
        (et.KAYNAK_ML, 3, True),         # VT confirms: block
        (et.KAYNAK_ML, "YEREL AG (N/A)", False),  # private IP shortcut is not evidence
        (et.KAYNAK_ML, None, False),     # VT unavailable
        (et.KAYNAK_ML, True, False),     # bool is not a score
    ],
)
def test_engelleme_karari(kaynak, vt_skor, beklenen):
    assert et.engelleme_karari(kaynak, {"vt_skor": vt_skor}) is beklenen


@pytest.fixture
def ortam(monkeypatch):
    engellenen, olaylar = [], []
    monkeypatch.setattr(et, "FIREWALL_BLOCK", True)
    monkeypatch.setattr(et, "ENGELLENEN_IPLER", set())
    monkeypatch.setattr(
        et.firewall, "ip_engelle",
        lambda ip: (engellenen.append(ip), et.firewall.FirewallResult(True, "engellendi"))[1],
    )
    monkeypatch.setattr(et.egitici_motor, "tavsiye_uret", lambda *a, **k: "rapor")
    monkeypatch.setattr(et.socketio, "emit", lambda olay, veri=None, **_k: olaylar.append((olay, veri)))

    def vt(skor):
        karar = "ENGELLE" if isinstance(skor, int) and skor > 0 else "IZIN_VER"
        monkeypatch.setattr(
            et.tehdit_motoru, "analiz_et_ve_karar_ver",
            lambda ip: {"ip": ip, "vt_skor": skor, "otonom_karar": karar},
        )

    return engellenen, olaylar, vt


def test_dogrulanmamis_ml_anomalisi_engellenmez_ama_bildirilir(ortam):
    engellenen, olaylar, vt = ortam
    vt(0)
    et._tehdit_isle(IP, "chrome.exe", None, "Yapay Zeka Anomali Tespiti", "", et.KAYNAK_ML)

    assert engellenen == []
    assert IP not in et.ENGELLENEN_IPLER  # keeps being monitored
    assert olaylar and olaylar[0][0] == "islem_bildirimi"
    assert olaylar[0][1]["durum"] == "bilgi"


def test_virustotal_dogruladigi_ml_anomalisi_engellenir(ortam):
    engellenen, olaylar, vt = ortam
    vt(5)
    et._tehdit_isle(IP, "x.exe", None, "Yapay Zeka Anomali Tespiti", "", et.KAYNAK_ML)

    assert engellenen == [IP]
    assert any(olay == "islem_sonucu" for olay, _ in olaylar)


def test_imza_alarmi_virustotal_temiz_olsa_da_engellenir(ortam):
    engellenen, _, vt = ortam
    vt(0)
    et._tehdit_isle(IP, "x.exe", None, "TCP SYN Flood (DoS)", "", et.KAYNAK_IMZA)

    assert engellenen == [IP]
