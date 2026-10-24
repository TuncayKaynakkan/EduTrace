"""Socket.IO authentication tests (Flask-SocketIO test client; no real network)."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import edutrace_ultimate as et  # noqa: E402


import pytest  # noqa: E402

TOKEN = "test-token-123"


@pytest.fixture(autouse=True)
def _token(monkeypatch):
    monkeypatch.setattr(et, "AUTH_TOKEN", TOKEN)
    monkeypatch.setattr(et, "AUTO_TERMINATE", False)
    monkeypatch.setattr(et, "IS_PRO_USER", False)


def test_tokensiz_istemci_baglanamaz():
    istemci = et.socketio.test_client(et.app)
    assert not istemci.is_connected()


def test_yanlis_token_ile_baglanilamaz():
    istemci = et.socketio.test_client(et.app, auth={"token": "tahmin"})
    assert not istemci.is_connected()


def test_tokensiz_istemci_otonom_savunmayi_acamaz():
    istemci = et.socketio.test_client(et.app)
    if istemci.is_connected():
        # The attack: any local program claims to be "Pro" and turns on process killing
        istemci.emit("lisans_durumu", {"is_pro": True})
    assert et.AUTO_TERMINATE is False


def test_dogru_token_ile_panel_calisir():
    istemci = et.socketio.test_client(et.app, auth={"token": TOKEN})
    assert istemci.is_connected()
    istemci.emit("lisans_durumu", {"is_pro": True})
    assert et.AUTO_TERMINATE is True
    istemci.disconnect()


def test_token_tanimsizken_herkes_reddedilir(monkeypatch):
    # Fail closed: if the token file could not be created, nobody gets in
    monkeypatch.setattr(et, "AUTH_TOKEN", "")
    istemci = et.socketio.test_client(et.app, auth={"token": ""})
    assert not istemci.is_connected()


def test_yetkisiz_olay_dogrudan_cagrilsa_da_islenmez():
    # Defence in depth: even if a handler is reached without an authenticated sid
    with et.app.test_request_context():
        from flask import request
        request.sid = "kimligi-dogrulanmamis"
        et.lisans_durumu_al({"is_pro": True})
    assert et.AUTO_TERMINATE is False
