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

⭐ Ücretsiz ve Pro

| Özellik | Ücretsiz | Pro |
|---|---|---|
| Canlı trafik analizi, imza kuralları, ML anomali tespiti | ✓ | ✓ |
| Çevrimdışı tehdit listeleri, AI eğitim raporu | ✓ | ✓ |
| Manuel IP engelleme ve engeli geri alma | ✓ | ✓ |
| Alarm geçmişi | Son 24 saat | 30 gün |
| CSV / PDF rapor | | ✓ |
| Telegram ve e-posta alarm bildirimi | | ✓ |
| Otomatik firewall engelleme ve süreç sonlandırma, beyaz liste | | ✓ |
| Özel kural editörü (eşikler ve port kuralları) | | ✓ |

EduTrace open-core olarak geliştirilir: motor ve panel bu depoda MIT lisansıyla açıktır, Pro özellikleri ise kurulum dosyasına eklenen kapalı kaynak bir eklentidir. Motor eklentiyi `pro_kancalari.py` arayüzü üzerinden çağırır; eklenti yoksa ücretsiz sürüm olarak çalışır.

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
- Kanıtın gücüne göre müdahale: İmza kuralı (SYN flood, XMAS tarama vb.) ve hacim eşiği alarmları doğrudan müdahale kararına gider. Makine öğrenmesi anomalilerinde ise müdahale yalnızca IP bir tehdit listesinde yer alıyorsa yapılır; aksi halde kullanıcıya bildirilir ve izlenir.
- Çevrimdışı tehdit istihbaratı: Spamhaus DROP (IPv4/IPv6) ve abuse.ch Feodo Tracker listeleri 12 saatte bir indirilir ve kontrol bilgisayarın içinde yapılır; bağlanılan IP adresleri hiçbir servise gönderilmez, API anahtarı gerekmez.
- IPv4 ve IPv6 kapsamı: Trafik her iki protokolde de analiz edilir. Bilgisayarın tüm adresleri (geçici ve link-local IPv6 adresleri dahil) dakikada bir yenilenir; komşu keşfi (NDP) gibi ICMPv6 kontrol mesajları ping sayılmaz.
- Durum takipli (stateful) analiz: Bilgisayarın başlattığı UDP/TCP akışlarının yanıtları (QUIC video, DNS, CDN) saldırı sayılmaz. Yanıt sayılmak için TCP paketinin ACK bayrağı taşıması gerekir; böylece tanıdık bir adresten gelen SYN/NULL/FIN/XMAS taramaları da yakalanır.
- Güvenli firewall kullanımı: Otomatik engelleme ve süreç sonlandırma varsayılan olarak kapalıdır; motor önce uyarır, Pro kullanıcı isterse panelden açar. Her engel panelden geri alınabilir (ücretsiz). Özel, loopback ve multicast adresler engellenemez; `netsh` komutları `shell=False` ile çalışır.
- Lisans motor tarafında doğrulanır: Panel motora "Pro'yum" diyemez; yalnızca lisans anahtarını iletir. Motor anahtarı Lemon Squeezy'ye kendisi sorar ve anahtarın EduTrace mağazasına ait olduğunu kontrol eder.
- Yalnızca yerel bağlantı: Panel sadece aynı bilgisayardaki motora (`127.0.0.1`) bağlanır; yerel ağı taramaz ve token'ı başka bir cihaza göndermez.
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
| `test_ipv6.py` | IPv6 tarama tespiti, QUIC yanıtları, NDP, yerel adresler, IPv6 firewall |

Çalışan bir motora karşı kimlik doğrulamasını elle denemek için: `python tools/yetkisiz_istemci.py` (token'sız → reddedilmeli), `--yanlis` (reddedilmeli), `--dogru` (bağlanmalı).

---

🔬 Canlı Test (25 Ekim 2026)

Birim testlerine ek olarak motor ve panel gerçek bir Windows 11 bilgisayarında, IPv6 destekli bir ev internet bağlantısında (Wi-Fi) birlikte çalıştırıldı. Test boyunca `FIREWALL_BLOCK=false` ve `AUTO_TERMINATE=false` kullanıldı; hiçbir IP engellenmedi, hiçbir süreç kapatılmadı.

Yöntem:
1. Motor başlatıldı, panel kendi token'ıyla bağlandı; `tools/yetkisiz_istemci.py` ile yetkisiz bağlantılar denendi.
2. Aynı bilgisayarda YouTube'da bir video oynatılırken 90 saniye boyunca motorun bildirdiği trafik, yetkili bir Socket.IO istemcisiyle kaydedildi.
3. Motorun gördüğü trafik, Wi-Fi kartının bayt sayacıyla karşılaştırıldı ("alarm yok" sonucunun "görmüyorum" anlamına gelmediğini doğrulamak için).

Bulgular:

| Kontrol | Sonuç |
|---|---|
| Token'sız / yanlış token'lı bağlantı | Reddedildi, motor logunda kayıt var |
| Panelin token ile bağlanması | Başarılı |
| Paket yakalama kapsamı | Wi-Fi'a gelen baytların ~%100'ü yakalandı; trafiğin **%94'ü IPv6** |
| IPv6 analizi | İlk testte **hiç yoktu** (kör nokta), [#11](https://github.com/TuncayKaynakkan/EduTrace/pull/11) ile eklendi |

IPv6 desteği öncesi ve sonrası, aynı video ve aynı 90 saniyelik ölçüm:

| | Önce | Sonra |
|---|---|---|
| Motorun gördüğü IPv6 sunucu | 0 | 28 |
| Motorun gördüğü IPv6 paket | 0 | 8.187 |
| YouTube QUIC sunucusundan (UDP/443) paket | görünmüyordu | 7.577 (~5.000/dk) |
| Yanlış alarm | 0 (trafiği görmediği için) | 0 (gördü, yanıt olarak doğru sınıflandırdı) |

YouTube'un dakikada ~5.000 paketi, eski UDP flood eşiğinin (dakikada 300) 16 katından fazladır. Durum takipli analiz ([#3](https://github.com/TuncayKaynakkan/EduTrace/pull/3), [#8](https://github.com/TuncayKaynakkan/EduTrace/pull/8)) bu trafiği bilgisayarın kendi açtığı bağlantıların yanıtı olarak tanıdı ve alarm üretmedi.

Sınırlar: Test tek bir bilgisayarda ve tek bir ağda yapıldı. Gerçek bir saldırı trafiği (ör. başka bir cihazdan `hping3`) canlı olarak denenmedi; saldırı tespiti birim testleri ve simülasyonlarla doğrulanmıştır.

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
| [#11](https://github.com/TuncayKaynakkan/EduTrace/pull/11) | IPv6 trafiğin hiç analiz edilmemesi (canlı testte trafiğin %94'ü) | Görünürlük boşluğu |
| [#13](https://github.com/TuncayKaynakkan/EduTrace/pull/13) | Bağlanılan IP'lerin VirusTotal'a gönderilmesi; ücretsiz API'nin ticari kullanım yasağı | Gizlilik / lisans uyumu |

Bilinen sınırlar: Lisans kontrolü istemci tarafındadır. Motor açılmadan önce kurulmuş bağlantıların yanıtları ilk 60 saniyede sayılabilir. Panel başka bir bilgisayardaki motora bağlanamaz (uzaktan izleme desteklenmiyor). Tehdit listeleri yalnızca bilinen kötü altyapıyı kapsar; listede olmayan bir saldırgan yalnızca davranış kurallarıyla yakalanır.

---

📚 Veri Kaynakları ve Teşekkür

- [Spamhaus DROP](https://www.spamhaus.org/blocklists/do-not-route-or-peer/) listeleri © The Spamhaus Project SLU; [kullanım şartları](https://www.spamhaus.org/drop/terms/). Dosyalar değiştirilmeden saklanır, tarih ve telif bilgisi korunur.
- [abuse.ch Feodo Tracker](https://feodotracker.abuse.ch/) verileri CC0 kapsamında; [kullanım şartları](https://abuse.ch/terms-of-use/).
