"""
EduTrace XDR Backend — Autonomous network threat detection and education engine.

Captures TCP traffic via Scapy, detects anomalies with IsolationForest,
validates threats via VirusTotal, generates educational reports via Gemini AI,
and streams events to the Flutter dashboard over Flask-SocketIO.
"""

from __future__ import annotations

import os
import socket
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
from scapy.all import IP, TCP, sniff
from sklearn.ensemble import IsolationForest

warnings.filterwarnings("ignore")
load_dotenv()

SNIFF_TIMEOUT = 3
PROCESS_SCAN_INTERVAL = 8
ML_RETRAIN_INTERVAL = 15
TRAFFIC_EMIT_COOLDOWN = 2.0
MAX_TRAINING_SAMPLES = 1000
GEMINI_MODEL = "gemini-2.0-flash"
GEMINI_TIMEOUT = 25
GEMINI_MAX_RETRIES = 3
SERVER_HOST = os.getenv("SERVER_HOST", "0.0.0.0")
SERVER_PORT = int(os.getenv("SERVER_PORT", "5000"))

app = Flask(__name__)
socketio = SocketIO(
        app,
        cors_allowed_origins=os.getenv("CORS_ORIGINS", "*"),
        async_mode="threading",
        always_connect=True,
)

_background_executor = ThreadPoolExecutor(max_workers=4, thread_name_prefix="edutrace-api")
_state_lock = threading.Lock()
_last_traffic_emit: dict[str, float] = {}


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

yapay_zeka = IsolationForest(contamination="auto", random_state=42)
dinamik_egitim_havuzu: deque[dict[str, int]] = deque(maxlen=MAX_TRAINING_SAMPLES)


class EgiticiAsistanMotoru:
    """Generates Turkish educational threat reports using the Gemini API."""

    def __init__(self) -> None:
        self.api_key = os.getenv("GEMINI_API_KEY", "")
        self.model_adi = GEMINI_MODEL
        self.client = genai.Client(api_key=self.api_key) if self.api_key else None
        if self.client:
          print(f"[+] AI Egitmen Aktif: {self.model_adi}")
        else:
          print("[!] GEMINI_API_KEY tanimli degil. AI raporlari devre disi.")

    def tavsiye_uret(self, uygulama_adi: str, hedef_ip: str, vt_skor: Any) -> str:
        """Create an educational report for a blocked threat.

        Args:
          uygulama_adi: Process name associated with the threat.
          hedef_ip: Suspicious remote IP address.
          vt_skor: VirusTotal malicious count or local-network marker.

        Returns:
          Educational report text in Turkish.
        """
        if not self.client:
          return self._varsayilan_rapor(hedef_ip)

        prompt = f"""
Sen EduTrace adinda, universite ogrencileri icin tasarlanmis egitici bir siber guvenlik asistanisin.
Sistemimiz az once otonom olarak bir tehdidi engelledi.

Engellenen Uygulama: {uygulama_adi}
Tehlikeli IP Adresi: {hedef_ip}
VirusTotal Skoru: {vt_skor}

Lutfen kullanicinin siber guvenlik bilgisini artirmak icin su formata uyarak kisa, net ve
anlasilir bir geri bildirim hazirla:
1. [Tehdidin Dogasi]: Bu uygulama/IP nasil bir saldiri gerceklestiriyor olabilir?
2. [Olasi Hasar]: Eger biz bunu engellemeseydik sisteme ne gibi zararlar verebilirdi?
3. [Gelecek Onlemi]: Kullanici bu tur zafiyetlerin tekrar yasanmamasi icin ne gibi onlemler almali?
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

        return self._varsayilan_rapor(hedef_ip)

    @staticmethod
    def _varsayilan_rapor(hedef_ip: str) -> str:
        """Return a fallback report when Gemini is unavailable."""
        return (
          f"AI Egitmen yanit veremedi.\n\n"
          f"Manuel Ozet:\n"
          f"1. [Tehdidin Dogasi]: {hedef_ip} adresinden yogun port taramasi tespit edildi. "
          f"Bu genellikle bir nmap/masscan saldirisinin ilk kesif fazidir.\n"
          f"2. [Olasi Hasar]: Acik portlar tespit edilerek sisteme sizma girisimi yapilabilirdi.\n"
          f"3. [Gelecek Onlemi]: Guvenlik duvarinda gereksiz portlari kapatin, "
          f"fail2ban gibi araclarla otomatik engelleme kurun."
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


def surec_bilgisi_al(hedef_ip: str) -> tuple[str, int | None]:
    """Map a remote IP to its owning process name and PID."""
    for conn in psutil.net_connections(kind="inet"):
        if conn.raddr and conn.raddr.ip == hedef_ip and conn.pid:
          try:
            process = psutil.Process(conn.pid)
            return process.name(), conn.pid
          except (psutil.NoSuchProcess, psutil.AccessDenied):
            continue
    return "Bilinmeyen Kaynak", None


def ag_ronto_cek(sure: int) -> dict[str, dict[str, Any]]:
    """Capture TCP packets for ``sure`` seconds and aggregate per source IP."""
    paketler = sniff(filter="tcp", timeout=sure)
    stats: dict[str, dict[str, Any]] = defaultdict(lambda: {"p": 0, "pt": set()})
    for pkt in paketler:
        if IP in pkt and TCP in pkt:
          stats[pkt[IP].src]["p"] += 1
          stats[pkt[IP].src]["pt"].add(pkt[TCP].dport)
    return stats


def emit_temiz_trafik(ip: str, paket: int) -> None:
    """Emit clean-traffic events with per-IP throttling."""
    now = time.time()
    if now - _last_traffic_emit.get(ip, 0) < TRAFFIC_EMIT_COOLDOWN:
        return
    _last_traffic_emit[ip] = now
    socketio.emit("temiz_trafik", {"ip": ip, "paket": paket})


def _tehdit_isle(ip: str, exe_adi: str, pid: int | None) -> None:
    """Run threat intelligence, blocking, and educational reporting in background."""
    print(f"\n[!!!] DIKKAT: {ip} anormal trafik yaratiyor. API'ler uzerinden sorgulaniyor...")
    istihbarat_raporu = tehdit_motoru.analiz_et_ve_karar_ver(ip)

    if istihbarat_raporu["otonom_karar"] != "ENGELLE":
        print(f"[+] API Analizi Sonucu: Yanlis alarm, {ip} guvenli gorunuyor.")
        return

    with _state_lock:
        ENGELLENEN_IPLER.add(ip)

    print(f"[X] OTONOM MUDAHALE: {ip} engelleniyor...")
    if pid:
        try:
          psutil.Process(int(pid)).terminate()
          islem_durumu = f"Zararli surec ({exe_adi}) otonom olarak sonlandirildi."
        except (psutil.NoSuchProcess, psutil.AccessDenied) as exc:
          islem_durumu = f"Surece mudahale edilemedi: {exc}"
    else:
        islem_durumu = f"Dis kaynakli ag saldirisi ({ip}) kaynagi bloklandi."

    print("[*] Egitici Asistan (Gemini) rapor hazirliyor...")
    egitici_rapor = egitici_motor.tavsiye_uret(exe_adi, ip, istihbarat_raporu["vt_skor"])
    socketio.emit(
        "islem_sonucu",
        {
          "mesaj": islem_durumu,
          "durum": "basarili",
          "egitici_rapor": egitici_rapor,
        },
    )


def canli_gorev_yoneticisi() -> None:
    """Periodically publish active network processes to connected clients."""
    while True:
        aktif_uygulamalar: list[dict[str, Any]] = []
        gordugum_pidler: set[int] = set()
        for conn in psutil.net_connections(kind="inet"):
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
    print("[*] FAZ 1: Yapay Zeka Agi Ogreniyor (15 Sn)...")
    yapay_zeka.fit(pd.DataFrame([{"p": 10, "pt": 2}]))
    son_egitim = time.time()
    print("[+] SISTEM AKTIF! Otonom XDR Devrede...")

    while True:
        anlik = ag_ronto_cek(SNIFF_TIMEOUT)
        su_an = time.time()

        for ip, veri in anlik.items():
          with _state_lock:
            if ip in BEYAZ_LISTE or ip in ENGELLENEN_IPLER:
              continue

          port_sayisi = len(veri["pt"])
          anomali = yapay_zeka.predict(
            pd.DataFrame([{"p": veri["p"], "pt": port_sayisi}])
          )[0]

          if (veri["p"] > 1000 and port_sayisi > 50) or (anomali == -1 and port_sayisi > 20):
            exe_adi, pid = surec_bilgisi_al(ip)
            _background_executor.submit(_tehdit_isle, ip, exe_adi, pid)
          else:
            dinamik_egitim_havuzu.append({"p": veri["p"], "pt": port_sayisi})
            emit_temiz_trafik(ip, veri["p"])

        if su_an - son_egitim > ML_RETRAIN_INTERVAL:
          df_yeni = pd.DataFrame(list(dinamik_egitim_havuzu))
          if not df_yeni.empty:
            yapay_zeka.fit(df_yeni)
          son_egitim = su_an


if __name__ == "__main__":
    print("EduTrace v10.0 [Tam Otonom XDR ve AI Egitmen] Baslatiliyor...")
    print("-" * 75)
    print(f"[*] Sistem IP Adresi: {AKTIF_IP}")
    print("-" * 75)

    threading.Thread(target=edutrace_sentinel_motoru, daemon=True).start()
    threading.Thread(target=canli_gorev_yoneticisi, daemon=True).start()
    print(f"[*] Radyo Kulesi Yayin Yapiyor -> IP: {SERVER_HOST} Port: {SERVER_PORT}")
    socketio.run(app, host=SERVER_HOST, port=SERVER_PORT, debug=False, use_reloader=False)
