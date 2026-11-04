"""The threat simulation also goes through the alert hook, marked as a simulation."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import edutrace_ultimate as et  # noqa: E402


class HemenCalisan:
    """Run the simulation thread synchronously."""

    def __init__(self, target, daemon=None):
        self.target = target

    def start(self):
        self.target()


def _simule_et(monkeypatch, tavsiye):
    olaylar = []
    monkeypatch.setattr(et.threading, "Thread", HemenCalisan)
    monkeypatch.setattr(et.time, "sleep", lambda s: None)
    monkeypatch.setattr(et.egitici_motor, "tavsiye_uret", tavsiye)
    monkeypatch.setattr(et.socketio, "emit", lambda olay, veri=None, **_k: olaylar.append(olay))
    et.simulasyon_baslat.__wrapped__({})
    return olaylar


def test_simulasyon_pro_bildirim_kancasini_cagirir(monkeypatch, sahte_pro):
    eklenti = sahte_pro()
    olaylar = _simule_et(monkeypatch, lambda *a, **k: "rapor")
    assert "islem_sonucu" in olaylar
    assert len(eklenti.bildirilen) == 1
    ip, saldiri_turu, _islem, _aciklama = eklenti.bildirilen[0]
    assert ip == "203.0.113.42" and saldiri_turu.startswith("[Simulasyon]")


def test_ai_hata_verse_de_bildirim_gider(monkeypatch, sahte_pro):
    eklenti = sahte_pro()

    def patla(*a, **k):
        raise RuntimeError("gemini yok")

    olaylar = _simule_et(monkeypatch, patla)
    assert "islem_sonucu" in olaylar  # fallback report
    assert len(eklenti.bildirilen) == 1
