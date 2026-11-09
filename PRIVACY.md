# EduTrace Gizlilik ve Aydınlatma Metni

Son güncelleme: 3 Kasım 2026 · Sürüm 1.2.0 · [English summary below](#english-summary)

Bu metin, EduTrace'in hangi verileri işlediğini, nerede sakladığını ve hangi durumlarda bilgisayarınızdan dışarı gönderdiğini anlatır. 6698 sayılı Kişisel Verilerin Korunması Kanunu (KVKK) kapsamında IP adresleri ve e-posta adresleri kişisel veri sayılabilir.

## Özet

- EduTrace ağ trafiğinizi **bilgisayarınızın içinde** analiz eder. Paketler, trafik kayıtları ve alarm geçmişi geliştiriciye gönderilmez.
- EduTrace'te kullanım istatistiği, reklam veya izleme (telemetri) yoktur.
- Veri yalnızca aşağıdaki "Dışarı giden veriler" bölümündeki durumlarda bilgisayarınızdan çıkar. Bunların çoğu sizin açmanız gereken isteğe bağlı özelliklerdir.

## Bilgisayarınızda tutulan veriler

| Veri | Yer | Süre |
|---|---|---|
| Alarm geçmişi: saldırgan IP, saldırı türü, alınan önlem | `%PROGRAMDATA%\EduTrace\olaylar.db` | 30 gün, sonra otomatik silinir |
| EduTrace'in engellediği IP'ler | `%PROGRAMDATA%\EduTrace\engellenenler.json` | Engel kaldırılana kadar |
| Motor günlüğü (IP adresleri içerebilir) | `%PROGRAMDATA%\EduTrace\engine.log` | Siz silene kadar |
| Gemini API anahtarı, Telegram token'ı, SMTP şifresi | `%PROGRAMDATA%\EduTrace\gizli.json`, `pro_ayarlar.json` | Siz silene kadar |
| Lisans bilgisi: anahtar, müşteri adı, e-posta | `%APPDATA%\EduTrace\license.json` | Lisansı kaldırana kadar |

Gizli anahtarlar Windows DPAPI ile şifrelenir; bu dosyalar başka bir kullanıcıda veya bilgisayarda çözülemez. `%PROGRAMDATA%\EduTrace` klasörüne yalnızca yöneticiler yazabilir. Gizli dosyaları yalnızca Administrators ve SYSTEM okuyabilir.

## Dışarı giden veriler

### 1. Tehdit listeleri (her zaman açık)
EduTrace 12 saatte bir, bilinen kötü amaçlı IP listelerini [Spamhaus](https://www.spamhaus.org/) ve [abuse.ch Feodo Tracker](https://feodotracker.abuse.ch/) sitelerinden **indirir**. IP kontrolü bilgisayarınızda yapılır; bağlandığınız adresler bu servislere gönderilmez. Her indirmede olduğu gibi, bu servisler sizin genel IP adresinizi görür.

### 2. Gemini AI eğitim raporu (isteğe bağlı, kendi API anahtarınızla)
Panelden bir Gemini API anahtarı girerseniz, her alarmda şu bilgiler Google'a gönderilir: saldırı türü, saldırgan IP adresi, ilgili sürecin (programın) adı ve tehdit listesi eşleşmesi. Anahtar girmezseniz rapor bilgisayarınızda hazır şablondan üretilir ve hiçbir şey gönderilmez.

**Önemli:** Google'ın [Gemini API ek koşullarına](https://ai.google.dev/gemini-api/terms) göre, ücretsiz kullanımda gönderilen içerik Google ürünlerini geliştirmek için kullanılabilir ve insan değerlendiriciler tarafından okunabilir. Google ücretsiz katmana kişisel veri gönderilmemesini önerir. Bunu istemiyorsanız ya Gemini anahtarı eklemeyin ya da faturalandırması açık (ücretli) bir Google Cloud projesinin anahtarını kullanın.

### 3. Lisans doğrulama (yalnızca Pro lisansı girerseniz)
Lisans anahtarı ve etkinleştirme kimliği [Polar](https://polar.sh/legal/privacy)'a gönderilir. Etkinleştirme sırasında bilgisayarınızın adı da gönderilir (aynı lisansın hangi bilgisayarlarda kullanıldığını görebilmeniz için). Doğrulama 12 saatte bir tekrarlanır.

### 4. Alarm bildirimleri (Pro, yalnızca siz ayarlarsanız)
Telegram veya e-posta bildirimini açarsanız, alarmlar (saldırı türü, IP adresi, alınan önlem) [Telegram](https://telegram.org/privacy) sunucularına veya girdiğiniz e-posta (SMTP) sunucusuna gönderilir.

### 5. Satın alma
Pro satın alırken ödeme ve fatura bilgilerinizi (ad, e-posta, ödeme yöntemi) satıcı (merchant of record) olarak Polar işler. Kart bilgileriniz geliştiriciye ulaşmaz. Geliştirici, Polar panelinde satışı yapmak ve destek vermek için gereken bilgileri (ad, e-posta, sipariş, lisans) görür.

## Yurt dışına aktarım

Google, Polar ve Telegram'ın sunucuları Türkiye dışında olabilir. Bu servisleri kullanan özellikleri (Gemini anahtarı, Pro lisans, bildirim) açtığınızda ilgili veri bu servislere aktarılır. Bu özellikler isteğe bağlıdır ve istediğiniz zaman kapatılabilir.

## Veri sorumlusu ve haklarınız

Veri sorumlusu EduTrace geliştiricisi Tuncay Kaynakkan'dır. Bilgisayarınızda tutulan verileri ilgili dosyaları silerek istediğiniz zaman silebilirsiniz. EduTrace'i kaldırmak programı siler ama `%PROGRAMDATA%\EduTrace` ve `%APPDATA%\EduTrace` klasörlerini (geçmiş, ayarlar, lisans) bırakır. Tüm veriyi silmek için kaldırdıktan sonra bu iki klasörü de silin; ilki yönetici izni ister.

KVKK'nın 11. maddesi kapsamındaki haklarınız (verinizin işlenip işlenmediğini öğrenme, düzeltme, silme, itiraz vb.) ve gizlilikle ilgili sorularınız için **kaynakkantun@gmail.com** adresine e-posta gönderebilirsiniz. Kişisel veri içeren talepleri herkese açık olan GitHub Issues yerine e-postayla iletin. Satın alma verileriniz için Polar'a da başvurabilirsiniz.

Bu metin değişirse güncel hali bu sayfada yayınlanır.

---

## English summary

- EduTrace analyses your network traffic **on your computer**. Packets, traffic records and alert history are never sent to the developer. There is no telemetry, analytics or advertising.
- Stored locally: alert history (30 days), blocked IPs, the engine log, DPAPI-encrypted secrets, and license details. Only administrators can write the `%PROGRAMDATA%\EduTrace` folder.
- Leaves your computer only when:
  1. Threat lists are **downloaded** from Spamhaus and abuse.ch every 12 hours. Your connections are never sent.
  2. You add your own Gemini API key. Each alert then sends the attack type, attacker IP, process name and threat-list match to Google. Under Google's [Gemini API terms](https://ai.google.dev/gemini-api/terms), unpaid-tier content may be used to improve Google products and may be read by human reviewers. Use a billing-enabled key or no key if that is not acceptable.
  3. You activate Pro. The license key, activation id and computer name go to Polar, which re-checks the license every 12 hours. Polar is the merchant of record for purchases.
  4. You enable Pro alerts. The attack type, IP and action taken go to Telegram or your SMTP server.
- Data controller: Tuncay Kaynakkan. Contact: kaynakkantun@gmail.com (please do not post personal data in public GitHub issues).
