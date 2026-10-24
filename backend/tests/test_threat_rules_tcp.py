"""Tests for TCP reply tracking in the signature engine (no packets are captured)."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from threat_rules import ThreatSignatureEngine  # noqa: E402

CDN = "104.16.132.229"
SALDIRGAN = "203.0.113.77"  # RFC 5737 test address

SYN, ACK, FIN, PSH, URG = 0x02, 0x10, 0x01, 0x08, 0x20


def _cdn_sayfa_yuklemesi(motor, baglanti=30):
    """A browser opens many connections to a CDN; each reply hits a different ephemeral port."""
    for i in range(baglanti):
        motor.kayit_ekle(CDN, 50000 + i, "TCP", SYN | ACK, sport=443)
        motor.kayit_ekle(CDN, 50000 + i, "TCP", PSH | ACK, sport=443)


def test_cdn_yanitlari_yavas_port_taramasi_sayilmaz():
    motor = ThreatSignatureEngine()
    motor.giden_tcp_kaydet(CDN, 443)
    _cdn_sayfa_yuklemesi(motor)

    assert motor.analiz_et(CDN, {}) is None


def test_baglanti_kaydi_yokken_ayni_trafik_hala_supheli():
    # Without the outbound record the engine cannot know these are replies
    motor = ThreatSignatureEngine()
    _cdn_sayfa_yuklemesi(motor)

    alarm = motor.analiz_et(CDN, {})
    assert alarm is not None
    assert "Yavas" in alarm.attack_type


def test_gercek_yavas_port_taramasi_hala_yakalanir():
    motor = ThreatSignatureEngine()
    for port in range(1, 31):
        motor.kayit_ekle(SALDIRGAN, port, "TCP", SYN, sport=40000 + port)

    alarm = motor.analiz_et(SALDIRGAN, {})
    assert alarm is not None
    assert "Yavas" in alarm.attack_type


def test_bilinen_kaynaktan_gelen_gizli_tarama_yanit_sayilmaz():
    # ACK-less probes (here XMAS) are never treated as replies, even from a known ip:port
    motor = ThreatSignatureEngine()
    motor.giden_tcp_kaydet(CDN, 443)
    for port in range(20, 26):
        motor.kayit_ekle(CDN, port, "TCP", FIN | PSH | URG, sport=443)

    alarm = motor.analiz_et(CDN, {})
    assert alarm is not None
    assert "Stealth" in alarm.attack_type


def test_udp_kaydi_tcp_yanitini_aklamaz():
    # Flows are tracked per protocol: a UDP flow to :443 says nothing about TCP from :443
    motor = ThreatSignatureEngine()
    motor.giden_udp_kaydet(CDN, 443)
    _cdn_sayfa_yuklemesi(motor)

    assert motor.analiz_et(CDN, {}) is not None
