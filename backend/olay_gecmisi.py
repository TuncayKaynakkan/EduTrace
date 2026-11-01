"""Persistent alert history (SQLite).

Every alert is stored for ``SAKLAMA_GUN`` days. The free edition shows the
last 24 hours; Pro shows the whole period and can export it.
"""

from __future__ import annotations

import os
import sqlite3
import threading
import time
from typing import Any, Callable

SAKLAMA_GUN = 30
GUN_SN = 24 * 3600


class OlayGecmisi:
    """Thread-safe store for alerts the engine handled."""

    def __init__(self, yol: str, saat: Callable[[], float] = time.time) -> None:
        self._saat = saat
        self._kilit = threading.Lock()
        try:
            if yol != ":memory:":
                os.makedirs(os.path.dirname(yol) or ".", exist_ok=True)
            self._db = sqlite3.connect(yol, check_same_thread=False)
            self._tablo_olustur()
        except (OSError, sqlite3.Error) as exc:
            # History is not worth stopping the engine for; keep it in memory instead
            print(f"[!] Olay gecmisi acilamadi ({exc}); bu oturum icin bellekte tutulacak.")
            self._db = sqlite3.connect(":memory:", check_same_thread=False)
            self._tablo_olustur()

    def _tablo_olustur(self) -> None:
        self._db.execute(
            """CREATE TABLE IF NOT EXISTS olaylar (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                zaman REAL NOT NULL,
                ip TEXT NOT NULL,
                saldiri_turu TEXT NOT NULL,
                kaynak TEXT NOT NULL,
                aciklama TEXT NOT NULL,
                islem TEXT NOT NULL,
                engellendi INTEGER NOT NULL
            )"""
        )
        self._db.execute("CREATE INDEX IF NOT EXISTS olaylar_zaman ON olaylar (zaman)")
        self._db.commit()

    def kaydet(
        self, ip: str, saldiri_turu: str, kaynak: str, aciklama: str, islem: str, engellendi: bool
    ) -> None:
        simdi = self._saat()
        with self._kilit:
            self._db.execute(
                "INSERT INTO olaylar (zaman, ip, saldiri_turu, kaynak, aciklama, islem, engellendi)"
                " VALUES (?, ?, ?, ?, ?, ?, ?)",
                (simdi, ip, saldiri_turu, kaynak, aciklama, islem, int(engellendi)),
            )
            # Retention: drop anything older than the Pro window
            self._db.execute("DELETE FROM olaylar WHERE zaman < ?", (simdi - SAKLAMA_GUN * GUN_SN,))
            self._db.commit()

    def listele(self, gun: float, limit: int = 1000) -> list[dict[str, Any]]:
        """Alerts from the last ``gun`` days, newest first."""
        sinir = self._saat() - gun * GUN_SN
        with self._kilit:
            satirlar = self._db.execute(
                "SELECT zaman, ip, saldiri_turu, kaynak, aciklama, islem, engellendi"
                " FROM olaylar WHERE zaman >= ? ORDER BY zaman DESC, id DESC LIMIT ?",
                (sinir, int(limit)),
            ).fetchall()
        alanlar = ("zaman", "ip", "saldiri_turu", "kaynak", "aciklama", "islem", "engellendi")
        return [
            {**dict(zip(alanlar, satir)), "engellendi": bool(satir[6])}
            for satir in satirlar
        ]
