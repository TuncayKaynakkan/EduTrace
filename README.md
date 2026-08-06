# EduTrace XDR

[![Python](https://img.shields.io/badge/Python-3.10%2B-blue)](backend/)
[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B)](flutter_application_1/)
[![License](https://img.shields.io/badge/License-MIT-green)](#lisans--license)

> **Otonom ag tehdit tespiti + yapay zeka destekli siber guvenlik egitimi**  
> **Autonomous network threat detection + AI-powered cybersecurity education**

---

## Turkce

### Proje Hakkinda

**EduTrace**, universite ogrencileri ve siber guvenlik meraklilari icin tasarlanmis acik kaynak bir **XDR (Extended Detection & Response)** platformudur. Gercek zamanli ag trafigini analiz eder, anomalileri makine ogrenmesi ile tespit eder, tehditleri VirusTotal uzerinden dogrular ve engellenen saldirilar hakkinda **Gemini AI** ile egitici raporlar uretir.

### Cozdugu Problem

Geleneksel guvenlik duvarlari tehditleri engeller ancak kullaniciya **neden** engellendigini ogretmez. EduTrace bu boslugu kapatir:

- Gercek zamanli ag izleme — Scapy ile TCP paket yakalama
- ML tabanli anomali tespiti — IsolationForest ile port tarama / DDoS kaliplari
- Tehdit istihbarati — VirusTotal API entegrasyonu
- AI egitmen — Gemini ile Turkce siber guvenlik dersleri
- Canli dashboard — Flutter ile gercek zamanli gorsellestirme

### Mimari

```
Flutter Dashboard (Network Discovery -> Socket.IO -> UI)
                           |
                    WebSocket (port 5000)
                           |
Python XDR Backend (Scapy -> IsolationForest -> VirusTotal -> Gemini)
```

### Proje Yapisi

```
EduTrace/
├── backend/
│   ├── edutrace_ultimate.py
│   ├── requirements.txt
│   └── .env.example
├── flutter_application_1/
│   └── lib/
│       ├── main.dart
│       ├── models/
│       ├── services/
│       ├── screens/
│       └── widgets/
└── README.md
```

### Kurulum

#### Gereksinimler

- Python 3.10+
- Flutter 3.x SDK
- Yonetici/root yetkisi (Scapy paket yakalama icin)
- Gemini API anahtari
- VirusTotal API anahtari

#### Backend (Python)

```bash
cd backend
python -m venv .venv
.venv\Scripts\activate          # Windows
pip install -r requirements.txt
copy .env.example .env          # Windows
python edutrace_ultimate.py
```

#### Frontend (Flutter)

```bash
cd flutter_application_1
flutter pub get
flutter run
```

### Socket.IO Olaylari

| Olay | Yon | Payload | Aciklama |
|------|-----|---------|----------|
| `temiz_trafik` | Python -> Flutter | `{ip, paket}` | Normal ag trafigi |
| `aktif_uygulamalar` | Python -> Flutter | `[{ad, pid, ip}]` | Aktif surecler |
| `islem_sonucu` | Python -> Flutter | `{mesaj, durum, egitici_rapor}` | Tehdit engellendi |
| `karar_ver` | Flutter -> Python | — | Otonom modda reddedilir |

### Yasal Uyari

Bu arac **yalnizca kendi aginizda** veya **yazili izniniz olan sistemlerde** kullanilmalidir.

---

## English

### About

**EduTrace** is an open-source **XDR (Extended Detection & Response)** platform for students and cybersecurity enthusiasts. It analyzes real-time network traffic, detects anomalies with machine learning, validates threats via VirusTotal, and generates educational reports with **Gemini AI**.

### Problem It Solves

Traditional firewalls block threats but do not teach users **why** something was blocked. EduTrace bridges that gap with live monitoring, ML anomaly detection, threat intelligence, and AI-generated lessons.

### Setup

#### Backend (Python)

```bash
cd backend
python -m venv .venv
source .venv/bin/activate       # macOS / Linux
pip install -r requirements.txt
cp .env.example .env
python edutrace_ultimate.py
```

#### Frontend (Flutter)

```bash
cd flutter_application_1
flutter pub get
flutter run
```

The Flutter app auto-discovers the Python backend on port **5000**.

### Socket.IO Events

| Event | Direction | Payload | Description |
|-------|-----------|---------|-------------|
| `temiz_trafik` | Python -> Flutter | `{ip, paket}` | Normal network traffic |
| `aktif_uygulamalar` | Python -> Flutter | `[{ad, pid, ip}]` | Active processes |
| `islem_sonucu` | Python -> Flutter | `{mesaj, durum, egitici_rapor}` | Threat blocked |
| `karar_ver` | Flutter -> Python | — | Rejected in autonomous mode |

### Legal Notice

Use this tool **only** on **your own network** or systems where you have **written permission**.

---

## Lisans / License

MIT License
