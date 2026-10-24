"""EduTrace Threat Detection Engine (Signature + Anomaly + Heuristic rules).

Detects specific attack types:
- SYN Flood / DoS
- UDP Flood (DDoS amplification / DNS flood)
- ICMP / Ping Flood
- Aggressive & Stealth Port Scans (XMAS, FIN, NULL scans)
- High-Risk Service Brute Force Targets (RDP 3389, SMB 445, SSH 22, Telnet 23)
"""

from __future__ import annotations

import time
from collections import defaultdict, deque
from dataclasses import dataclass, field
from typing import Any


@dataclass
class ThreatAlert:
    """Represents a diagnosed network threat alert."""
    ip: str
    attack_type: str
    severity: str  # DUSUK, ORTA, YUKSEK, KRITIK
    description: str
    packet_count: int
    target_ports: list[int] = field(default_factory=list)


# Ports frequently targeted by exploits, ransomware & brute force
KRITIK_SERVIS_PORTLARI = {
    445: "SMB / WannaCry Ransomware Hedefi",
    3389: "RDP (Uzak Masaustu) Brute Force",
    22: "SSH Brute Force",
    23: "Telnet Brute Force / Mirai Botnet",
    135: "RPC DCOM Exploit",
    139: "NetBIOS Hedefi",
    1433: "MSSQL Veritabani Taramasi",
    3306: "MySQL Taramasi",
    53: "DNS Amplification / Flood",
}


class ThreatSignatureEngine:
    """Sliding-window threat analyzer for TCP, UDP and ICMP traffic."""

    def __init__(self, window_seconds: int = 60) -> None:
        self.window_seconds = window_seconds
        # ip -> deque of (timestamp, dport, proto, flags)
        self._history: dict[str, deque[tuple[float, int, str, int]]] = defaultdict(deque)
        # (remote ip, remote port) -> last time this host sent UDP to it.
        # Lets us tell replies (QUIC video, DNS answers) apart from unsolicited floods.
        self._giden_udp: dict[tuple[str, int], float] = {}

    def giden_udp_kaydet(self, hedef_ip: str, hedef_port: int) -> None:
        """Remember an outbound UDP flow so its replies are not counted as a flood."""
        now = time.time()
        self._giden_udp[(hedef_ip, hedef_port)] = now
        if len(self._giden_udp) > 5000:
            cutoff = now - self.window_seconds
            self._giden_udp = {k: t for k, t in self._giden_udp.items() if t >= cutoff}

    def udp_yanit_mi(self, kaynak_ip: str, kaynak_port: int) -> bool:
        """Whether inbound UDP from this ip:port answers a flow this host started."""
        t = self._giden_udp.get((kaynak_ip, kaynak_port))
        return t is not None and time.time() - t <= self.window_seconds

    def kayit_ekle(self, ip: str, dport: int, proto: str, flags: int, sport: int = 0) -> None:
        now = time.time()
        if proto == "UDP" and self.udp_yanit_mi(ip, sport):
            proto = "UDP_YANIT"
        q = self._history[ip]
        q.append((now, dport, proto, flags))
        self._temizle(ip, now)

    def _temizle(self, ip: str, now: float) -> None:
        q = self._history[ip]
        cutoff = now - self.window_seconds
        while q and q[0][0] < cutoff:
            q.popleft()
        if not q and ip in self._history:
            del self._history[ip]

    def sifirla(self, ip: str) -> None:
        """Reset history for an IP once an alert has been generated to prevent re-triggering."""
        if ip in self._history:
            self._history[ip].clear()
            del self._history[ip]

    def analiz_et(self, ip: str, anlik_veri: dict[str, Any]) -> ThreatAlert | None:
        """Inspects aggregated packet metrics & sliding-window for signatures."""
        now = time.time()
        self._temizle(ip, now)
        # Replies to flows this host started are normal traffic, not attack evidence
        q = [item for item in self._history.get(ip, deque()) if item[2] != "UDP_YANIT"]

        total_window_packets = len(q)
        window_ports = {item[1] for item in q if item[1] > 0}
        window_protos = {item[2] for item in q}

        # 1. ICMP / Ping Flood Detection
        icmp_count = sum(1 for item in q if item[2] == "ICMP")
        if icmp_count > 60:
            return ThreatAlert(
                ip=ip,
                attack_type="ICMP Ping Flood (DoS)",
                severity="YUKSEK",
                description=f"{ip} adresinden asiri yogun ICMP Ping trafigi tespit edildi ({icmp_count} paket/dk).",
                packet_count=icmp_count,
            )

        # 2. UDP Flood / DNS Amplification
        udp_count = sum(1 for item in q if item[2] == "UDP")
        if udp_count > 300:
            return ThreatAlert(
                ip=ip,
                attack_type="UDP Flood / DDoS",
                severity="KRITIK",
                description=f"{ip} adresinden hedef sisteme UDP Flood saldirisi algilandi ({udp_count} paket/dk).",
                packet_count=udp_count,
                target_ports=list(window_ports)[:5],
            )

        # 3. Stealth Scans (NULL, FIN, XMAS Nmap Flags)
        # FIN=0x01, SYN=0x02, RST=0x04, PSH=0x08, ACK=0x10, URG=0x20
        # NULL: flags == 0
        # XMAS: flags == FIN|PSH|URG (0x29)
        null_scans = sum(1 for item in q if item[2] == "TCP" and item[3] == 0)
        xmas_scans = sum(1 for item in q if item[2] == "TCP" and item[3] == 0x29)
        fin_scans = sum(1 for item in q if item[2] == "TCP" and item[3] == 0x01)

        if (null_scans + xmas_scans + fin_scans) >= 5:
            return ThreatAlert(
                ip=ip,
                attack_type="Gizli Ag Taramasi (Nmap Stealth Scan)",
                severity="YUKSEK",
                description=f"{ip} adresinden guvenlik duvarlarini atlatmaya yonelik gizli TCP bayrak kombinasyonlari (NULL/XMAS/FIN) yakalandi.",
                packet_count=null_scans + xmas_scans + fin_scans,
                target_ports=list(window_ports)[:5],
            )

        # 4. Critical Service Brute Force / Targeted Scan (RDP, SMB, SSH)
        for target_port, service_name in KRITIK_SERVIS_PORTLARI.items():
            targeted = sum(1 for item in q if item[1] == target_port)
            if targeted >= 25:
                return ThreatAlert(
                    ip=ip,
                    attack_type=f"Hedefli Saldiri: {service_name}",
                    severity="KRITIK",
                    description=f"{ip} adresi dogrudan {target_port} ({service_name}) servisine yogun sizma/brute-force girisiminde bulunuyor.",
                    packet_count=targeted,
                    target_ports=[target_port],
                )

        # 5. SYN Flood / DoS
        syn_only = sum(1 for item in q if item[2] == "TCP" and item[3] == 0x02)
        if syn_only >= 150:
            return ThreatAlert(
                ip=ip,
                attack_type="TCP SYN Flood (DoS)",
                severity="KRITIK",
                description=f"{ip} adresinden sunucu kaynaklarini tuketmeye yonelik SYN Flood saldirisi algilandi.",
                packet_count=syn_only,
            )

        # 6. Sliding-Window Slow Port Scan (Low & Slow Scan)
        if len(window_ports) >= 20 and total_window_packets >= 30:
            return ThreatAlert(
                ip=ip,
                attack_type="Yavas Ag Taramasi (Low & Slow Port Scan)",
                severity="ORTA",
                description=f"{ip} adresi zamana yayarak {len(window_ports)} farkli portu tarayarak kesif yapiyor.",
                packet_count=total_window_packets,
                target_ports=list(window_ports)[:8],
            )

        return None
