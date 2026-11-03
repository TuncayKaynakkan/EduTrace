"""Encrypt secrets at rest with Windows DPAPI (current-user scope).

Values are stored as ``dpapi:<base64>``. Only the same Windows user on the same
machine can decrypt them, so a copied settings file, a backup or another user
learns nothing. A process running as that user could still decrypt, which is
why the files holding these values are also readable only by Administrators
and SYSTEM (see ayarlar.gizli_dosya_yaz).

Values without the prefix are treated as legacy plaintext and returned as is,
so older settings keep working until they are saved again.
"""

from __future__ import annotations

import base64
import sys

ONEK = "dpapi:"
# Ties the blobs to EduTrace: another DPAPI user cannot decrypt them by accident
_ENTROPI = b"EduTrace/gizli/v1"


class GizliHata(Exception):
    """A value could not be encrypted or decrypted."""


if sys.platform == "win32":
    import ctypes
    from ctypes import wintypes

    class _Blob(ctypes.Structure):
        _fields_ = [("cbData", wintypes.DWORD), ("pbData", ctypes.POINTER(ctypes.c_char))]

    _crypt32 = ctypes.WinDLL("crypt32", use_last_error=True)
    _kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
    _CRYPTPROTECT_UI_FORBIDDEN = 0x1

    def _blob(veri: bytes) -> tuple[_Blob, ctypes.Array]:
        tampon = ctypes.create_string_buffer(veri, len(veri))
        return _Blob(len(veri), ctypes.cast(tampon, ctypes.POINTER(ctypes.c_char))), tampon

    def _cagir(islev, veri: bytes) -> bytes:
        giris, _g = _blob(veri)
        entropi, _e = _blob(_ENTROPI)
        cikis = _Blob()
        if not islev(ctypes.byref(giris), None, ctypes.byref(entropi), None, None,
                     _CRYPTPROTECT_UI_FORBIDDEN, ctypes.byref(cikis)):
            raise GizliHata(f"DPAPI hatasi {ctypes.get_last_error()}")
        try:
            return ctypes.string_at(cikis.pbData, cikis.cbData)
        finally:
            _kernel32.LocalFree(cikis.pbData)

    def _koru(veri: bytes) -> bytes:
        return _cagir(_crypt32.CryptProtectData, veri)

    def _coz(veri: bytes) -> bytes:
        return _cagir(_crypt32.CryptUnprotectData, veri)

else:  # pragma: no cover - EduTrace runs on Windows; keep imports working elsewhere
    def _koru(veri: bytes) -> bytes:
        raise GizliHata("DPAPI yalnizca Windows'ta var")

    def _coz(veri: bytes) -> bytes:
        raise GizliHata("DPAPI yalnizca Windows'ta var")


def sifreli_mi(deger: str) -> bool:
    return isinstance(deger, str) and deger.startswith(ONEK)


def sifrele(metin: str) -> str:
    """Encrypt a secret for storage; an empty value stays empty."""
    if not metin:
        return ""
    return ONEK + base64.b64encode(_koru(metin.encode("utf-8"))).decode("ascii")


def coz(deger: str) -> str:
    """Decrypt a stored value; legacy plaintext is returned unchanged."""
    if not sifreli_mi(deger):
        return deger or ""
    try:
        return _coz(base64.b64decode(deger[len(ONEK):])).decode("utf-8")
    except (ValueError, UnicodeDecodeError) as exc:
        raise GizliHata(f"Bozuk sifreli deger: {exc}") from exc
