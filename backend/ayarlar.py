"""Admin-only JSON settings files (block records, add-on settings).

These files can hold secrets (an add-on's notification credentials), so they
are readable only by Administrators and SYSTEM, the same as auth.token. The
elevated engine is the only writer; the dashboard changes them over the
authenticated socket and never gets secrets back.
"""

from __future__ import annotations

import json
import os
import subprocess
import sys
import threading
from typing import Any


def gizli_dosya_yaz(yol: str, icerik: str) -> None:
    """Write a file that only Administrators and SYSTEM can open."""
    os.makedirs(os.path.dirname(yol) or ".", exist_ok=True)
    gecici = yol + ".tmp"
    if os.path.exists(gecici):
        os.remove(gecici)
    os.close(os.open(gecici, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600))
    if sys.platform == "win32":
        sonuc = subprocess.run(
            ["icacls", gecici, "/inheritance:r", "/grant:r", "*S-1-5-32-544:F", "*S-1-5-18:F"],
            capture_output=True, timeout=10, check=False, shell=False,
        )
        if sonuc.returncode != 0:
            os.remove(gecici)
            raise OSError(f"icacls basarisiz: {sonuc.stdout or sonuc.stderr}")
    with open(gecici, "w", encoding="utf-8") as f:
        f.write(icerik)
    os.replace(gecici, yol)


class GizliAyarlar:
    """Thread-safe JSON settings with partial updates."""

    def __init__(self, yol: str) -> None:
        self.yol = yol
        self._kilit = threading.Lock()
        self._veri: dict[str, Any] = self._oku()

    def _oku(self) -> dict[str, Any]:
        try:
            with open(self.yol, encoding="utf-8") as f:
                veri = json.load(f)
            return veri if isinstance(veri, dict) else {}
        except (OSError, ValueError):
            return {}

    def al(self, anahtar: str, varsayilan: Any = None) -> Any:
        with self._kilit:
            return self._veri.get(anahtar, varsayilan)

    def hepsi(self) -> dict[str, Any]:
        with self._kilit:
            return dict(self._veri)

    def guncelle(self, degisiklikler: dict[str, Any]) -> None:
        """Merge and persist; a value of ``None`` removes the key."""
        with self._kilit:
            for anahtar, deger in degisiklikler.items():
                if deger is None:
                    self._veri.pop(anahtar, None)
                else:
                    self._veri[anahtar] = deger
            gizli_dosya_yaz(self.yol, json.dumps(self._veri, ensure_ascii=False, indent=2))
