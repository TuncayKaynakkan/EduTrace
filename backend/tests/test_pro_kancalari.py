"""Loading the optional Pro add-on: missing or broken add-ons fall back to free."""

import sys
import types
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import edutrace_ultimate as et  # noqa: E402


def test_eklenti_yoksa_ucretsiz_kancalar(monkeypatch):
    monkeypatch.setattr(et.importlib.util, "find_spec", lambda ad: None)
    pro = et.pro_eklentisini_yukle()
    assert type(pro) is et.ProKancalari
    assert not pro.aktif and pro.gecmis_gun_siniri() == 1
    assert not (pro.oto_firewall() or pro.oto_sonlandir() or pro.beyaz_listede("1.2.3.4"))


def test_eklenti_kur_ile_motoru_alir(monkeypatch):
    alinan = []

    class Eklenti(et.ProKancalari):
        aktif = True

    modul = types.SimpleNamespace(kur=lambda motor: (alinan.append(motor), Eklenti(motor.socketio))[1])
    monkeypatch.setattr(et.importlib.util, "find_spec", lambda ad: object())
    monkeypatch.setattr(et.importlib, "import_module", lambda ad: modul)
    pro = et.pro_eklentisini_yukle()
    assert pro.aktif and alinan == [sys.modules["edutrace_ultimate"]]


def test_bozuk_eklenti_motoru_durdurmaz(monkeypatch):
    def patla(ad):
        raise ImportError("reportlab yok")

    monkeypatch.setattr(et.importlib.util, "find_spec", lambda ad: object())
    monkeypatch.setattr(et.importlib, "import_module", patla)
    assert type(et.pro_eklentisini_yukle()) is et.ProKancalari
