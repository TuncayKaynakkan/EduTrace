"""Offline threat intelligence from freely licensed IP blocklists.

Sources (both allow commercial use):
- Spamhaus DROP v4/v6: free for anyone; when used in a product, Spamhaus must
  be credited and the file's date and copyright kept
  (https://www.spamhaus.org/drop/terms/). Files are stored unmodified.
- abuse.ch Feodo Tracker: CC0 (https://abuse.ch/terms-of-use/).

Lists are downloaded at most every 12 hours and checked locally, so the IP
addresses this machine talks to never leave it.
"""

from __future__ import annotations

import ipaddress
import json
import os
import threading
import time
from dataclasses import dataclass

import requests

SPAMHAUS_V4 = "spamhaus_drop_v4.json"
SPAMHAUS_V6 = "spamhaus_drop_v6.json"
FEODO = "feodo_ipblocklist.json"

KAYNAKLAR = {
    SPAMHAUS_V4: "https://www.spamhaus.org/drop/drop_v4.json",
    SPAMHAUS_V6: "https://www.spamhaus.org/drop/drop_v6.json",
    FEODO: "https://feodotracker.abuse.ch/downloads/ipblocklist.json",
}
YENILEME_SN = 12 * 3600  # Spamhaus asks for no more than one download per hour
INDIRME_ZAMAN_ASIMI = 15
KULLANICI_AJANI = "EduTrace/1.1 (+https://github.com/TuncayKaynakkan/EduTrace)"


@dataclass(frozen=True)
class Eslesme:
    """One blocklist entry that matched an IP address."""

    kaynak: str
    detay: str


def spamhaus_ayristir(metin: str) -> list[tuple[ipaddress.IPv4Network | ipaddress.IPv6Network, str]]:
    """Parse a Spamhaus DROP NDJSON file into (network, SBL id) pairs; the metadata line is skipped."""
    aglar = []
    for satir in metin.splitlines():
        satir = satir.strip()
        if not satir:
            continue
        try:
            kayit = json.loads(satir)
            if "cidr" not in kayit:
                continue
            aglar.append((ipaddress.ip_network(kayit["cidr"], strict=False), str(kayit.get("sblid", ""))))
        except (ValueError, TypeError):
            continue
    return aglar


def feodo_ayristir(metin: str) -> dict[str, str]:
    """Parse the Feodo Tracker JSON list into {ip: malware} for C2 servers that are still online.

    Offline entries are skipped: they are often cloud addresses that have since
    been handed to someone else.
    """
    try:
        kayitlar = json.loads(metin)
    except ValueError:
        return {}
    sonuc = {}
    for kayit in kayitlar if isinstance(kayitlar, list) else []:
        if not isinstance(kayit, dict) or kayit.get("status") != "online":
            continue
        try:
            ip = ipaddress.ip_address(kayit["ip_address"]).compressed
        except (KeyError, ValueError, TypeError):
            continue
        sonuc[ip] = str(kayit.get("malware") or "botnet C2")
    return sonuc


class TehditListeleri:
    """Downloads, caches and looks up the blocklists."""

    def __init__(self, klasor: str) -> None:
        self.klasor = klasor
        self._kilit = threading.Lock()
        self._aglar: list[tuple[ipaddress.IPv4Network | ipaddress.IPv6Network, str]] = []
        self._feodo: dict[str, str] = {}

    def _yol(self, dosya: str) -> str:
        return os.path.join(self.klasor, dosya)

    def _eski_mi(self, dosya: str) -> bool:
        try:
            return time.time() - os.path.getmtime(self._yol(dosya)) > YENILEME_SN
        except OSError:
            return True

    def guncelle(self) -> None:
        """Download stale lists, keeping the previous copy when a download fails, then reload."""
        os.makedirs(self.klasor, exist_ok=True)
        for dosya, url in KAYNAKLAR.items():
            if not self._eski_mi(dosya):
                continue
            try:
                yanit = requests.get(url, timeout=INDIRME_ZAMAN_ASIMI, headers={"User-Agent": KULLANICI_AJANI})
                yanit.raise_for_status()
                gecici = self._yol(dosya) + ".tmp"
                with open(gecici, "wb") as f:
                    f.write(yanit.content)
                os.replace(gecici, self._yol(dosya))
            except (requests.RequestException, OSError) as exc:
                print(f"[!] Tehdit listesi indirilemedi ({dosya}): {exc}")
        self.yukle()

    def yukle(self) -> None:
        """(Re)load whatever list files are on disk."""
        aglar = []
        for dosya in (SPAMHAUS_V4, SPAMHAUS_V6):
            try:
                with open(self._yol(dosya), encoding="utf-8") as f:
                    aglar += spamhaus_ayristir(f.read())
            except OSError:
                continue
        feodo = {}
        try:
            with open(self._yol(FEODO), encoding="utf-8") as f:
                feodo = feodo_ayristir(f.read())
        except OSError:
            pass
        with self._kilit:
            self._aglar, self._feodo = aglar, feodo
        print(f"[+] Tehdit listeleri: Spamhaus DROP {len(aglar)} ag, Feodo Tracker {len(feodo)} C2 sunucusu.")

    def kontrol_et(self, ip: str) -> list[Eslesme]:
        """Every blocklist entry that covers ``ip``; empty for unknown, private or invalid addresses."""
        try:
            adres = ipaddress.ip_address(ip)
        except ValueError:
            return []
        with self._kilit:
            aglar, feodo = self._aglar, self._feodo
        eslesmeler = [
            Eslesme("Spamhaus DROP", sbl) for ag, sbl in aglar if ag.version == adres.version and adres in ag
        ]
        if adres.compressed in feodo:
            eslesmeler.append(Eslesme("Feodo Tracker", feodo[adres.compressed]))
        return eslesmeler
