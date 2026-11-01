"""Tests for the offline blocklists (downloads are mocked; nothing touches the network)."""

import json
import os
import sys
import time
from pathlib import Path
from unittest.mock import MagicMock

import pytest
import requests

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import threat_intel as ti  # noqa: E402

SPAMHAUS_V4 = "\n".join([
    '{"cidr":"203.0.113.0/24","sblid":"SBL111111","rir":"apnic"}',
    '{"cidr":"198.51.100.128/25","sblid":"SBL222222","rir":"arin"}',
    '{"type":"metadata","timestamp":1793531642,"size":107142,"records":2,'
    '"copyright":"(c) 2026 The Spamhaus Project SLU","terms":"https://www.spamhaus.org/drop/terms/"}',
])
SPAMHAUS_V6 = '{"cidr":"2001:db8:bad::/48","sblid":"SBL333333","rir":"ripencc"}\n'
FEODO = json.dumps([
    {"ip_address": "192.0.2.50", "status": "online", "malware": "QakBot"},
    {"ip_address": "192.0.2.60", "status": "offline", "malware": "Emotet"},
])


def test_spamhaus_ayristirma_metadata_satirini_atlar():
    aglar = ti.spamhaus_ayristir(SPAMHAUS_V4)
    assert [str(ag) for ag, _ in aglar] == ["203.0.113.0/24", "198.51.100.128/25"]
    assert aglar[0][1] == "SBL111111"


def test_feodo_sadece_cevrimici_c2_sunucularini_alir():
    assert ti.feodo_ayristir(FEODO) == {"192.0.2.50": "QakBot"}


def test_bozuk_dosyalar_cokertmez():
    assert ti.spamhaus_ayristir("bu json degil\n{yarim") == []
    assert ti.feodo_ayristir("{bozuk") == {}


@pytest.fixture
def listeler(tmp_path):
    (tmp_path / ti.SPAMHAUS_V4).write_text(SPAMHAUS_V4, encoding="utf-8")
    (tmp_path / ti.SPAMHAUS_V6).write_text(SPAMHAUS_V6, encoding="utf-8")
    (tmp_path / ti.FEODO).write_text(FEODO, encoding="utf-8")
    motor = ti.TehditListeleri(str(tmp_path))
    motor.yukle()
    return motor


@pytest.mark.parametrize(
    ("ip", "beklenen"),
    [
        ("203.0.113.77", [ti.Eslesme("Spamhaus DROP", "SBL111111")]),
        ("198.51.100.200", [ti.Eslesme("Spamhaus DROP", "SBL222222")]),
        ("198.51.100.5", []),                                            # outside the /25
        ("2001:db8:bad::1", [ti.Eslesme("Spamhaus DROP", "SBL333333")]),  # IPv6
        ("2001:db8:bad:0::1", [ti.Eslesme("Spamhaus DROP", "SBL333333")]),  # other spelling
        ("192.0.2.50", [ti.Eslesme("Feodo Tracker", "QakBot")]),
        ("192.0.2.60", []),                                              # offline C2 ignored
        ("192.168.1.1", []),
        ("bu-ip-degil", []),
    ],
)
def test_kontrol_et(listeler, ip, beklenen):
    assert listeler.kontrol_et(ip) == beklenen


def _yanit(icerik: bytes):
    yanit = MagicMock()
    yanit.content = icerik
    yanit.raise_for_status = lambda: None
    return yanit


def test_eski_liste_indirilir_ve_yuklenir(tmp_path, monkeypatch):
    istekler = []

    def sahte_get(url, **kwargs):
        istekler.append((url, kwargs.get("headers", {}).get("User-Agent")))
        icerik = {ti.KAYNAKLAR[ti.SPAMHAUS_V4]: SPAMHAUS_V4, ti.KAYNAKLAR[ti.SPAMHAUS_V6]: SPAMHAUS_V6}
        return _yanit(icerik.get(url, FEODO).encode())

    monkeypatch.setattr(ti.requests, "get", sahte_get)
    motor = ti.TehditListeleri(str(tmp_path))
    motor.guncelle()

    assert len(istekler) == 3 and all(ua.startswith("EduTrace/") for _, ua in istekler)
    assert motor.kontrol_et("203.0.113.1") and motor.kontrol_et("192.0.2.50")
    # Spamhaus terms: the file is stored unmodified, copyright line included
    assert "The Spamhaus Project" in (tmp_path / ti.SPAMHAUS_V4).read_text(encoding="utf-8")


def test_taze_liste_tekrar_indirilmez(listeler, monkeypatch):
    monkeypatch.setattr(ti.requests, "get", lambda *a, **k: pytest.fail("taze liste indirilmemeli"))
    listeler.guncelle()


def test_indirme_hatasinda_eski_kopya_korunur(listeler, tmp_path, monkeypatch):
    eski = time.time() - ti.YENILEME_SN - 60
    for dosya in ti.KAYNAKLAR:
        os.utime(tmp_path / dosya, (eski, eski))

    def hata(*a, **k):
        raise requests.ConnectionError("internet yok")

    monkeypatch.setattr(ti.requests, "get", hata)
    listeler.guncelle()

    assert listeler.kontrol_et("203.0.113.77") == [ti.Eslesme("Spamhaus DROP", "SBL111111")]
