import psutil
from scapy.all import sniff, IP, TCP
import pandas as pd
from sklearn.ensemble import IsolationForest
from collections import defaultdict, deque
import time
import threading
import socket
import ipaddress
import requests
import concurrent.futures
from google import genai
from flask import Flask
from flask_socketio import SocketIO, emit
import warnings
warnings.filterwarnings("ignore")

print("EduTrace v10.0 [Tam Otonom XDR ve AI Egitmen] Baslatiliyor...")
print("-" * 75)

app = Flask(__name__)
socketio = SocketIO(app, cors_allowed_origins="*", async_mode='threading', always_connect=True)

# --- 1. DINAMIK AG VE IP TESPITI ---
def aktif_yerel_ip_bul():
    try:
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as s:
            s.connect(("8.8.8.8", 80))
            return s.getsockname()[0]
    except Exception:
        return "127.0.0.1"

def alt_ag_belirle(ip_adresi):
    if ip_adresi == "127.0.0.1":
        return None
    return str(ipaddress.IPv4Interface(f"{ip_adresi}/24").network)

AKTIF_IP = aktif_yerel_ip_bul()
ALT_AG = alt_ag_belirle(AKTIF_IP)

print(f"[*] Sistem IP Adresi: {AKTIF_IP}")
print(f"[*] Hedef Alt Ag: {ALT_AG}")
print("-" * 75)

# --- 2. YAPAY ZEKA EGITMEN MOTORU ---
class EgiticiAsistanMotoru:
    def __init__(self):
        self.api_key = "YOUR_API_KEY_HERE"
        self.client = genai.Client(api_key=self.api_key)
        self.model_adi = "gemini-2.0-flash"
        print(f"[+] AI Egitmen Aktif: {self.model_adi} modeline kilitlendi.")

    def tavsiye_uret(self, uygulama_adi, hedef_ip, vt_skor):
        prompt = f"""
Sen EduTrace adinda, universite ogrencileri icin tasarlanmis egitici bir siber guvenlik asistanisin.
Sistemimiz az once otonom olarak bir tehdidi engelledi.

Engellenen Uygulama: {uygulama_adi}
Tehlikeli IP Adresi: {hedef_ip}
VirusTotal Skoru: {vt_skor}

Lutfen kullanicinin siber guvenlik bilgisini artirmak icin su formata uyarak kisa, net ve anlasilirbir geri bildirim hazirla:
1. [Tehdidin Dogasi]: Bu uygulama/IP nasil bir saldiri gerceklestiriyor olabilir?
2. [Olasi Hasar]: Eger biz bunu engellemeseydik sisteme ne gibi zararlar verebilirdi?
3. [Gelecek Onlemi]: Kullanici bu tur zafiyetlerin tekrar yasanmamasi icin ne gibi onlemler almalidir?
"""
        for deneme in range(3):
            try:
                print(f"[*] Gemini API'ye istek gonderiliyor... (Deneme {deneme+1}/3)")
                with concurrent.futures.ThreadPoolExecutor() as executor:
                    future = executor.submit(
                        self.client.models.generate_content,
                        model=self.model_adi,
                        contents=prompt
                    )
                    response = future.result(timeout=25)
                print("[+] Gemini yanit verdi!")
                return response.text

            except concurrent.futures.TimeoutError:
                print("[!] Gemini timeout!")
                break

            except Exception as e:
                hata = str(e)
                if "429" in hata or "RESOURCE_EXHAUSTED" in hata:
                    bekleme = 30 * (deneme + 1)
                    print(f"[!] Kota asildi. {bekleme} saniye bekleniyor...")
                    time.sleep(bekleme)
                else:
                    print(f"[!] Gemini Hatasi: {type(e).__name__}: {e}")
                    break

        return (
            f"AI Egitmen kota limitine ulasti veya yanit veremedi.\n\n"
            f"Manuel Ozet:\n"
            f"1. [Tehdidin Dogasi]: {hedef_ip} adresinden yogun port taramasi tespit edildi. "
            f"Bu genellikle bir nmap/masscan saldirisinin ilk kesif fazidir.\n"
            f"2. [Olasi Hasar]: Acik portlar tespit edilerek sisteme sizma girisimi yapilabilirdi.\n"
            f"3. [Gelecek Onlemi]: Guvenlik duvarinda gereksiz portlari kapatin, "
            f"fail2ban gibi araclarla otomatik engelleme kurun."
        )


egitici_motor = EgiticiAsistanMotoru()


# --- 3. TEHDIT ISTIHBARAT MOTORU ---
class TehditAnalizMotoru:
    def __init__(self):
        self.vt_api_key = "80c0c2aa6537c53f6936d45b0b08024f4f61b3b2e55830be18ddf249f00f0cf5"
        self.sorgu_gecmisi = {}

    def analiz_et_ve_karar_ver(self, ip_adresi):
        try:
            ip_obj = ipaddress.ip_address(ip_adresi)
            if ip_obj.is_private:
                return {
                    "ip": ip_adresi,
                    "vt_skor": "YEREL AG (N/A)",
                    "otonom_karar": "ENGELLE"
                }
        except ValueError:
            pass

        if ip_adresi in self.sorgu_gecmisi:
            return self.sorgu_gecmisi[ip_adresi]

        url = f"https://www.virustotal.com/api/v3/ip_addresses/{ip_adresi}"
        headers = {"accept": "application/json", "x-apikey": self.vt_api_key}
        try:
            response = requests.get(url, headers=headers, timeout=5)
            if response.status_code == 200:
                veri = response.json()
                zararli_sayisi = veri['data']['attributes']['last_analysis_stats']['malicious']
                otonom_karar = "ENGELLE" if zararli_sayisi > 0 else "IZIN_VER"
                sonuc = {"vt_skor": zararli_sayisi, "otonom_karar": otonom_karar}
                self.sorgu_gecmisi[ip_adresi] = sonuc
                return sonuc
            return {"vt_skor": 0, "otonom_karar": "IZIN_VER"}
        except Exception:
            return {"vt_skor": 0, "otonom_karar": "IZIN_VER"}


tehdit_motoru = TehditAnalizMotoru()

# --- 4. GLOBAL DEGISKENLER VE YAPAY ZEKA MODELI ---
yapay_zeka = IsolationForest(contamination='auto', random_state=42)
dinamik_egitim_havuzu = deque(maxlen=1000)
BEYAZ_LISTE = ["127.0.0.1", "192.168.1.1", AKTIF_IP, "255.255.255.255"]
ENGELLENEN_IPLER = set()

# --- 5. SOKET ILETISIMI ---
@socketio.on('karar_ver')
def karar_uygula(data):
    print("[!] Uyari: Manuel mudahale istegi reddedildi. Sistem Otonom XDR modunda calismaktadir.")

# --- 6. AG ANALIZ FONKSIYONLARI ---
def surec_bilgisi_al(hedef_ip):
    for conn in psutil.net_connections(kind='inet'):
        if conn.raddr and conn.raddr.ip == hedef_ip:
            try:
                p = psutil.Process(conn.pid)
                return p.name(), conn.pid
            except:
                pass
    return "Bilinmeyen Kaynak", None

def ag_ronto_cek(sure):
    paketler = sniff(filter="tcp", timeout=sure)
    stats = defaultdict(lambda: {"p": 0, "pt": set()})
    for pkt in paketler:
        if IP in pkt and TCP in pkt:
            stats[pkt[IP].src]["p"] += 1
            stats[pkt[IP].src]["pt"].add(pkt[TCP].dport)
    return stats

# --- 7. BIRINCI MOTOR: CANLI GOREV YONETICISI ---
def canli_gorev_yoneticisi():
    while True:
        aktif_uygulamalar = []
        gordugum_pidler = set()
        for conn in psutil.net_connections(kind='inet'):
            if conn.status == 'ESTABLISHED' and conn.pid and conn.pid not in gordugum_pidler:
                try:
                    p = psutil.Process(conn.pid)
                    aktif_uygulamalar.append({
                        "ad": p.name(),
                        "pid": p.pid,
                        "ip": conn.raddr.ip if conn.raddr else "Bilinmiyor"
                    })
                    gordugum_pidler.add(conn.pid)
                except:
                    pass
        socketio.emit('aktif_uygulamalar', aktif_uygulamalar)
        time.sleep(3)

# --- 8. IKINCI MOTOR: YAPAY ZEKA VE AG RADARI (XDR) ---
def edutrace_sentinel_motoru():
    print("[*] FAZ 1: Yapay Zeka Agi Ogreniyor (15 Sn)...")
    yapay_zeka.fit(pd.DataFrame([{"p": 10, "pt": 2}]))
    son_egitim = time.time()
    print("[+] SISTEM AKTIF! Otonom XDR Devrede...")

    while True:
        anlik = ag_ronto_cek(3)
        su_an = time.time()
        for ip, veri in anlik.items():
            if ip in BEYAZ_LISTE or ip in ENGELLENEN_IPLER:
                continue

            anomali = yapay_zeka.predict(pd.DataFrame([{"p": veri['p'], "pt": len(veri['pt'])}]))[0]

            if (veri['p'] > 1000 and len(veri['pt']) > 50) or (anomali == -1 and len(veri['pt']) > 20):
                exe_adi, pid = surec_bilgisi_al(ip)
                print(f"\n[!!!] DIKKAT: {ip} anormal trafik yaratiyor. API'ler uzerinden sorgulanıyor...")
                istihbarat_raporu = tehdit_motoru.analiz_et_ve_karar_ver(ip)

                if istihbarat_raporu["otonom_karar"] == "ENGELLE":
                    print(f"[X] OTONOM MUDAHALE: {ip} engelleniyor...")
                    ENGELLENEN_IPLER.add(ip)

                    if pid:
                        try:
                            psutil.Process(int(pid)).terminate()
                            islem_durumu = f"Zararli surec ({exe_adi}) otonom olarak sonlandirildi."
                        except Exception as e:
                            islem_durumu = f"Surece mudahale edilemedi: {e}"
                    else:
                        islem_durumu = f"Dis kaynakli ag saldirisi ({ip}) kaynagi bloklandi."

                    print(f"[*] Egitici Asistan (Gemini) rapor hazirlıyor...")
                    egitici_rapor = egitici_motor.tavsiye_uret(exe_adi, ip, istihbarat_raporu['vt_skor'])

                    socketio.emit('islem_sonucu', {
                        "mesaj": islem_durumu,
                        "durum": "basarili",
                        "egitici_rapor": egitici_rapor
                    })
                else:
                    print(f"[+] API Analizi Sonucu: Yanlis Alarm, {ip} guvenli gorunuyor.")
            else:
                dinamik_egitim_havuzu.append({"p": veri['p'], "pt": len(veri['pt'])})
                socketio.emit('temiz_trafik', {"ip": ip, "paket": veri['p']})

        if su_an - son_egitim > 15:
            df_yeni = pd.DataFrame(list(dinamik_egitim_havuzu))
            if not df_yeni.empty:
                yapay_zeka.fit(df_yeni)
            son_egitim = su_an

# --- 9. BASLATMA ---
if __name__ == '__main__':
    threading.Thread(target=edutrace_sentinel_motoru, daemon=True).start()
    threading.Thread(target=canli_gorev_yoneticisi, daemon=True).start()
    print("[*] Radyo Kulesi Yayin Yapiyor -> IP: 0.0.0.0 Port: 5000")
    socketio.run(app, host='0.0.0.0', port=5000, debug=False, use_reloader=False)