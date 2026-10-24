"""
EduTrace XDR Backend — Autonomous network threat detection and education engine.

Captures TCP traffic via Scapy, detects anomalies with IsolationForest,
validates threats via VirusTotal, generates educational reports via Gemini AI,
and streams events to the Flutter dashboard over Flask-SocketIO.
"""

from __future__ import annotations

import os
import socket
import sys
import threading
import time
import warnings
from collections import defaultdict, deque
from concurrent.futures import ThreadPoolExecutor, TimeoutError as FuturesTimeoutError
from typing import Any

import ipaddress
import pandas as pd
import psutil
import requests
from dotenv import load_dotenv
from flask import Flask
from flask_socketio import SocketIO
from google import genai
from scapy.all import IP, TCP, UDP, ICMP, sniff
from sklearn.ensemble import IsolationForest

import firewall
from threat_rules import ThreatSignatureEngine, ThreatAlert

imza_motoru = ThreatSignatureEngine(window_seconds=60)

warnings.filterwarnings("ignore")


def _env_yukle() -> None:
    """Load .env and settings.json from %APPDATA%\\EduTrace or %PROGRAMDATA%\\EduTrace."""
    adaylar = []
    if getattr(sys, "frozen", False):
        adaylar.append(os.path.join(os.path.dirname(sys.executable), ".env"))
    programdata = os.getenv("PROGRAMDATA")
    if programdata:
        adaylar.append(os.path.join(programdata, "EduTrace", ".env"))
    appdata = os.getenv("APPDATA") or os.getenv("LOCALAPPDATA")
    if appdata:
        adaylar.append(os.path.join(appdata, "EduTrace", ".env"))
    for yol in adaylar:
        if os.path.isfile(yol):
            load_dotenv(yol)
            break
    else:
        load_dotenv()

    # Also check %APPDATA%\EduTrace\settings.json for user-configured gemini_api_key
    if appdata:
        settings_file = os.path.join(appdata, "EduTrace", "settings.json")
        if os.path.isfile(settings_file):
            try:
                import json
                with open(settings_file, "r", encoding="utf-8") as sf:
                    sdata = json.load(sf)
                    gkey = sdata.get("gemini_api_key")
                    if gkey and not os.getenv("GEMINI_API_KEY"):
                        os.environ["GEMINI_API_KEY"] = str(gkey).strip()
            except Exception:
                pass


_env_yukle()

# noconsole/GUI modunda calisirken print cagrilarinin cokmesini onlemek icin log dosyasina yonlendir
if sys.stdout is None or sys.stderr is None:
    try:
        log_dir = os.path.join(os.getenv("PROGRAMDATA", "C:\\ProgramData"), "EduTrace")
        os.makedirs(log_dir, exist_ok=True)
        log_file = open(os.path.join(log_dir, "engine.log"), "a", encoding="utf-8", buffering=1)
        sys.stdout = log_file
        sys.stderr = log_file
    except Exception:
        sys.stdout = open(os.devnull, "w", encoding="utf-8")
        sys.stderr = open(os.devnull, "w", encoding="utf-8")

SNIFF_TIMEOUT = 3
PROCESS_SCAN_INTERVAL = 8
ML_RETRAIN_INTERVAL = 15
MIN_TRAINING_SAMPLES = 30
TRAFFIC_EMIT_COOLDOWN = 2.0
MAX_TRAINING_SAMPLES = 1000
GEMINI_MODEL = os.getenv("GEMINI_MODEL", "gemini-2.5-flash")
GEMINI_TIMEOUT = 25
GEMINI_MAX_RETRIES = 3
# Varsayilan olarak yalnizca yerel makineye acik; ag uzerinden erisim icin SERVER_HOST=0.0.0.0
SERVER_HOST = os.getenv("SERVER_HOST", "127.0.0.1")
SERVER_PORT = int(os.getenv("SERVER_PORT", "5000"))
# Zararli bulunan sureci otomatik sonlandir (varsayilan: kapali, guvenlik icin)
# Public IP'yi Windows Guvenlik Duvari'nda engelle (yonetici yetkisi gerekir)
FIREWALL_BLOCK = os.getenv("FIREWALL_BLOCK", "true").lower() == "true"
AUTO_TERMINATE = os.getenv("AUTO_TERMINATE", "false").lower() == "true"
KORUNAN_SURECLER = {
    "system", "system idle process", "csrss.exe", "wininit.exe", "winlogon.exe",
    "services.exe", "lsass.exe", "svchost.exe", "explorer.exe", "python.exe",
    "pythonw.exe", "flutter_application_1.exe", "edutrace.exe",
}

app = Flask(__name__)
_cors = os.getenv("CORS_ORIGINS")
socketio = SocketIO(
        app,
        cors_allowed_origins=_cors if _cors else None,
        async_mode="threading",
        always_connect=True,
)

_background_executor = ThreadPoolExecutor(max_workers=4, thread_name_prefix="edutrace-api")
_state_lock = threading.Lock()
_last_traffic_emit: dict[str, float] = {}
_last_threat_time: dict[str, float] = {}
_last_npcap_warn: float = 0.0
THREAT_COOLDOWN = 45.0
_isleniyor: set[str] = set()


def aktif_yerel_ip_bul() -> str:
    """Detect the active local IPv4 address used for outbound traffic."""
    try:
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
          sock.connect(("8.8.8.8", 80))
          return sock.getsockname()[0]
    except OSError:
        return "127.0.0.1"


AKTIF_IP = aktif_yerel_ip_bul()
BEYAZ_LISTE = ["127.0.0.1", "192.168.1.1", AKTIF_IP, "255.255.255.255"]
ENGELLENEN_IPLER: set[str] = set()
CURRENT_LANG = "tr"

yapay_zeka = IsolationForest(contamination="auto", random_state=42)
dinamik_egitim_havuzu: deque[dict[str, int]] = deque(maxlen=MAX_TRAINING_SAMPLES)


class EgiticiAsistanMotoru:
    """Generates educational threat reports using the Gemini API in Turkish or English."""

    def __init__(self) -> None:
        self.api_key = os.getenv("GEMINI_API_KEY", "")
        self.model_adi = GEMINI_MODEL
        self.client = genai.Client(api_key=self.api_key) if self.api_key else None
        if self.client:
          print(f"[+] AI Egitmen Aktif: {self.model_adi}")
        else:
          print("[!] GEMINI_API_KEY tanimli degil. AI raporlari dahili sablondan uretilecek.")

    def guncelle_api_key(self, yeni_key: str) -> bool:
        """Update Gemini API key at runtime."""
        self.api_key = yeni_key.strip()
        os.environ["GEMINI_API_KEY"] = self.api_key
        try:
            self.client = genai.Client(api_key=self.api_key) if self.api_key else None
            if self.client:
                print(f"[+] AI Egitmen API Anahtari Basariyla Guncellendi ({self.model_adi})")
                return True
        except Exception as exc:
            print(f"[!] Gemini Client baslatilamadi: {exc}")
            self.client = None
        return False

    def tavsiye_uret(
        self, uygulama_adi: str, hedef_ip: str, vt_skor: Any, saldiri_turu: str = "Supheli Ag Taramasi"
    ) -> str:
        """Create an educational report for a blocked threat in the active language."""
        if not self.client:
          return self._varsayilan_rapor(hedef_ip, saldiri_turu)

        if CURRENT_LANG == "en":
          prompt = f"""
You are EduTrace, an educational XDR assistant designed for university students and cybersecurity analysts.
Our system just autonomously intercepted and neutralized the following security threat:

Detected Threat / Attack Type: {saldiri_turu}
Associated Application / Process: {uygulama_adi}
Offending IP Address: {hedef_ip}
VirusTotal Threat Score: {vt_skor}

Please formulate an educational threat response report adhering strictly to this clear, technical format:
1. [Attack Analysis]: What exactly is {saldiri_turu} and what is the threat actor trying to accomplish?
2. [Potential Impact]: If this attack had not been blocked, what vulnerability or system compromise could have occurred?
3. [Prevention Strategy]: What specific network and endpoint hardening measures should be deployed to prevent future occurrences?
"""
        else:
          prompt = f"""
Sen EduTrace adinda, universite ogrencileri ve siber guvenlik analistleri icin tasarlanmis egitici bir XDR asistanisin.
Sistemimiz az once su tehdidi otonom olarak engelledi:

Tespit Edilen Saldiri Turu: {saldiri_turu}
Iliskili Uygulama: {uygulama_adi}
Tehlikeli IP Adresi: {hedef_ip}
VirusTotal Skoru: {vt_skor}

Lutfen kullaniciya siber guvenlik egitimi vermek icin su net ve teknik formata uyarak yanit ver:
1. [Saldirinin Analizi]: {saldiri_turu} tam olarak nedir ve saldirgan bu yontemle neyi hedefliyor?
2. [Olasi Hasar]: Eger engellenmeseydi sistemde ne gibi bir zafiyet veya hasar olusurdu?
3. [Gelecek Onlemi]: Bu tur saldirilara karsi alinmasi gereken ag ve sistem guvenligi onlemleri nelerdir?
"""
        for deneme in range(GEMINI_MAX_RETRIES):
          try:
            print(f"[*] Gemini API'ye istek gonderiliyor... (Deneme {deneme + 1}/{GEMINI_MAX_RETRIES})")
            future = _background_executor.submit(
              self.client.models.generate_content,
              model=self.model_adi,
              contents=prompt,
            )
            response = future.result(timeout=GEMINI_TIMEOUT)
            print("[+] Gemini yanit verdi!")
            return response.text

          except FuturesTimeoutError:
            print("[!] Gemini timeout!")
            break
          except Exception as exc:
            hata = str(exc)
            if "429" in hata or "RESOURCE_EXHAUSTED" in hata:
              bekleme = 30 * (deneme + 1)
              print(f"[!] Kota asildi. {bekleme} saniye bekleniyor...")
              time.sleep(bekleme)
            else:
              print(f"[!] Gemini Hatasi: {type(exc).__name__}: {exc}")
              break

        return self._varsayilan_rapor(hedef_ip, saldiri_turu)

    @staticmethod
    def _varsayilan_rapor(hedef_ip: str, saldiri_turu: str = "Supheli Ag Taramasi") -> str:
        """Return a fallback report when Gemini is unavailable."""
        if CURRENT_LANG == "en":
          return (
            f"EduTrace Autonomous Incident Report:\n\n"
            f"1. [Attack Diagnostics]: Detected '{saldiri_turu}' pattern targeting or originating from {hedef_ip}.\n"
            f"2. [Potential Impact]: Target ports and network services could be probed for unauthorized entry points.\n"
            f"3. [Prevention Strategy]: Restrict unused ports on firewall rules and enforce strong multi-factor authentication."
          )
        return (
          f"EduTrace Otomasyon Raporu:\n\n"
          f"1. [Saldiri Tehsisi]: {hedef_ip} adresinden '{saldiri_turu}' kalibi tespit edildi.\n"
          f"2. [Olasi Hasar]: Hedef portlar ve servisler taranarak sisteme yetkisiz erisim saglanabilirdi.\n"
          f"3. [Gelecek Onlemi]: Guvenlik duvarinda kullanilmayan portlari kapatin ve guclu kimlik dogrulama uygulayin."
        )



class TehditAnalizMotoru:
    """Queries VirusTotal and returns an autonomous block/allow decision."""

    def __init__(self) -> None:
        self.vt_api_key = os.getenv("VIRUSTOTAL_API_KEY", "")
        self.sorgu_gecmisi: dict[str, dict[str, Any]] = {}
        if self.vt_api_key:
          print("[+] VirusTotal istihbarat modulu aktif.")
        else:
          print("[!] VIRUSTOTAL_API_KEY tanimli degil. Dis IP analizi sinirli.")

    def analiz_et_ve_karar_ver(self, ip_adresi: str) -> dict[str, Any]:
        """Analyze an IP and decide whether to block it.

        Args:
          ip_adresi: Remote IP address to inspect.

        Returns:
          Dictionary with keys ``ip``, ``vt_skor``, and ``otonom_karar``.
        """
        try:
          ip_obj = ipaddress.ip_address(ip_adresi)
          if ip_obj.is_private:
            return {
              "ip": ip_adresi,
              "vt_skor": "YEREL AG (N/A)",
              "otonom_karar": "ENGELLE",
            }
        except ValueError:
          pass

        if ip_adresi in self.sorgu_gecmisi:
          cached = self.sorgu_gecmisi[ip_adresi].copy()
          cached["ip"] = ip_adresi
          return cached

        if not self.vt_api_key:
          return {"ip": ip_adresi, "vt_skor": 0, "otonom_karar": "IZIN_VER"}

        url = f"https://www.virustotal.com/api/v3/ip_addresses/{ip_adresi}"
        headers = {"accept": "application/json", "x-apikey": self.vt_api_key}
        try:
          response = requests.get(url, headers=headers, timeout=5)
          if response.status_code == 200:
            veri = response.json()
            zararli_sayisi = veri["data"]["attributes"]["last_analysis_stats"]["malicious"]
            otonom_karar = "ENGELLE" if zararli_sayisi > 0 else "IZIN_VER"
            sonuc = {"vt_skor": zararli_sayisi, "otonom_karar": otonom_karar}
            self.sorgu_gecmisi[ip_adresi] = sonuc
            return {"ip": ip_adresi, **sonuc}
        except requests.RequestException as exc:
          print(f"[!] VirusTotal hatasi: {exc}")

        return {"ip": ip_adresi, "vt_skor": 0, "otonom_karar": "IZIN_VER"}


egitici_motor = EgiticiAsistanMotoru()
tehdit_motoru = TehditAnalizMotoru()


@socketio.on("karar_ver")
def karar_uygula(_data: dict[str, Any]) -> None:
    """Reject manual intervention requests while autonomous mode is active."""
    print("[!] Manuel mudahale reddedildi. Sistem otonom XDR modunda calisiyor.")


@socketio.on("surec_sonlandir")
def surec_sonlandir(data: dict[str, Any]) -> None:
    """Terminates process(es) requested by the user from the dashboard."""
    pids = data.get("pids", [])
    ad = data.get("ad", "Bilinmeyen Surec")
    
    if ad.lower() in KORUNAN_SURECLER:
        socketio.emit(
            "islem_bildirimi",
            {"durum": "hata", "mesaj": f"Kritik sistem sureci ({ad}) sonlandirilamaz!"},
        )
        return

    basarili_sayi = 0
    hatalar = []

    for pid in pids:
        try:
            p = psutil.Process(int(pid))
            p.terminate()
            basarili_sayi += 1
        except (psutil.NoSuchProcess, psutil.AccessDenied) as exc:
            hatalar.append(str(exc))

    if basarili_sayi > 0:
        socketio.emit(
            "islem_bildirimi",
            {"durum": "basarili", "mesaj": f"{ad} basariyla sonlandirildi ({basarili_sayi} surec)."},
        )
    else:
        socketio.emit(
            "islem_bildirimi",
            {"durum": "hata", "mesaj": f"{ad} sonlandirilamadi: {', '.join(hatalar) if hatalar else 'Yetki yetersiz'}"},
        )


@socketio.on("ip_engelle")
def ip_manuel_engelle(data: dict[str, Any]) -> None:
    """Blocks an IP address on Windows Firewall on user request."""
    ip = data.get("ip", "")
    if not ip or ip in BEYAZ_LISTE:
        socketio.emit("islem_bildirimi", {"durum": "hata", "mesaj": f"{ip} guvenli listede veya gecersiz!"})
        return

    fw = firewall.ip_engelle(ip)
    with _state_lock:
        ENGELLENEN_IPLER.add(ip)
    socketio.emit(
        "islem_bildirimi",
        {"durum": "basarili" if fw.ok else "hata", "mesaj": fw.message},
    )


IS_PRO_USER = False


@socketio.on("lisans_durumu")
def lisans_durumu_al(data: dict[str, Any]) -> None:
    """Updates Pro status and toggles autonomous active defense."""
    global IS_PRO_USER, AUTO_TERMINATE
    IS_PRO_USER = bool(data.get("is_pro", False))
    if IS_PRO_USER:
        AUTO_TERMINATE = True
        print("[+] EduTrace PRO Aktif! Otonom Savunma (Active Defense) Devrede.")
    else:
        AUTO_TERMINATE = False
        print("[*] EduTrace Standart (Free) Modunda Calisiyor.")


@socketio.on("dil_degistir")
def dil_degistir_al(data: dict[str, Any]) -> None:
    """Updates the active language ('tr' or 'en') for AI generation and system messages."""
    global CURRENT_LANG
    yeni_dil = str(data.get("dil", "tr")).lower()
    if yeni_dil in ("tr", "en"):
        CURRENT_LANG = yeni_dil
        print(f"[+] Dil secimi guncellendi: {CURRENT_LANG.upper()}")


@socketio.on("simulasyon_baslat")
def simulasyon_baslat(data: dict[str, Any] | None = None) -> None:
    """Triggers a safe, realistic educational threat simulation showcasing XDR defense."""
    print("[*] Egitici Tehdit Simulasyonu Baslatiliyor...")

    sim_ip = "203.0.113.42"  # RFC 5737 TEST-NET-3 (Safe test IP)

    if CURRENT_LANG == "en":
        saldiri_turu = "Nmap Stealth Scan (SYN/FIN Probe)"
        aciklama = f"Security Simulation: Detected covert port probe from {sim_ip} attempting to map open services."
        if IS_PRO_USER:
            islem_durumu = f"[PRO SHIELD] Autonomous active defense isolated {sim_ip} and intercepted suspicious reconnaissance."
        else:
            islem_durumu = f"Security threat intercepted ({sim_ip}). Threat: {saldiri_turu}."
    else:
        saldiri_turu = "Gizli Ağ Taraması (Nmap Stealth Scan)"
        aciklama = f"Güvenlik Simülasyonu: {sim_ip} adresinden açık portları tespit etmeye çalışan gizli TCP bayrak kombinasyonları yakalandı."
        if IS_PRO_USER:
            islem_durumu = f"[PRO KALKAN] Otonom savunma devreye girdi; {sim_ip} adresi izole edildi ve saldırı engellendi."
        else:
            islem_durumu = f"Dış kaynaklı saldırı engellendi ({sim_ip}). Tehdit: {saldiri_turu}."

    def _calistir() -> None:
        try:
            # Emit incoming suspicious traffic for visual feedback on radar/traffic table
            socketio.emit("temiz_trafik", {"ip": sim_ip, "paket": 1420})
            time.sleep(0.6)  # Realistic simulation delay
            egitici_rapor = egitici_motor.tavsiye_uret(
                "nmap_recon.exe", sim_ip, "Simulasyon (1/72 VT Skoru)", saldiri_turu=saldiri_turu
            )
            socketio.emit(
                "islem_sonucu",
                {
                    "mesaj": islem_durumu,
                    "durum": "basarili",
                    "saldiri_turu": saldiri_turu,
                    "aciklama": aciklama,
                    "egitici_rapor": egitici_rapor,
                },
            )
            print(f"[+] Simulasyon basariyla tamamlandi: {saldiri_turu}")
        except Exception as exc:
            print(f"[!] Simulasyon sirasinda hata olustu: {exc}")
            import traceback
            traceback.print_exc()
            fallback_rapor = egitici_motor._varsayilan_rapor(sim_ip, saldiri_turu)
            socketio.emit(
                "islem_sonucu",
                {
                    "mesaj": islem_durumu,
                    "durum": "basarili",
                    "saldiri_turu": saldiri_turu,
                    "aciklama": aciklama,
                    "egitici_rapor": fallback_rapor,
                },
            )

    threading.Thread(target=_calistir, daemon=True).start()


@socketio.on("gemini_key_guncelle")
def gemini_key_guncelle_al(data: dict[str, Any]) -> None:
    """Updates the Gemini API key in memory and persists to settings."""
    yeni_key = str(data.get("api_key", "")).strip()
    basarili = egitici_motor.guncelle_api_key(yeni_key)

    appdata = os.getenv("APPDATA") or os.getenv("LOCALAPPDATA")
    if appdata:
        try:
            import json
            edutrace_dir = os.path.join(appdata, "EduTrace")
            os.makedirs(edutrace_dir, exist_ok=True)
            settings_path = os.path.join(edutrace_dir, "settings.json")
            sdata = {}
            if os.path.isfile(settings_path):
                try:
                    with open(settings_path, "r", encoding="utf-8") as f:
                        sdata = json.load(f)
                except Exception:
                    pass
            sdata["gemini_api_key"] = yeni_key
            with open(settings_path, "w", encoding="utf-8") as f:
                json.dump(sdata, f, indent=2)

            env_path = os.path.join(edutrace_dir, ".env")
            with open(env_path, "a", encoding="utf-8") as f:
                f.write(f"\nGEMINI_API_KEY={yeni_key}\n")
        except Exception as exc:
            print(f"[!] API anahtari dosyaya yazilamadi: {exc}")

    if basarili:
        msg = "Google Gemini API anahtarı başarıyla bağlandı!" if CURRENT_LANG == "tr" else "Google Gemini API key connected successfully!"
        socketio.emit("islem_bildirimi", {"durum": "basarili", "mesaj": msg})
    else:
        msg = "API anahtarı temizlendi, dahili şablon devrede." if CURRENT_LANG == "tr" else "API key cleared, built-in template active."
        socketio.emit("islem_bildirimi", {"durum": "bilgi", "mesaj": msg})


def _baglantilar() -> list:
    """Return inet connections; empty list if access is denied (run as admin)."""
    try:
        return psutil.net_connections(kind="inet")
    except (psutil.AccessDenied, OSError) as exc:
        print(f"[!] Baglanti listesi okunamadi (yonetici olarak calistirin): {exc}")
        return []


def surec_bilgisi_al(hedef_ip: str) -> tuple[str, int | None]:
    """Map a remote IP to its owning process name and PID."""
    for conn in _baglantilar():
        if conn.raddr and conn.raddr.ip == hedef_ip and conn.pid:
          try:
            process = psutil.Process(conn.pid)
            return process.name(), conn.pid
          except (psutil.NoSuchProcess, psutil.AccessDenied):
            continue
    return "Bilinmeyen Kaynak", None


def ag_ronto_cek(sure: int) -> dict[str, dict[str, Any]]:
    """Capture TCP, UDP and ICMP packets for ``sure`` seconds and aggregate per source IP."""
    paketler = sniff(filter="ip", timeout=sure)
    stats: dict[str, dict[str, Any]] = defaultdict(lambda: {"p": 0, "pt": set(), "udp_p": 0, "icmp_p": 0})
    for pkt in paketler:
        if IP in pkt:
            src_ip = pkt[IP].src
            stats[src_ip]["p"] += 1

            if TCP in pkt:
                dport = pkt[TCP].dport
                flags = int(pkt[TCP].flags)
                stats[src_ip]["pt"].add(dport)
                imza_motoru.kayit_ekle(src_ip, dport, "TCP", flags)
            elif UDP in pkt:
                dport = pkt[UDP].dport
                stats[src_ip]["pt"].add(dport)
                stats[src_ip]["udp_p"] += 1
                imza_motoru.kayit_ekle(src_ip, dport, "UDP", 0)
            elif ICMP in pkt:
                stats[src_ip]["icmp_p"] += 1
                imza_motoru.kayit_ekle(src_ip, 0, "ICMP", 0)

    return stats


def emit_temiz_trafik(ip: str, paket: int) -> None:
    """Emit clean-traffic events with per-IP throttling."""
    now = time.time()
    if now - _last_traffic_emit.get(ip, 0) < TRAFFIC_EMIT_COOLDOWN:
        return
    _last_traffic_emit[ip] = now
    socketio.emit("temiz_trafik", {"ip": ip, "paket": paket})


def _tehdit_isle(
    ip: str, exe_adi: str, pid: int | None, saldiri_turu: str = "Supheli Ag Taramasi", aciklama: str = ""
) -> None:
    """Run threat intelligence, blocking, and educational reporting in background."""
    try:
        print(f"\n[!!!] TEHDIT YAKALANDI: {ip} -> {saldiri_turu}")
        istihbarat_raporu = tehdit_motoru.analiz_et_ve_karar_ver(ip)

        # Yerel ag veya kural motoru tarafindan yakalanan somut saldirilar harici API'ye bagimli olmadan otonom engellenir
        imza_saldirisi = any(k in saldiri_turu.lower() for k in ["scan", "tarama", "flood", "brute", "anomali", "stealth", "dos"])
        if istihbarat_raporu["otonom_karar"] != "ENGELLE" and not imza_saldirisi:
            print(f"[+] API Analizi Sonucu: Yanlis alarm, {ip} guvenli gorunuyor.")
            return

        with _state_lock:
            ENGELLENEN_IPLER.add(ip)

        print(f"[X] OTONOM MUDAHALE: {ip} ({saldiri_turu}) engelleniyor...")
        if pid and exe_adi.lower() in KORUNAN_SURECLER:
            islem_durumu = f"Korunan sistem sureci ({exe_adi}) sonlandirilmadi; {ip} izleme listesine alindi."
        elif pid and AUTO_TERMINATE:
            try:
                psutil.Process(int(pid)).terminate()
                islem_durumu = f"Zararli surec ({exe_adi}) otonom olarak sonlandirildi."
            except (psutil.NoSuchProcess, psutil.AccessDenied) as exc:
                islem_durumu = f"Surece mudahale edilemedi: {exc}"
        elif pid:
            islem_durumu = (
                f"Supheli surec ({exe_adi}, PID {pid}) tespit edildi. "
                f"Saldiri Turu: {saldiri_turu}."
            )
        else:
            islem_durumu = f"Dis kaynakli saldiri engellendi ({ip}). Tehdit: {saldiri_turu}."

        if FIREWALL_BLOCK:
            fw = firewall.ip_engelle(ip)
            print(f"[*] Guvenlik duvari: {fw.message}")
            islem_durumu += f" {fw.message}"

        print("[*] Egitici Asistan (Gemini) rapor hazirliyor...")
        egitici_rapor = egitici_motor.tavsiye_uret(
            exe_adi, ip, istihbarat_raporu["vt_skor"], saldiri_turu=saldiri_turu
        )
        socketio.emit(
            "islem_sonucu",
            {
                "mesaj": islem_durumu,
                "durum": "basarili",
                "saldiri_turu": saldiri_turu,
                "aciklama": aciklama,
                "egitici_rapor": egitici_rapor,
            },
        )
    except Exception as exc:
        print(f"[!] Tehdit isleme hatasi ({ip}): {type(exc).__name__}: {exc}")
    finally:
        with _state_lock:
            _isleniyor.discard(ip)


def canli_gorev_yoneticisi() -> None:
    """Periodically publish active network processes to connected clients."""
    while True:
        aktif_uygulamalar: list[dict[str, Any]] = []
        gordugum_pidler: set[int] = set()
        for conn in _baglantilar():
          if conn.status != "ESTABLISHED" or not conn.pid or conn.pid in gordugum_pidler:
            continue
          try:
            process = psutil.Process(conn.pid)
            aktif_uygulamalar.append(
              {
                "ad": process.name(),
                "pid": process.pid,
                "ip": conn.raddr.ip if conn.raddr else "Bilinmiyor",
              }
            )
            gordugum_pidler.add(conn.pid)
          except (psutil.NoSuchProcess, psutil.AccessDenied):
            continue

        socketio.emit("aktif_uygulamalar", aktif_uygulamalar)
        time.sleep(PROCESS_SCAN_INTERVAL)


def edutrace_sentinel_motoru() -> None:
    """Main XDR loop: sniff traffic, detect anomalies, and enqueue threat handling."""
    global _last_npcap_warn
    print(f"[*] FAZ 1: Baz trafik ogreniliyor (en az {MIN_TRAINING_SAMPLES} ornek)...")
    model_hazir = False
    son_egitim = time.time()
    while True:
        su_an = time.time()
        try:
            anlik = ag_ronto_cek(SNIFF_TIMEOUT)
        except Exception as exc:  # Npcap eksik / yetki yok vb.
            print(f"[!] Paket yakalama hatasi: {exc}. 5 sn sonra tekrar denenecek.")
            msg_str = str(exc).lower()
            if "winpcap" in msg_str or "npcap" in msg_str:
                if su_an - _last_npcap_warn > 60.0:
                    _last_npcap_warn = su_an
                    socketio.emit(
                        "islem_bildirimi",
                        {
                            "durum": "hata",
                            "mesaj": "Npcap surucusu bulunamadi! Paket yakalamak icin npcap.com adresinden Npcap kurmalisiniz.",
                        },
                    )
            time.sleep(5)
            continue

        for ip, veri in anlik.items():
            with _state_lock:
                if ip in BEYAZ_LISTE or ip in ENGELLENEN_IPLER or ip in _isleniyor:
                    continue

            port_sayisi = len(veri["pt"])
            anomali = 1
            if model_hazir:
                anomali = yapay_zeka.predict(
                    pd.DataFrame([{"p": veri["p"], "pt": port_sayisi}])
                )[0]

            # 1. Kural Tabanlı Tehdit İmzası Kontrolü (SYN Flood, UDP Flood, ICMP, Brute Force, Stealth Scan)
            imza_alarmi: ThreatAlert | None = imza_motoru.analiz_et(ip, veri)

            kesin_tarama = veri["p"] > 1000 and port_sayisi > 50
            ml_anomali = anomali == -1 and port_sayisi > 20

            if imza_alarmi is not None:
                imza_motoru.sifirla(ip)
                if su_an - _last_threat_time.get(ip, 0) < THREAT_COOLDOWN:
                    continue
                _last_threat_time[ip] = su_an
                with _state_lock:
                    _isleniyor.add(ip)
                exe_adi, pid = surec_bilgisi_al(ip)
                _background_executor.submit(
                    _tehdit_isle, ip, exe_adi, pid, imza_alarmi.attack_type, imza_alarmi.description
                )
            elif kesin_tarama or ml_anomali:
                if su_an - _last_threat_time.get(ip, 0) < THREAT_COOLDOWN:
                    continue
                _last_threat_time[ip] = su_an
                with _state_lock:
                    _isleniyor.add(ip)
                saldiri_adi = "Agresif Port Taramasi (DDoS/Kesif)" if kesin_tarama else "Yapay Zeka Anomali Tespiti"
                aciklama = f"{ip} adresinden {port_sayisi} farkli porta {veri['p']} adet supheli paket gonderildi."
                exe_adi, pid = surec_bilgisi_al(ip)
                _background_executor.submit(_tehdit_isle, ip, exe_adi, pid, saldiri_adi, aciklama)
            else:
                dinamik_egitim_havuzu.append({"p": veri["p"], "pt": port_sayisi})
                emit_temiz_trafik(ip, veri["p"])

        if (
            su_an - son_egitim > ML_RETRAIN_INTERVAL
            and len(dinamik_egitim_havuzu) >= MIN_TRAINING_SAMPLES
        ):
            yapay_zeka.fit(pd.DataFrame(list(dinamik_egitim_havuzu)))
            model_hazir = True
            son_egitim = su_an


if __name__ == "__main__":
    print("EduTrace v10.0 [Tam Otonom XDR ve AI Egitmen] Baslatiliyor...")
    print("-" * 75)
    print(f"[*] Sistem IP Adresi: {AKTIF_IP}")
    print("-" * 75)

    threading.Thread(target=edutrace_sentinel_motoru, daemon=True).start()
    threading.Thread(target=canli_gorev_yoneticisi, daemon=True).start()
    print(f"[*] Radyo Kulesi Yayin Yapiyor -> IP: {SERVER_HOST} Port: {SERVER_PORT}")
    socketio.run(
        app,
        host=SERVER_HOST,
        port=SERVER_PORT,
        debug=False,
        use_reloader=False,
        allow_unsafe_werkzeug=True,
    )
