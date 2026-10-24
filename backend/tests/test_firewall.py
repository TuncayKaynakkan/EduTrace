"""Unit tests for the firewall module (netsh is mocked; nothing touches the real firewall)."""

import subprocess
import sys
from pathlib import Path
from unittest.mock import patch

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import firewall  # noqa: E402


def _ok(*_a, **_k):
    return subprocess.CompletedProcess(args=[], returncode=0, stdout="Ok.", stderr="")


def _fail(*_a, **_k):
    return subprocess.CompletedProcess(args=[], returncode=1, stdout="Access denied", stderr="")


@pytest.mark.parametrize(
    "ip",
    ["127.0.0.1", "192.168.1.5", "10.0.0.2", "169.254.1.1", "224.0.0.1", "0.0.0.0", "not-an-ip", "1.2.3.4; calc"],
)
def test_refuses_non_public_or_invalid(ip):
    with patch("firewall._netsh") as netsh:
        result = firewall.ip_engelle(ip)
    assert not result.ok
    netsh.assert_not_called()


def test_blocks_public_ip_in_and_out():
    with patch("firewall.sys.platform", "win32"), patch("firewall._netsh", side_effect=_ok) as netsh:
        result = firewall.ip_engelle("8.8.4.4")
    assert result.ok
    assert netsh.call_count == 2
    first_args = netsh.call_args_list[0].args[0]
    assert "action=block" in first_args and "remoteip=8.8.4.4" in first_args


def test_reports_failure_without_admin():
    with patch("firewall.sys.platform", "win32"), patch("firewall._netsh", side_effect=_fail):
        result = firewall.ip_engelle("8.8.4.4")
    assert not result.ok
    assert "yonetici" in result.message.lower()


def test_not_supported_off_windows():
    with patch("firewall.sys.platform", "linux"):
        result = firewall.ip_engelle("8.8.4.4")
    assert not result.ok


def test_unblock_deletes_both_rules():
    with patch("firewall.sys.platform", "win32"), patch("firewall._netsh", side_effect=_ok) as netsh:
        result = firewall.ip_engeli_kaldir("8.8.4.4")
    assert result.ok
    assert netsh.call_count == 2


def test_unblock_rejects_invalid_ip():
    assert not firewall.ip_engeli_kaldir("abc").ok
