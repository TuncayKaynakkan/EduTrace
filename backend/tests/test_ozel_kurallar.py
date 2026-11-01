"""Configurable thresholds and custom port rules in the signature engine."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from threat_rules import VARSAYILAN_ESIKLER, OzelKural, ThreatSignatureEngine  # noqa: E402

IP = "198.51.100.7"
MONGO = OzelKural(ad="MongoDB taramasi", port=27017, proto="TCP", esik=10, siddet="YUKSEK")


def _gonder(motor, adet, port, proto="TCP", flags=0x18):
    for _ in range(adet):
        motor.kayit_ekle(IP, port, proto, flags)


def test_ozel_kural_esikte_alarm_verir():
    motor = ThreatSignatureEngine()
    motor.ayarla(kurallar=[MONGO])
    _gonder(motor, 9, 27017)
    assert motor.analiz_et(IP, {}) is None
    _gonder(motor, 1, 27017)
    alarm = motor.analiz_et(IP, {})
    assert alarm.attack_type == "Ozel Kural: MongoDB taramasi" and alarm.severity == "YUKSEK"


def test_ozel_kural_protokol_ve_yanitlari_ayirt_eder():
    motor = ThreatSignatureEngine()
    motor.ayarla(kurallar=[MONGO])
    _gonder(motor, 20, 27017, proto="UDP")
    assert motor.analiz_et(IP, {}) is None
    # Replies to a connection this host opened are not attack traffic
    motor.giden_tcp_kaydet(IP, 443)
    for _ in range(20):
        motor.kayit_ekle(IP, 27017, "TCP", 0x10, sport=443)
    assert motor.analiz_et(IP, {}) is None


def test_esik_dusurulunce_daha_erken_alarm():
    motor = ThreatSignatureEngine()
    _gonder(motor, 50, 0, proto="ICMP", flags=0)
    assert motor.analiz_et(IP, {}) is None
    motor.ayarla(esikler={"icmp": 40})
    assert "ICMP" in motor.analiz_et(IP, {}).attack_type


def test_ayarla_bos_cagrilinca_varsayilana_doner():
    motor = ThreatSignatureEngine()
    motor.ayarla({"syn": 5}, [MONGO])
    motor.ayarla()
    assert motor.esikler == VARSAYILAN_ESIKLER and motor.ozel_kurallar == []
