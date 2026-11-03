"""DPAPI-encrypted secrets and moving the old plaintext Gemini key."""

import json
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import edutrace_ultimate as et  # noqa: E402
import gizli  # noqa: E402

pytestmark = pytest.mark.skipif(sys.platform != "win32", reason="Windows DPAPI")

ANAHTAR = "AIzaSyTEST-anahtar-çğış"


def test_sifreleme_geri_cozulur_ve_duz_metin_icermez():
    sifreli = gizli.sifrele(ANAHTAR)
    assert sifreli.startswith(gizli.ONEK) and "AIza" not in sifreli
    assert gizli.coz(sifreli) == ANAHTAR


def test_eski_duz_metin_aynen_doner_bos_bos_kalir():
    assert gizli.coz("duz-anahtar") == "duz-anahtar"
    assert gizli.sifrele("") == "" and gizli.coz("") == ""


def test_bozuk_sifreli_deger_hata_verir():
    with pytest.raises(gizli.GizliHata):
        gizli.coz(gizli.ONEK + "AAAA")


@pytest.fixture
def motor(monkeypatch):
    olaylar, anahtarlar = [], []
    monkeypatch.setattr(et.socketio, "emit", lambda olay, veri=None, **_k: olaylar.append((olay, veri)))
    monkeypatch.setattr(et.egitici_motor, "guncelle_api_key", lambda k: (anahtarlar.append(k), bool(k))[1])
    return olaylar, anahtarlar


def test_panelden_gelen_anahtar_sifreli_saklanir(motor, tmp_path):
    olaylar, anahtarlar = motor
    et.gemini_key_guncelle_al.__wrapped__({"api_key": f"  {ANAHTAR} "})
    kayit = et.gizli_ayarlar.al("gemini_api_key")
    assert gizli.sifreli_mi(kayit) and gizli.coz(kayit) == ANAHTAR
    assert ANAHTAR not in (tmp_path / "gizli.json").read_text(encoding="utf-8")
    assert anahtarlar == [ANAHTAR]
    assert any(o == "ai_durumu" for o, _ in olaylar)
    # Nothing in the user profile any more
    assert not (tmp_path / "appdata").exists()


def test_bos_anahtar_kaydi_siler(motor):
    et.gemini_key_guncelle_al.__wrapped__({"api_key": ANAHTAR})
    et.gemini_key_guncelle_al.__wrapped__({"api_key": ""})
    assert et.gizli_ayarlar.al("gemini_api_key") is None


def test_eski_duz_metin_anahtar_tasinir_ve_silinir(motor, tmp_path):
    _, anahtarlar = motor
    klasor = tmp_path / "appdata" / "EduTrace"
    klasor.mkdir(parents=True)
    (klasor / "settings.json").write_text(
        json.dumps({"language": "tr", "gemini_api_key": ANAHTAR}), encoding="utf-8"
    )
    (klasor / ".env").write_text(f"\nGEMINI_API_KEY={ANAHTAR}\n\nGEMINI_API_KEY={ANAHTAR}\n", encoding="utf-8")

    et.gemini_anahtarini_hazirla()

    assert json.loads((klasor / "settings.json").read_text(encoding="utf-8")) == {"language": "tr"}
    assert not (klasor / ".env").exists()  # only held the leaked key
    assert gizli.coz(et.gizli_ayarlar.al("gemini_api_key")) == ANAHTAR
    assert anahtarlar == [ANAHTAR]


def test_env_deki_diger_satirlar_korunur(motor, tmp_path):
    klasor = tmp_path / "appdata" / "EduTrace"
    klasor.mkdir(parents=True)
    (klasor / ".env").write_text(f"SERVER_PORT=5000\nGEMINI_API_KEY={ANAHTAR}\n", encoding="utf-8")
    et.eski_gemini_anahtarlarini_tasi()
    assert (klasor / ".env").read_text(encoding="utf-8") == "SERVER_PORT=5000\n"


def test_kayitli_anahtar_eskisinin_ustune_yazilmaz(motor, tmp_path):
    et.gizli_ayarlar.guncelle({"gemini_api_key": gizli.sifrele("YENI")})
    klasor = tmp_path / "appdata" / "EduTrace"
    klasor.mkdir(parents=True)
    (klasor / "settings.json").write_text(json.dumps({"gemini_api_key": "ESKI"}), encoding="utf-8")
    et.gemini_anahtarini_hazirla()
    assert gizli.coz(et.gizli_ayarlar.al("gemini_api_key")) == "YENI"
