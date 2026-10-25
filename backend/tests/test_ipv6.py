"""IPv6 support: capture, own-address detection and firewall rules (no real network)."""

import socket
import sys
from collections import namedtuple
from pathlib import Path
from unittest.mock import patch

import pytest
from scapy.all import ICMPv6EchoRequest, ICMPv6ND_NS, IPv6, TCP, UDP, Ether

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import edutrace_ultimate as et  # noqa: E402
import firewall  # noqa: E402
from threat_rules import ThreatSignatureEngine  # noqa: E402

BIZ = "2001:db8::12"
SALDIRGAN = "2001:db8::66"
YOUTUBE = "2a02:e0:312d::c"


@pytest.fixture
def motor(monkeypatch):
    yeni = ThreatSignatureEngine()
    monkeypatch.setattr(et, "imza_motoru", yeni)
    monkeypatch.setattr(et, "YEREL_ADRESLER", {"127.0.0.1", "::1", BIZ})
    return yeni


def _yakala(monkeypatch, paketler):
    monkeypatch.setattr(et, "sniff", lambda **_k: paketler)
    return et.ag_ronto_cek(3)


def test_ipv6_port_taramasi_artik_gorunur(monkeypatch, motor):
    paketler = [Ether() / IPv6(src=SALDIRGAN, dst=BIZ) / TCP(sport=40000 + p, dport=p, flags="S") for p in range(1, 31)]
    stats = _yakala(monkeypatch, paketler)

    assert stats[SALDIRGAN]["p"] == 30
    alarm = motor.analiz_et(SALDIRGAN, stats[SALDIRGAN])
    assert alarm is not None and "Yavas" in alarm.attack_type


def test_ipv6_quic_video_yanitlari_alarm_uretmez(monkeypatch, motor):
    giden = [Ether() / IPv6(src=BIZ, dst=YOUTUBE) / UDP(sport=51234, dport=443)]
    gelen = [Ether() / IPv6(src=YOUTUBE, dst=BIZ) / UDP(sport=443, dport=51234) for _ in range(400)]
    stats = _yakala(monkeypatch, giden + gelen)

    assert stats[YOUTUBE]["pt"] == set()  # our ephemeral port is not a scan target
    assert motor.analiz_et(YOUTUBE, stats[YOUTUBE]) is None


def test_ipv6_komsu_kesfi_ping_sayilmaz_ama_echo_sayilir(monkeypatch, motor):
    ndp = [Ether() / IPv6(src="fe80::1", dst="ff02::1:ff00:12") / ICMPv6ND_NS(tgt=BIZ) for _ in range(5)]
    ping = [Ether() / IPv6(src=SALDIRGAN, dst=BIZ) / ICMPv6EchoRequest() for _ in range(5)]
    stats = _yakala(monkeypatch, ndp + ping)

    assert stats["fe80::1"]["icmp_p"] == 0
    assert stats[SALDIRGAN]["icmp_p"] == 5


def test_kendi_ipv6_baglantimiz_giden_akis_olarak_kaydedilir(monkeypatch, motor):
    # 40 outbound connections from our IPv6 address: recorded as our flows, so the
    # server's SYN-ACKs count as replies; the sentinel loop skips BIZ itself
    giden = [Ether() / IPv6(src=BIZ, dst=YOUTUBE) / TCP(sport=50000 + i, dport=443, flags="S") for i in range(40)]
    _yakala(monkeypatch, giden)

    assert BIZ in et.YEREL_ADRESLER
    assert motor.tcp_yanit_mi(YOUTUBE, 443, 0x12)          # SYN-ACK from the server is a reply
    assert not motor.tcp_yanit_mi(YOUTUBE, 443, 0x02)      # a bare SYN from it would not be


Adres = namedtuple("Adres", "family address netmask broadcast ptp")


def test_yerel_adresler_tum_ipv6_adreslerini_toplar(monkeypatch):
    sahte = {
        "Wi-Fi": [
            Adres(socket.AF_INET, "192.168.1.12", None, None, None),
            Adres(socket.AF_INET6, "2001:DB8:0:0::12", None, None, None),       # stable
            Adres(socket.AF_INET6, "2001:db8::abcd:1234", None, None, None),    # temporary
            Adres(socket.AF_INET6, "fe80::1c2b:3a4d%12", None, None, None),     # link-local + zone
            Adres(-1, "aa-bb-cc-dd-ee-ff", None, None, None),                   # MAC, ignored
        ]
    }
    monkeypatch.setattr(et.psutil, "net_if_addrs", lambda: sahte)
    adresler = et.yerel_adresleri_bul()

    assert {"192.168.1.12", "2001:db8::12", "2001:db8::abcd:1234", "fe80::1c2b:3a4d", "::1"} <= adresler


@pytest.mark.parametrize("ip", ["::1", "fe80::1", "fd00::1", "fc00::5", "ff02::1", "::", "2001:db8::66; calc"])
def test_firewall_ozel_ipv6_adreslerini_engellemez(ip):
    with patch("firewall._netsh") as netsh:
        sonuc = firewall.ip_engelle(ip)
    assert not sonuc.ok
    netsh.assert_not_called()


def test_firewall_genel_ipv6_adresini_engeller():
    ok = __import__("subprocess").CompletedProcess(args=[], returncode=0, stdout="Ok.", stderr="")
    with patch("firewall.sys.platform", "win32"), patch("firewall._netsh", return_value=ok) as netsh:
        sonuc = firewall.ip_engelle("2606:4700:4700::1111")
    assert sonuc.ok
    assert any("remoteip=2606:4700:4700::1111" in arg for arg in netsh.call_args_list[0].args[0])
