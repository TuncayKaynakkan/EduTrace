"""Tests for the block-or-report decision (threat lists, firewall and Gemini are mocked)."""

import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import edutrace_ultimate as et  # noqa: E402
from threat_intel import Eslesme  # noqa: E402

IP = "198.51.100.7"  # RFC 5737 test address


@pytest.mark.parametrize(
    ("kaynak", "skor", "beklenen"),
    [
        (et.KAYNAK_IMZA, 0, True),       # concrete attack behaviour: block even if no list knows the IP
        (et.KAYNAK_ESIK, 0, True),
        (et.KAYNAK_ML, 0, False),        # not on any list: an anomaly alone is not enough
        (et.KAYNAK_ML, 2, True),         # on a blocklist: block
        (et.KAYNAK_ML, None, False),     # lists unavailable
        (et.KAYNAK_ML, True, False),     # bool is not a score
    ],
)
def test_engelleme_karari(kaynak, skor, beklenen):
    assert et.engelleme_karari(kaynak, {"istihbarat_skoru": skor}) is beklenen


@pytest.fixture
def ortam(monkeypatch):
    engellenen, olaylar, raporlar = [], [], []
    monkeypatch.setattr(et, "FIREWALL_BLOCK", True)
    monkeypatch.setattr(et, "ENGELLENEN_IPLER", set())
    monkeypatch.setattr(
        et.firewall, "ip_engelle",
        lambda ip: (engellenen.append(ip), et.firewall.FirewallResult(True, "engellendi"))[1],
    )
    monkeypatch.setattr(
        et.egitici_motor, "tavsiye_uret",
        lambda exe, ip, istihbarat, saldiri_turu="": (raporlar.append(istihbarat), "rapor")[1],
    )
    monkeypatch.setattr(et.socketio, "emit", lambda olay, veri=None, **_k: olaylar.append((olay, veri)))

    def listede(*eslesmeler):
        monkeypatch.setattr(et.tehdit_listeleri, "kontrol_et", lambda ip: list(eslesmeler))

    return engellenen, olaylar, raporlar, listede


def test_listede_olmayan_ml_anomalisi_engellenmez_ama_bildirilir(ortam):
    engellenen, olaylar, _, listede = ortam
    listede()
    et._tehdit_isle(IP, "chrome.exe", None, "Yapay Zeka Anomali Tespiti", "", et.KAYNAK_ML)

    assert engellenen == []
    assert IP not in et.ENGELLENEN_IPLER  # keeps being monitored
    assert olaylar and olaylar[0][0] == "islem_bildirimi"
    assert olaylar[0][1]["durum"] == "bilgi"


def test_tehdit_listesindeki_ml_anomalisi_engellenir(ortam):
    engellenen, olaylar, raporlar, listede = ortam
    listede(Eslesme("Spamhaus DROP", "SBL123456"))
    et._tehdit_isle(IP, "x.exe", None, "Yapay Zeka Anomali Tespiti", "", et.KAYNAK_ML)

    assert engellenen == [IP]
    assert any(olay == "islem_sonucu" for olay, _ in olaylar)
    assert raporlar == ["Spamhaus DROP (SBL123456)"]  # the AI report says which list matched


def test_imza_alarmi_listede_olmasa_da_engellenir(ortam):
    engellenen, _, raporlar, listede = ortam
    listede()
    et._tehdit_isle(IP, "x.exe", None, "TCP SYN Flood (DoS)", "", et.KAYNAK_IMZA)

    assert engellenen == [IP]
    assert raporlar == ["Bilinen tehdit listelerinde yok"]
