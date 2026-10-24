"""Tests for the signature engine's UDP flood rule (no packets are captured)."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from threat_rules import ThreatSignatureEngine  # noqa: E402

YOUTUBE = "142.250.184.14"
SALDIRGAN = "203.0.113.66"  # RFC 5737 test address


def test_quic_video_yanitlari_udp_flood_sayilmaz():
    motor = ThreatSignatureEngine()
    # We opened a QUIC (UDP 443) connection to YouTube...
    motor.giden_udp_kaydet(YOUTUBE, 443)
    # ...so 400 packets coming back from YouTube:443 are replies, not a flood.
    for _ in range(400):
        motor.kayit_ekle(YOUTUBE, 51234, "UDP", 0, sport=443)

    assert motor.analiz_et(YOUTUBE, {}) is None


def test_istenmeyen_udp_flood_hala_yakalanir():
    motor = ThreatSignatureEngine()
    # Nobody asked this host for anything: unsolicited packets to many ports.
    for i in range(400):
        motor.kayit_ekle(SALDIRGAN, 1000 + i % 50, "UDP", 0, sport=53)

    alarm = motor.analiz_et(SALDIRGAN, {})
    assert alarm is not None
    assert alarm.attack_type == "UDP Flood / DDoS"


def test_baska_porttan_gelen_paket_yanit_sayilmaz():
    motor = ThreatSignatureEngine()
    # We talked to YouTube on 443; packets from another port on the same IP are not replies.
    motor.giden_udp_kaydet(YOUTUBE, 443)
    for _ in range(400):
        motor.kayit_ekle(YOUTUBE, 51234, "UDP", 0, sport=9999)

    assert motor.analiz_et(YOUTUBE, {}) is not None


def test_yanitlar_yavas_port_taramasi_sayilmaz():
    motor = ThreatSignatureEngine()
    # A DNS server answering 40 queries lands on 40 different ephemeral ports of ours.
    motor.giden_udp_kaydet("1.1.1.1", 53)
    for i in range(40):
        motor.kayit_ekle("1.1.1.1", 50000 + i, "UDP", 0, sport=53)

    assert motor.analiz_et("1.1.1.1", {}) is None
