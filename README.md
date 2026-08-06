# 🛡️ EduTrace - Real-Time Autonomous XDR & Security Platform

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
2. Bağlantı Kurulumu: Flutter uygulaması açıldığında yerel Socket.IO sunucusuna otomatik bağlanır (`http://192.168.x.x:5000`).
3. Veri Akışı & Analiz: Ağ paketleri ve cihaz durumları arka planda işlenir, tespit edilen anomali veya tarama sonuçları anlık olarak Flutter arayüzüne gönderilerek görselleştirilir.
