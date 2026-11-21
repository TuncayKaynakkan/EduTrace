"""Windows Firewall IP blocking for EduTrace.

Uses ``netsh advfirewall`` (requires an elevated/administrator process).
Only public IPv4/IPv6 addresses can be blocked; private, loopback, link-local
and multicast addresses are always refused so the user's LAN is never cut off.
"""

from __future__ import annotations

import ipaddress
import re
import subprocess
import sys
from dataclasses import dataclass

RULE_PREFIX = "EduTrace Block"
_TIMEOUT = 10
# Listing walks every rule on the machine, which takes a few seconds
_LISTE_TIMEOUT = 30
# Matches the rule name we create, wherever it appears in netsh's output. Only the
# value is matched, never a label, so it works on any Windows display language.
_KURAL_ADI = re.compile(rf"{re.escape(RULE_PREFIX)} (\S+) \((?:in|out)\)")


@dataclass(frozen=True)
class FirewallResult:
    """Outcome of a firewall operation."""

    ok: bool
    message: str


def _gecerli_acik_ip(ip: str) -> ipaddress.IPv4Address | ipaddress.IPv6Address | None:
    """Return the parsed IP if it is a blockable public address, else ``None``."""
    try:
        obj = ipaddress.ip_address(ip)
    except ValueError:
        return None
    if (
        obj.is_private
        or obj.is_loopback
        or obj.is_link_local
        or obj.is_multicast
        or obj.is_unspecified
        or obj.is_reserved
    ):
        return None
    return obj


def _netsh(args: list[str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["netsh", "advfirewall", "firewall", *args],
        capture_output=True,
        text=True,
        timeout=_TIMEOUT,
        check=False,
        shell=False,
    )


def desteklenir_mi() -> bool:
    """Whether firewall blocking is available on this platform."""
    return sys.platform == "win32"


def ip_engelle(ip: str) -> FirewallResult:
    """Block inbound and outbound traffic for a public IP address."""
    obj = _gecerli_acik_ip(ip)
    if obj is None:
        return FirewallResult(False, f"{ip} engellenemez (gecersiz veya yerel/ozel adres).")
    if not desteklenir_mi():
        return FirewallResult(False, "Guvenlik duvari engelleme yalnizca Windows'ta desteklenir.")

    adres = str(obj)
    for yon in ("in", "out"):
        try:
            sonuc = _netsh(
                [
                    "add", "rule",
                    f"name={RULE_PREFIX} {adres} ({yon})",
                    f"dir={yon}",
                    "action=block",
                    f"remoteip={adres}",
                ]
            )
        except (OSError, subprocess.TimeoutExpired) as exc:
            return FirewallResult(False, f"Guvenlik duvari komutu calistirilamadi: {exc}")
        if sonuc.returncode != 0:
            return FirewallResult(
                False,
                "Guvenlik duvari kurali eklenemedi (yonetici olarak calistirin): "
                f"{(sonuc.stdout or sonuc.stderr).strip()}",
            )
    return FirewallResult(True, f"{adres} Windows Guvenlik Duvari'nda engellendi.")


def engel_kurallari() -> list[str]:
    """IPs that currently have an EduTrace block rule in Windows Firewall.

    Read from the firewall itself, not from our records: rules outlive the engine
    and may have been created by an older version that kept no record.
    """
    if not desteklenir_mi():
        return []
    try:
        sonuc = subprocess.run(
            ["netsh", "advfirewall", "firewall", "show", "rule", "name=all"],
            capture_output=True,
            text=True,
            errors="replace",
            timeout=_LISTE_TIMEOUT,
            check=False,
            shell=False,
        )
    except (OSError, subprocess.TimeoutExpired):
        return []
    adresler: set[str] = set()
    for aday in _KURAL_ADI.findall(sonuc.stdout or ""):
        try:
            adresler.add(str(ipaddress.ip_address(aday)))
        except ValueError:
            continue
    return sorted(adresler)


def ip_engeli_kaldir(ip: str) -> FirewallResult:
    """Remove the EduTrace block rules for an IP address."""
    try:
        adres = str(ipaddress.ip_address(ip))
    except ValueError:
        return FirewallResult(False, f"Gecersiz IP: {ip}")
    if not desteklenir_mi():
        return FirewallResult(False, "Yalnizca Windows'ta desteklenir.")

    for yon in ("in", "out"):
        try:
            _netsh(["delete", "rule", f"name={RULE_PREFIX} {adres} ({yon})"])
        except (OSError, subprocess.TimeoutExpired) as exc:
            return FirewallResult(False, f"Kural silinemedi: {exc}")
    return FirewallResult(True, f"{adres} engeli kaldirildi.")
