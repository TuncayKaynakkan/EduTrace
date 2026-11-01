"""Alert history and the edition-dependent history window."""

import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import edutrace_ultimate as et  # noqa: E402
from olay_gecmisi import GUN_SN, SAKLAMA_GUN, OlayGecmisi  # noqa: E402

TOKEN = "test-token-123"


def test_gecmis_yeniden_eskiye_ve_pencereye_gore_listelenir():
    saat = [100 * GUN_SN]
    g = OlayGecmisi(":memory:", saat=lambda: saat[0])
    g.kaydet("198.51.100.1", "SYN Flood", "imza", "", "engellendi", True)
    saat[0] += 2 * GUN_SN
    g.kaydet("198.51.100.2", "UDP Flood", "imza", "", "engellendi", True)

    assert [o["ip"] for o in g.listele(1)] == ["198.51.100.2"]
    assert [o["ip"] for o in g.listele(3)] == ["198.51.100.2", "198.51.100.1"]
    assert g.listele(3)[0]["engellendi"] is True


def test_saklama_suresini_gecen_kayitlar_silinir():
    saat = [100 * GUN_SN]
    g = OlayGecmisi(":memory:", saat=lambda: saat[0])
    g.kaydet("198.51.100.1", "eski", "imza", "", "", True)
    saat[0] += (SAKLAMA_GUN + 1) * GUN_SN
    g.kaydet("198.51.100.2", "yeni", "imza", "", "", True)
    assert [o["saldiri_turu"] for o in g.listele(1000)] == ["yeni"]


def test_acilamayan_veritabani_motoru_durdurmaz(tmp_path):
    # A directory where the file should be: sqlite cannot open it
    (tmp_path / "olaylar.db").mkdir()
    g = OlayGecmisi(str(tmp_path / "olaylar.db"))
    g.kaydet("198.51.100.1", "x", "imza", "", "", True)
    assert len(g.listele(1)) == 1


@pytest.fixture
def istemci(monkeypatch):
    monkeypatch.setattr(et, "AUTH_TOKEN", TOKEN)
    saat = [100 * GUN_SN]
    g = OlayGecmisi(":memory:", saat=lambda: saat[0])
    g.kaydet("198.51.100.1", "eski", "imza", "", "", True)
    saat[0] += 5 * GUN_SN
    g.kaydet("198.51.100.2", "yeni", "imza", "", "", True)
    monkeypatch.setattr(et, "olay_gecmisi", g)
    c = et.socketio.test_client(et.app, auth={"token": TOKEN})
    yield c
    c.disconnect()


def _gecmis(c):
    return [e["args"][0] for e in c.get_received() if e["name"] == "gecmis"][0]


def test_ucretsiz_surum_yalnizca_son_24_saati_gosterir(istemci):
    istemci.emit("gecmis_iste", {"gun": 30})
    yanit = _gecmis(istemci)
    assert yanit["gun"] == 1 and [o["saldiri_turu"] for o in yanit["olaylar"]] == ["yeni"]


def test_pro_eklentisi_pencereyi_genisletebilir(istemci, sahte_pro):
    sahte_pro(gun=30)
    istemci.emit("gecmis_iste", {"gun": 30})
    assert len(_gecmis(istemci)["olaylar"]) == 2


@pytest.mark.parametrize("istek", [{"gun": "abc"}, {"gun": -5}, None, "x"])
def test_bozuk_gun_istegi_bir_gune_duser(istek):
    assert et.gecmis_gunu(istek) == 1


def test_islenen_tehdit_gecmise_yazilir(monkeypatch):
    monkeypatch.setattr(et.tehdit_listeleri, "kontrol_et", lambda ip: [])
    monkeypatch.setattr(et.egitici_motor, "tavsiye_uret", lambda *a, **k: "rapor")
    monkeypatch.setattr(et.socketio, "emit", lambda *a, **k: None)
    monkeypatch.setattr(et._background_executor, "submit", lambda f, *a: f(*a))
    et._tehdit_isle("198.51.100.9", "x.exe", None, "SYN Flood", "", et.KAYNAK_IMZA)
    et._tehdit_isle("198.51.100.8", "x.exe", None, "Anomali", "", et.KAYNAK_ML)
    kayitlar = {o["ip"]: o["engellendi"] for o in et.olay_gecmisi.listele(1)}
    assert kayitlar == {"198.51.100.9": True, "198.51.100.8": False}
