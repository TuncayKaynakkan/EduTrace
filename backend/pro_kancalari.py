"""Extension points the engine offers to the optional EduTrace Pro add-on.

The free engine answers every question with the defaults below. When the
private ``edutrace_pro`` package is installed, its ``kur(motor)`` returns a
subclass that overrides these methods and registers the Pro socket events.
"""

from __future__ import annotations

from typing import Any

UCRETSIZ_GECMIS_GUN = 1


class ProKancalari:
    """Free-edition behaviour; every method is a hook Pro may override."""

    def __init__(self, socketio: Any) -> None:
        self.socketio = socketio

    @property
    def aktif(self) -> bool:
        """Whether a verified Pro license is active."""
        return False

    def gecmis_gun_siniri(self) -> int:
        """How many days of alert history the panel may see."""
        return UCRETSIZ_GECMIS_GUN

    def beyaz_listede(self, ip: str) -> bool:
        """User whitelist: alerts for these IPs are ignored."""
        return False

    def oto_firewall(self) -> bool:
        """Block attacking IPs in Windows Firewall without asking."""
        return False

    def oto_sonlandir(self) -> bool:
        """Terminate the process behind an attack without asking."""
        return False

    def alarm_sonrasi(self, ip: str, saldiri_turu: str, islem: str, aciklama: str) -> None:
        """Called after an alert was acted on (Pro sends notifications here)."""

    def lisans_al(self, anahtar: str, instance_id: str) -> None:
        """The panel forwarded a license key; the free engine cannot use it."""
        self.socketio.emit("pro_durumu", {
            "is_pro": False,
            "mesaj": "Bu motor surumunde EduTrace Pro modulu yok.",
        })

    def baslat(self) -> None:
        """Start background work (license re-checks) once the engine runs."""
