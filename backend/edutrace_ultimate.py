"""
EduTrace XDR Backend — Autonomous network threat detection and education engine.

Captures IPv4/IPv6 traffic via Scapy, detects anomalies with IsolationForest,
checks IPs against offline blocklists (Spamhaus DROP, Feodo Tracker), generates
educational reports via Gemini AI, and streams events to the Flutter dashboard
over Flask-SocketIO.
"""

from __future__ import annotations

import hmac
import importlib
import importlib.util
import os
import secrets
import socket
import subprocess
import sys
import threading
import time
import warnings
from collections import defaultdict, deque
from concurrent.futures import ThreadPoolExecutor, TimeoutError as FuturesTimeoutError
from functools import wraps
from typing import Any

import ipaddress
import pandas as pd
import psutil
from dotenv import load_dotenv
from flask import Flask, request
from flask_socketio import SocketIO
from google import genai
from scapy.all import IP, IPv6, TCP, UDP, ICMP, ICMPv6EchoRequest, sniff
from sklearn.ensemble import IsolationForest

import firewall
from ayarlar import GizliAyarlar
from gizli import GizliHata, coz, sifrele
from olay_gecmisi import OlayGecmisi
from pro_kancalari import ProKancalari
from threat_intel import TehditListeleri
from threat_rules import ThreatSignatureEngine, ThreatAlert

imza_motoru = ThreatSignatureEngine(window_seconds=60)

warnings.filterwarnings("ignore")


def _env_yukle() -> None:
    """Load .env from next to the engine exe or %PROGRAMDATA%\\EduTrace.

    The Gemini key the user enters in the panel is not read from here; it is
    kept DPAPI-encrypted in gizli.json (see gemini_anahtarini_hazirla).
    """
    adaylar = []
    if getattr(sys, "frozen", False):
        adaylar.append(os.path.join(os.path.dirname(sys.executable), ".env"))
    programdata = os.getenv("PROGRAMDATA")
    if programdata:
        adaylar.append(os.path.join(programdata, "EduTrace", ".env"))
    for yol in adaylar:
        if os.path.isfile(yol):
            load_dotenv(yol)
            break
    else:
        load_dotenv()


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
# Automatic firewall blocking and process termination are EduTrace Pro
# settings (see pro_kancalari.py), off by default so a false positive never
# cuts the user's connection or kills their program without them opting in.
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
        # Connections stay provisional until the connect handler accepts the token
        always_connect=False,
)

# Per-run secret the dashboard must present; empty means every client is refused.
AUTH_TOKEN = ""
_yetkili_istemciler: set[str] = set()


def token_dosyasi_yolu() -> str:
    """Location of the token file the Flutter dashboard reads before connecting."""
    kok = os.getenv("PROGRAMDATA") or os.path.expanduser("~")
    return os.path.join(kok, "EduTrace", "auth.token")


def yetki_tokeni_olustur() -> str:
    """Create a fresh token and store it where only this user, admins and SYSTEM can read it.

    Returns "" when the file cannot be written: the panel could never learn the
    token, so the engine should not run (see ``__main__``).
    """
    token = secrets.token_urlsafe(32)
    yol = token_dosyasi_yolu()
    try:
        os.makedirs(os.path.dirname(yol), exist_ok=True)
        # Recreate the file ourselves: a file planted by another user would let its
        # owner rewrite the permissions and read the token.
        if os.path.exists(yol):
            os.remove(yol)
        os.close(os.open(yol, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600))
        # Lock the empty file down before the secret is written into it
        if sys.platform == "win32":
            # Every user may read %PROGRAMDATA%\EduTrace, so drop inherited rights
            kullanici = os.getenv("USERNAME", "")
            sonuc = subprocess.run(
                ["icacls", yol, "/inheritance:r", "/grant:r",
                 f"{kullanici}:F", "*S-1-5-32-544:F", "*S-1-5-18:F"],
                capture_output=True, timeout=10, check=False, shell=False,
            )
            if sonuc.returncode != 0:
                raise OSError(f"icacls basarisiz: {sonuc.stdout or sonuc.stderr}")
        with open(yol, "w", encoding="utf-8") as f:
            f.write(token)
    except (OSError, subprocess.TimeoutExpired) as exc:
        print(f"[!] Yetki tokeni yazilamadi, panel baglanamayacak: {exc}")
        return ""
    return token


@socketio.on("connect")
def istemci_baglandi(auth: Any = None) -> None:
    """Accept only clients that present this run's token."""
    gelen = str(auth.get("token", "")) if isinstance(auth, dict) else ""
    if not AUTH_TOKEN or not hmac.compare_digest(gelen.encode(), AUTH_TOKEN.encode()):
        print(f"[!] Yetkisiz Socket.IO baglantisi reddedildi ({request.remote_addr})")
        raise ConnectionRefusedError("yetkisiz")
    _yetkili_istemciler.add(request.sid)
    socketio.emit("ai_durumu", ai_durumu(), to=request.sid)


@socketio.on("disconnect")
def istemci_ayrildi(*_args: Any) -> None:
    _yetkili_istemciler.discard(request.sid)


def yetkili(handler):
    """Drop events from clients that did not authenticate (defence in depth)."""
    @wraps(handler)
    def sarmalayici(*args: Any, **kwargs: Any) -> Any:
        if request.sid not in _yetkili_istemciler:
            print(f"[!] Yetkisiz '{handler.__name__}' istegi yok sayildi.")
            return None
        return handler(*args, **kwargs)
    return sarmalayici

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
YEREL_ADRES_YENILEME = 60


def yerel_adresleri_bul() -> set[str]:
    """Every IPv4/IPv6 address of this machine.

    An IPv6 host usually has several at once (stable, temporary privacy and
    link-local fe80:: addresses), and temporary ones rotate, so a single
    "our IP" is not enough to tell our own traffic apart.
    """
    adresler = {"127.0.0.1", "::1", AKTIF_IP}
    try:
        for liste in psutil.net_if_addrs().values():
            for adres in liste:
                if adres.family not in (socket.AF_INET, socket.AF_INET6):
                    continue
                try:
                    # Drop the "%12" zone index Windows appends to link-local addresses
                    adresler.add(ipaddress.ip_address(adres.address.split("%")[0]).compressed)
                except ValueError:
                    continue
    except OSError as exc:
        print(f"[!] Ag arayuzu adresleri okunamadi: {exc}")
    return adresler


YEREL_ADRESLER = yerel_adresleri_bul()
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
        self, uygulama_adi: str, hedef_ip: str, istihbarat: str, saldiri_turu: str = "Supheli Ag Taramasi"
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
Threat Intelligence: {istihbarat}

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
Tehdit Istihbarati: {istihbarat}

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



def _istihbarat_klasoru() -> str:
    """Where the blocklists are cached.

    The installed engine keeps them next to its exe (Program Files, admin-only
    writes) so a standard user cannot plant entries; source runs use ProgramData.
    """
    if getattr(sys, "frozen", False):
        return os.path.join(os.path.dirname(sys.executable), "intel")
    return os.path.join(os.getenv("PROGRAMDATA") or os.path.expanduser("~"), "EduTrace", "intel")


LISTE_KONTROL_ARALIGI = 3600


def istihbarat_sorgula(ip: str) -> dict[str, Any]:
    """Look an IP up in the local blocklists; nothing is sent over the network."""
    eslesmeler = tehdit_listeleri.kontrol_et(ip)
    return {
        "ip": ip,
        "istihbarat_skoru": len(eslesmeler),
        "kaynaklar": [f"{e.kaynak} ({e.detay})" for e in eslesmeler],
    }


def istihbarat_ozeti(rapor: dict[str, Any]) -> str:
    """One-line description of a lookup for logs and AI reports."""
    if rapor.get("kaynaklar"):
        return ", ".join(rapor["kaynaklar"])
    return "Bilinen tehdit listelerinde yok"


def tehdit_listesi_guncelleyici() -> None:
    """Keep the blocklists fresh; each list is only downloaded when older than 12 hours."""
    while True:
        tehdit_listeleri.guncelle()
        time.sleep(LISTE_KONTROL_ARALIGI)


egitici_motor = EgiticiAsistanMotoru()
# Secrets entered in the panel, DPAPI-encrypted, file readable only by admins/SYSTEM
gizli_ayarlar = GizliAyarlar(
    os.path.join(os.getenv("PROGRAMDATA") or os.path.expanduser("~"), "EduTrace", "gizli.json")
)


def eski_gemini_anahtarlarini_tasi() -> None:
    """Move the plaintext Gemini key older versions left in %APPDATA%\\EduTrace.

    1.1 and earlier wrote it to settings.json and appended a GEMINI_API_KEY line
    to .env on every change. The key moves into gizli.json and both copies go.
    """
    import json

    appdata = os.getenv("APPDATA")
    if not appdata:
        return
    klasor = os.path.join(appdata, "EduTrace")
    ayar_yolu = os.path.join(klasor, "settings.json")
    try:
        with open(ayar_yolu, encoding="utf-8") as f:
            ayarlar = json.load(f)
    except (OSError, ValueError):
        ayarlar = None
    if isinstance(ayarlar, dict) and "gemini_api_key" in ayarlar:
        eski = str(ayarlar.pop("gemini_api_key") or "").strip()
        try:
            if eski and not gizli_ayarlar.al("gemini_api_key"):
                gizli_ayarlar.guncelle({"gemini_api_key": sifrele(eski)})
            with open(ayar_yolu, "w", encoding="utf-8") as f:
                json.dump(ayarlar, f)
            print("[+] Eski duz metin Gemini anahtari sifreli depoya tasindi.")
        except (OSError, GizliHata) as exc:
            print(f"[!] Eski Gemini anahtari tasinamadi: {exc}")
            return

    env_yolu = os.path.join(klasor, ".env")
    try:
        with open(env_yolu, encoding="utf-8") as f:
            satirlar = f.readlines()
    except OSError:
        return
    kalan = [s for s in satirlar if not s.strip().startswith("GEMINI_API_KEY")]
    if len(kalan) != len(satirlar):
        try:
            if any(s.strip() for s in kalan):
                with open(env_yolu, "w", encoding="utf-8") as f:
                    f.writelines(kalan)
            else:
                os.remove(env_yolu)
        except OSError as exc:
            print(f"[!] Eski .env temizlenemedi: {exc}")


def gemini_anahtarini_hazirla() -> None:
    """Use the key saved from the panel; GEMINI_API_KEY in .env is the fallback."""
    eski_gemini_anahtarlarini_tasi()
    try:
        anahtar = coz(gizli_ayarlar.al("gemini_api_key", ""))
    except GizliHata as exc:
        print(f"[!] Kayitli Gemini anahtari cozulemedi: {exc}")
        return
    if anahtar:
        egitici_motor.guncelle_api_key(anahtar)


def ai_durumu() -> dict[str, Any]:
    return {"anahtar_var": egitici_motor.client is not None}
tehdit_listeleri = TehditListeleri(_istihbarat_klasoru())


@socketio.on("karar_ver")
@yetkili
def karar_uygula(_data: dict[str, Any]) -> None:
    """Reject manual intervention requests while autonomous mode is active."""
    print("[!] Manuel mudahale reddedildi. Sistem otonom XDR modunda calisiyor.")


@socketio.on("surec_sonlandir")
@yetkili
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
@yetkili
def ip_manuel_engelle(data: dict[str, Any]) -> None:
    """Blocks an IP address on Windows Firewall on user request."""
    ip = data.get("ip", "")
    if not ip or ip in BEYAZ_LISTE or ip in YEREL_ADRESLER:
        socketio.emit("islem_bildirimi", {"durum": "hata", "mesaj": f"{ip} guvenli listede veya gecersiz!"})
        return

    fw = firewall.ip_engelle(ip)
    with _state_lock:
        ENGELLENEN_IPLER.add(ip)
    if fw.ok:
        engeli_kaydet(ip, "Manuel engelleme")
    socketio.emit(
        "islem_bildirimi",
        {"durum": "basarili" if fw.ok else "hata", "mesaj": fw.message},
    )


def _veri_klasoru() -> str:
    return os.path.join(os.getenv("PROGRAMDATA") or os.path.expanduser("~"), "EduTrace")


olay_gecmisi = OlayGecmisi(os.path.join(_veri_klasoru(), "olaylar.db"))
# Firewall rules outlive the engine, so the list of what EduTrace blocked does too
engel_kayitlari = GizliAyarlar(os.path.join(_veri_klasoru(), "engellenenler.json"))
ENGELLENEN_IPLER.update(engel_kayitlari.hepsi())


def engeli_kaydet(ip: str, neden: str) -> None:
    try:
        engel_kayitlari.guncelle({ip: {"zaman": time.time(), "neden": neden}})
    except OSError as exc:
        print(f"[!] Engel kaydi yazilamadi: {exc}")


def engellenenleri_gonder() -> None:
    kayitlar = [
        {"ip": ip, **bilgi}
        for ip, bilgi in engel_kayitlari.hepsi().items()
        if isinstance(bilgi, dict)
    ]
    kayitlar.sort(key=lambda k: k.get("zaman", 0), reverse=True)
    socketio.emit("engellenenler", kayitlar)


@socketio.on("engellenenler_iste")
@yetkili
def engellenenler_iste(_data: Any = None) -> None:
    engellenenleri_gonder()


@socketio.on("engeli_kaldir")
@yetkili
def engeli_kaldir(data: Any) -> None:
    """Undo a block. Free: every user must be able to reverse a block."""
    ip = str(data.get("ip", "")) if isinstance(data, dict) else ""
    if not ip or engel_kayitlari.al(ip) is None:
        socketio.emit("islem_bildirimi", {"durum": "hata", "mesaj": f"{ip} EduTrace tarafindan engellenmemis."})
        return
    fw = firewall.ip_engeli_kaldir(ip)
    if fw.ok:
        try:
            engel_kayitlari.guncelle({ip: None})
        except OSError as exc:
            print(f"[!] Engel kaydi silinemedi: {exc}")
        with _state_lock:
            ENGELLENEN_IPLER.discard(ip)
        _last_threat_time.pop(ip, None)
    socketio.emit("islem_bildirimi", {"durum": "basarili" if fw.ok else "hata", "mesaj": fw.message})
    engellenenleri_gonder()


def gecmis_gunu(data: Any) -> int:
    """Requested history window, capped by the edition (1 day free)."""
    try:
        gun = int(data.get("gun", 1)) if isinstance(data, dict) else 1
    except (TypeError, ValueError):
        gun = 1
    return max(1, min(gun, pro.gecmis_gun_siniri()))


@socketio.on("gecmis_iste")
@yetkili
def gecmis_iste(data: Any = None) -> None:
    gun = gecmis_gunu(data)
    socketio.emit(
        "gecmis",
        {"gun": gun, "pro": pro.aktif, "olaylar": olay_gecmisi.listele(gun, limit=500)},
        to=request.sid,
    )


@socketio.on("lisans_durumu")
@yetkili
def lisans_durumu_al(data: Any) -> None:
    """The panel forwards the license key; only the Pro add-on can verify it.

    An ``is_pro`` flag from the panel is ignored: the engine never takes the
    client's word for it.
    """
    data = data if isinstance(data, dict) else {}
    pro.lisans_al(str(data.get("license_key") or ""), str(data.get("instance_id") or ""))


@socketio.on("dil_degistir")
@yetkili
def dil_degistir_al(data: dict[str, Any]) -> None:
    """Updates the active language ('tr' or 'en') for AI generation and system messages."""
    global CURRENT_LANG
    yeni_dil = str(data.get("dil", "tr")).lower()
    if yeni_dil in ("tr", "en"):
        CURRENT_LANG = yeni_dil
        print(f"[+] Dil secimi guncellendi: {CURRENT_LANG.upper()}")


@socketio.on("simulasyon_baslat")
@yetkili
def simulasyon_baslat(data: dict[str, Any] | None = None) -> None:
    """Triggers a safe, realistic educational threat simulation showcasing XDR defense."""
    print("[*] Egitici Tehdit Simulasyonu Baslatiliyor...")

    sim_ip = "203.0.113.42"  # RFC 5737 TEST-NET-3 (Safe test IP)

    if CURRENT_LANG == "en":
        saldiri_turu = "Nmap Stealth Scan (SYN/FIN Probe)"
        aciklama = f"Security Simulation: Detected covert port probe from {sim_ip} attempting to map open services."
        if pro.aktif:
            islem_durumu = f"[PRO SHIELD] Autonomous active defense isolated {sim_ip} and intercepted suspicious reconnaissance."
        else:
            islem_durumu = f"Security threat intercepted ({sim_ip}). Threat: {saldiri_turu}."
    else:
        saldiri_turu = "Gizli Ağ Taraması (Nmap Stealth Scan)"
        aciklama = f"Güvenlik Simülasyonu: {sim_ip} adresinden açık portları tespit etmeye çalışan gizli TCP bayrak kombinasyonları yakalandı."
        if pro.aktif:
            islem_durumu = f"[PRO KALKAN] Otonom savunma devreye girdi; {sim_ip} adresi izole edildi ve saldırı engellendi."
        else:
            islem_durumu = f"Dış kaynaklı saldırı engellendi ({sim_ip}). Tehdit: {saldiri_turu}."

    def _calistir() -> None:
        try:
            # Emit incoming suspicious traffic for visual feedback on radar/traffic table
            socketio.emit("temiz_trafik", {"ip": sim_ip, "paket": 1420})
            time.sleep(0.6)  # Realistic simulation delay
            egitici_rapor = egitici_motor.tavsiye_uret(
                "nmap_recon.exe", sim_ip, "Simulasyon (Spamhaus DROP eslesmesi)", saldiri_turu=saldiri_turu
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
        # Let users check their alert channels end to end; marked so nobody
        # mistakes it for a real attack. Pro's per-IP limit still applies.
        try:
            pro.alarm_sonrasi(sim_ip, f"[Simulasyon] {saldiri_turu}", islem_durumu, aciklama)
        except Exception as exc:
            print(f"[!] Simulasyon bildirimi gonderilemedi: {exc}")

    threading.Thread(target=_calistir, daemon=True).start()


@socketio.on("gemini_key_guncelle")
@yetkili
def gemini_key_guncelle_al(data: dict[str, Any]) -> None:
    """Update the Gemini key in memory and store it DPAPI-encrypted; "" removes it."""
    yeni_key = str(data.get("api_key", "") if isinstance(data, dict) else "").strip()
    try:
        gizli_ayarlar.guncelle({"gemini_api_key": sifrele(yeni_key) or None})
    except (OSError, GizliHata) as exc:
        print(f"[!] API anahtari kaydedilemedi: {exc}")
        socketio.emit("islem_bildirimi", {"durum": "hata", "mesaj": f"API anahtari kaydedilemedi: {exc}"})
        return
    basarili = egitici_motor.guncelle_api_key(yeni_key)
    socketio.emit("ai_durumu", ai_durumu())

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


def ip_adresleri(pkt: Any) -> tuple[str, str] | None:
    """Source and destination of an IPv4 or IPv6 packet, or ``None`` for anything else."""
    if IP in pkt:
        return pkt[IP].src, pkt[IP].dst
    if IPv6 in pkt:
        return pkt[IPv6].src, pkt[IPv6].dst
    return None


def ag_ronto_cek(sure: int) -> dict[str, dict[str, Any]]:
    """Capture IPv4/IPv6 TCP, UDP and ICMP packets for ``sure`` seconds and aggregate per source IP."""
    paketler = sniff(filter="ip or ip6", timeout=sure)
    stats: dict[str, dict[str, Any]] = defaultdict(lambda: {"p": 0, "pt": set(), "udp_p": 0, "icmp_p": 0})
    for pkt in paketler:
        adresler = ip_adresleri(pkt)
        if adresler is None:
            continue
        src_ip, dst_ip = adresler
        bizden = src_ip in YEREL_ADRESLER
        stats[src_ip]["p"] += 1

        if TCP in pkt:
            sport, dport = pkt[TCP].sport, pkt[TCP].dport
            flags = int(pkt[TCP].flags)
            if bizden:
                imza_motoru.giden_tcp_kaydet(dst_ip, dport)
            # A server's reply lands on our ephemeral port, which is not a scan target
            if not imza_motoru.tcp_yanit_mi(src_ip, sport, flags):
                stats[src_ip]["pt"].add(dport)
            imza_motoru.kayit_ekle(src_ip, dport, "TCP", flags, sport=sport)
        elif UDP in pkt:
            sport, dport = pkt[UDP].sport, pkt[UDP].dport
            if bizden:
                imza_motoru.giden_udp_kaydet(dst_ip, dport)
            # On a reply to our own request, dport is just our ephemeral port, not a target
            if not imza_motoru.udp_yanit_mi(src_ip, sport):
                stats[src_ip]["pt"].add(dport)
            stats[src_ip]["udp_p"] += 1
            imza_motoru.kayit_ekle(src_ip, dport, "UDP", 0, sport=sport)
        # ICMPv6 also carries neighbour discovery and router adverts; only echo requests are pings
        elif ICMP in pkt or ICMPv6EchoRequest in pkt:
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


# Where an alert came from decides how much evidence it carries
KAYNAK_IMZA = "imza"  # signature rule matched concrete attack behaviour
KAYNAK_ESIK = "esik"  # hard volume threshold (1000+ packets to 50+ ports)
KAYNAK_ML = "ml"      # IsolationForest: traffic is unusual, not proven malicious


def engelleme_karari(kaynak: str, istihbarat: dict[str, Any]) -> bool:
    """Whether an alert is acted on (firewall, process kill) or only reported.

    Rule and threshold alerts are based on observed attack behaviour. An ML
    anomaly only says the traffic is unusual, so the IP has to be on a threat
    intelligence blocklist before anything is blocked.
    """
    if kaynak in (KAYNAK_IMZA, KAYNAK_ESIK):
        return True
    skor = istihbarat.get("istihbarat_skoru")
    return isinstance(skor, int) and not isinstance(skor, bool) and skor > 0


def _tehdit_isle(
    ip: str,
    exe_adi: str,
    pid: int | None,
    saldiri_turu: str = "Supheli Ag Taramasi",
    aciklama: str = "",
    kaynak: str = KAYNAK_ML,
) -> None:
    """Run threat intelligence, blocking, and educational reporting in background."""
    try:
        if pro.beyaz_listede(ip):
            print(f"[~] {ip} kullanicinin beyaz listesinde; alarm yok sayildi.")
            return
        print(f"\n[!!!] TEHDIT YAKALANDI: {ip} -> {saldiri_turu} (kaynak: {kaynak})")
        istihbarat_raporu = istihbarat_sorgula(ip)

        if not engelleme_karari(kaynak, istihbarat_raporu):
            print(
                f"[~] {ip}: ML anomalisi tehdit listelerinde dogrulanmadi; "
                "engellenmedi, izlenmeye devam ediliyor."
            )
            olay_gecmisi.kaydet(ip, saldiri_turu, kaynak, aciklama, "Izleniyor (engellenmedi)", False)
            socketio.emit(
                "islem_bildirimi",
                {
                    "durum": "bilgi",
                    "mesaj": f"{ip} adresinde olagan disi trafik goruldu ({saldiri_turu}); "
                    "bilinen tehdit listelerinde olmadigi icin engellenmedi, izleniyor.",
                },
            )
            return

        with _state_lock:
            ENGELLENEN_IPLER.add(ip)

        print(f"[X] OTONOM MUDAHALE: {ip} ({saldiri_turu}) engelleniyor...")
        if pid and exe_adi.lower() in KORUNAN_SURECLER:
            islem_durumu = f"Korunan sistem sureci ({exe_adi}) sonlandirilmadi; {ip} izleme listesine alindi."
        elif pid and pro.oto_sonlandir():
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
            islem_durumu = f"Dis kaynakli saldiri tespit edildi ({ip}). Tehdit: {saldiri_turu}."

        if pro.oto_firewall():
            fw = firewall.ip_engelle(ip)
            print(f"[*] Guvenlik duvari: {fw.message}")
            islem_durumu += f" {fw.message}"
            if fw.ok:
                engeli_kaydet(ip, saldiri_turu)

        print("[*] Egitici Asistan (Gemini) rapor hazirliyor...")
        egitici_rapor = egitici_motor.tavsiye_uret(
            exe_adi, ip, istihbarat_ozeti(istihbarat_raporu), saldiri_turu=saldiri_turu
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
        olay_gecmisi.kaydet(ip, saldiri_turu, kaynak, aciklama, islem_durumu, True)
        _background_executor.submit(pro.alarm_sonrasi, ip, saldiri_turu, islem_durumu, aciklama)
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
    global _last_npcap_warn, YEREL_ADRESLER
    print(f"[*] FAZ 1: Baz trafik ogreniliyor (en az {MIN_TRAINING_SAMPLES} ornek)...")
    model_hazir = False
    son_egitim = time.time()
    son_adres_yenileme = time.time()
    while True:
        su_an = time.time()
        # Temporary IPv6 addresses rotate; keep our own traffic recognisable
        if su_an - son_adres_yenileme > YEREL_ADRES_YENILEME:
            YEREL_ADRESLER = yerel_adresleri_bul()
            son_adres_yenileme = su_an
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
                if (
                    ip in BEYAZ_LISTE
                    or ip in YEREL_ADRESLER
                    or ip in ENGELLENEN_IPLER
                    or ip in _isleniyor
                ):
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
                    _tehdit_isle, ip, exe_adi, pid, imza_alarmi.attack_type, imza_alarmi.description,
                    KAYNAK_IMZA,
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
                kaynak = KAYNAK_ESIK if kesin_tarama else KAYNAK_ML
                _background_executor.submit(_tehdit_isle, ip, exe_adi, pid, saldiri_adi, aciklama, kaynak)
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


def pro_eklentisini_yukle() -> ProKancalari:
    """Use the private EduTrace Pro add-on when it is installed, else the free hooks."""
    if importlib.util.find_spec("edutrace_pro") is None:
        print("[*] EduTrace Pro modulu yok; ucretsiz surum calisiyor.")
        return ProKancalari(socketio)
    try:
        return importlib.import_module("edutrace_pro").kur(sys.modules[__name__])
    except Exception as exc:
        # A broken add-on must not take detection down with it
        print(f"[!] EduTrace Pro modulu yuklenemedi ({type(exc).__name__}: {exc}); ucretsiz surum calisiyor.")
        return ProKancalari(socketio)


pro = pro_eklentisini_yukle()

TEK_ORNEK_ADI = "EduTraceEngine"
_tek_ornek_tutamaci: Any = None


def tek_ornek_kilidi_al(ad: str = TEK_ORNEK_ADI) -> bool:
    """Whether this is the only engine running.

    A second engine would overwrite auth.token with a token the engine that
    owns port 5000 does not know, and the panel could never connect. That
    happens when the installer and the panel both start the engine at once.
    """
    global _tek_ornek_tutamaci
    if sys.platform != "win32":
        return True
    import ctypes
    from ctypes import wintypes

    kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
    kernel32.CreateMutexW.argtypes = [wintypes.LPVOID, wintypes.BOOL, wintypes.LPCWSTR]
    kernel32.CreateMutexW.restype = wintypes.HANDLE
    tutamac = kernel32.CreateMutexW(None, False, f"Global\\{ad}")
    hata = ctypes.get_last_error()
    # 183: another engine created it. 5: an elevated engine owns it and this
    # unelevated one may not open it, which also means one is already running.
    if hata in (183, 5):
        if tutamac:
            kernel32.CloseHandle(tutamac)
        return False
    if not tutamac:
        # Cannot create a lock at all: running unguarded beats not running
        print(f"[!] Tek kopya kilidi olusturulamadi (hata {hata}); devam ediliyor.")
        return True
    _tek_ornek_tutamaci = tutamac
    return True


if __name__ == "__main__":
    if not tek_ornek_kilidi_al():
        print("[*] EduTrace motoru zaten calisiyor; bu kopya kapaniyor.")
        sys.exit(0)
    print("EduTrace v1.2.0 [XDR ve AI Egitmen] Baslatiliyor...")
    print("-" * 75)
    print(f"[*] Sistem IP Adresi: {AKTIF_IP}")
    print("-" * 75)
    AUTH_TOKEN = yetki_tokeni_olustur()
    if not AUTH_TOKEN:
        # Typically an unelevated copy: exit and release the single-instance lock
        # so the elevated engine (scheduled task) can start instead.
        print("[!] Motor yonetici olarak calismali; bu kopya kapaniyor.")
        sys.exit(1)
    print(f"[+] Panel yetki tokeni olusturuldu: {token_dosyasi_yolu()}")
    gemini_anahtarini_hazirla()

    threading.Thread(target=edutrace_sentinel_motoru, daemon=True).start()
    threading.Thread(target=canli_gorev_yoneticisi, daemon=True).start()
    threading.Thread(target=tehdit_listesi_guncelleyici, daemon=True).start()
    pro.baslat()
    print(f"[*] Radyo Kulesi Yayin Yapiyor -> IP: {SERVER_HOST} Port: {SERVER_PORT}")
    socketio.run(
        app,
        host=SERVER_HOST,
        port=SERVER_PORT,
        debug=False,
        use_reloader=False,
        allow_unsafe_werkzeug=True,
    )
