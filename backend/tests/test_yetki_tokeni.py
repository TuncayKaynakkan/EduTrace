"""auth.token creation: a token the panel cannot read must not be used."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import edutrace_ultimate as et  # noqa: E402


def test_token_dosyaya_yazilir_ve_doner(monkeypatch, tmp_path):
    yol = tmp_path / "EduTrace" / "auth.token"
    monkeypatch.setattr(et, "token_dosyasi_yolu", lambda: str(yol))
    token = et.yetki_tokeni_olustur()
    assert token and yol.read_text(encoding="utf-8") == token


def test_yazilamayan_token_bos_doner(monkeypatch, tmp_path):
    # A file where the folder should be: the token cannot be written
    (tmp_path / "EduTrace").write_text("x")
    monkeypatch.setattr(et, "token_dosyasi_yolu", lambda: str(tmp_path / "EduTrace" / "auth.token"))
    assert et.yetki_tokeni_olustur() == ""
