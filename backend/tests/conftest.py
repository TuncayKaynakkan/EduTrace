"""Shared fixtures: keep tests away from the real %PROGRAMDATA%/EduTrace files."""

import sys

import pytest


@pytest.fixture(autouse=True)
def _gecici_veri(monkeypatch, tmp_path):
    et = sys.modules.get("edutrace_ultimate")
    if et is None:
        yield
        return
    from olay_gecmisi import OlayGecmisi

    monkeypatch.setattr(et, "olay_gecmisi", OlayGecmisi(":memory:"))
    monkeypatch.setattr(et, "engel_kayitlari", et.GizliAyarlar(str(tmp_path / "engellenenler.json")))
    # Core tests run the free edition unless a test installs a fake Pro add-on
    monkeypatch.setattr(et, "pro", et.ProKancalari(et.socketio))
    yield
    et.imza_motoru.ayarla()


@pytest.fixture
def sahte_pro(monkeypatch):
    """Install a Pro add-on whose hooks return what the test asks for."""
    et = sys.modules["edutrace_ultimate"]

    def kur(**kancalar):
        class SahtePro(et.ProKancalari):
            aktif = True
            bildirilen: list = []

            def gecmis_gun_siniri(self):
                return kancalar.get("gun", 30)

            def beyaz_listede(self, ip):
                return ip in kancalar.get("beyaz_liste", ())

            def oto_firewall(self):
                return kancalar.get("firewall", False)

            def oto_sonlandir(self):
                return kancalar.get("sonlandir", False)

            def alarm_sonrasi(self, *args):
                self.bildirilen.append(args)

        eklenti = SahtePro(et.socketio)
        eklenti.bildirilen = []
        monkeypatch.setattr(et, "pro", eklenti)
        return eklenti

    return kur
