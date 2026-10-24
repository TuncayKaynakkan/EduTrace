# 🛡️ EduTrace - Real-Time Autonomous XDR & Security Platform

[![Backend Tests](https://github.com/TuncayKaynakkan/EduTrace/actions/workflows/backend-tests.yml/badge.svg)](https://github.com/TuncayKaynakkan/EduTrace/actions/workflows/backend-tests.yml)

EduTrace, ağ üzerindeki tehditleri tespit etmek, cihaz durumlarını ve ağ trafiğini gerçek zamanlı izlemek amacıyla geliştirilmiş AI destekli ve tam otonom bir XDR (Extended Detection and Response) platformudur.

Proje; modern ve sezgisel bir mobil/masaüstü kullanıcı arayüzü ile güçlü bir Python arka plan analiz motorunu bir araya getirir.

---

🚀 Öne Çıkan Özellikler

- Dinamik Ağ ve IP Tespiti: Yerel ağdaki aktif arayüzleri ve IP aralıklarını otomatik belirleme.
- Otonom Ağ Radar Taraması: Ağdaki cihazları ve açık servisleri aktif/pasif tarama teknikleriyle tespit etme.
- Yapay Zekâ Destekli Tehdit Analizi: Anomali tespiti ve paket analizi için entegre AI/ML algoritmaları.
- Gerçek Zamanlı İletişim: Socket.IO protokolü üzerinden ön yüz ile arka plan servisleri arasında anlık veri akışı.
- Modern Dashboard Arayüzü: Koyu tema odaklı, hızlı erişim sağlayan performanslı mobil/masaüstü kontrol paneli.

---

 🛠️ Mimari ve Teknolojiler

Proje iki ana bileşenden oluşmaktadır:

1. Frontend (Mobil & Kullanıcı Arayüzü)
- Framework: Flutter (Dart)
- İletişim: `socket_io_client` ile gerçek zamanlı olay tabanlı dinleme

2. Backend (Analiz & Tehdit Avcılığı Motoru)
- Dil & Kütüphaneler: Python, Flask, Flask-SocketIO
- Ağ Analizi: scapy, Socket, Threading
- Yapay Zekâ & Veri İşleme: Scikit-learn (Isolation Forest), Pandas, Google GenAI SDK

---

⚙️ Nasıl Çalışır?

1. Servis Başlatma: Python motoru (`edutrace_ultimate.py`) çalıştırılır. Motor, ortamdaki aktif ağ arayüzünü otomatik bulur ve dinleme moduna geçer.
2. Bağlantı Kurulumu: Flutter uygulaması açıldığında yerel Socket.IO sunucusuna (`http://127.0.0.1:5000`) motorun ürettiği yetki token'ı ile bağlanır.
3. Veri Akışı & Analiz: Ağ paketleri ve cihaz durumları arka planda işlenir, tespit edilen anomali veya tarama sonuçları anlık olarak Flutter arayüzüne gönderilerek görselleştirilir.

---

🔐 Güvenlik Tasarımı

EduTrace yönetici yetkisiyle çalışıp firewall kuralı ekleyebildiği için motorun kendisi de bir saldırı yüzeyidir. Bu yüzden şu kurallara göre tasarlanmıştır:

- Kimlik doğrulamalı yerel API: Motor her açılışta rastgele bir token üretir ve `%PROGRAMDATA%\EduTrace\auth.token` dosyasına yazar. Dosyayı yalnızca çalıştıran kullanıcı, Administrators ve SYSTEM okuyabilir. Token'ı göndermeyen istemciler reddedilir; token oluşturulamazsa herkes reddedilir (fail closed).
- Kanıtın gücüne göre müdahale: İmza kuralı (SYN flood, XMAS tarama vb.) ve hacim eşiği alarmları doğrudan engellenir. Makine öğrenmesi anomalileri ise yalnızca VirusTotal tarafından doğrulanırsa engellenir; aksi halde kullanıcıya bildirilir ve izlenir.
- Durum takipli (stateful) analiz: Bilgisayarın başlattığı UDP/TCP akışlarının yanıtları (QUIC video, DNS, CDN) saldırı sayılmaz. Yanıt sayılmak için TCP paketinin ACK bayrağı taşıması gerekir; böylece tanıdık bir adresten gelen SYN/NULL/FIN/XMAS taramaları da yakalanır.
- Güvenli firewall kullanımı: Özel, loopback ve multicast adresler engellenemez; `netsh` komutları `shell=False` ile çalışır.
- Koda gömülü sır yok: API anahtarları `.env` dosyasından okunur; geliştirici lisans anahtarı yalnızca debug derlemesinde `--dart-define` ile verilir.

---

🧪 Testler ve CI

Backend testleri her pull request'te GitHub Actions ile Windows üzerinde, Python 3.11 ve 3.13 ile otomatik çalışır. `main` dalı korumalıdır: değişiklikler yalnızca PR ile girebilir ve iki test işi de geçmeden birleştirme yapılamaz.

Yerelde çalıştırmak için:

```bash
cd backend
python -m pip install -r requirements-dev.txt
python -m pytest tests -v
```

| Test dosyası | Kapsam |
|---|---|
| `test_firewall.py` | Özel/geçersiz IP reddi, komut enjeksiyonu denemesi |
| `test_sentinel.py` | Npcap eksikken tespit motorunun çökmemesi |
| `test_threat_rules.py` | UDP/QUIC yanıtları ve gerçek UDP flood |
| `test_threat_rules_tcp.py` | CDN yanıtları, yavaş port taraması, gizli tarama |
| `test_socket_auth.py` | Token'sız/yanlış token'lı bağlantıların reddi |
| `test_tehdit_karari.py` | Alarm kaynağına göre engelleme kararı |

Çalışan bir motora karşı kimlik doğrulamasını elle denemek için: `python tools/yetkisiz_istemci.py` (token'sız → reddedilmeli), `--yanlis` (reddedilmeli), `--dogru` (bağlanmalı).

---

📋 Güvenlik Değişiklik Günlüğü

| PR | Sorun | Tür |
|---|---|---|
| [#2](https://github.com/TuncayKaynakkan/EduTrace/pull/2) | Npcap eksikken tespit motoru sessizce duruyordu | Kararlılık |
| [#2](https://github.com/TuncayKaynakkan/EduTrace/pull/2) | Koda gömülü lisans anahtarları, formata uyan her anahtarın kabulü | Hardcoded credentials |
| [#3](https://github.com/TuncayKaynakkan/EduTrace/pull/3) | QUIC/DNS yanıtlarının UDP flood sayılması | Yanlış alarm |
| [#4](https://github.com/TuncayKaynakkan/EduTrace/pull/4) | Yönetici yetkili motorda kimlik doğrulaması olmaması | CWE-306 |
| [#8](https://github.com/TuncayKaynakkan/EduTrace/pull/8) | CDN yanıtlarının yavaş port taraması sayılması | Yanlış alarm |
| [#9](https://github.com/TuncayKaynakkan/EduTrace/pull/9) | ML anomalilerinin VirusTotal doğrulaması olmadan engellenmesi | Hatalı otomatik müdahale |

Bilinen sınırlar: Lisans kontrolü istemci tarafındadır. Motor açılmadan önce kurulmuş bağlantıların yanıtları ilk 60 saniyede sayılabilir. Ağ üzerinden bağlanan panel (`SERVER_HOST=0.0.0.0`) token dosyasına erişemediği için bağlanamaz.
