import 'dart:io';
import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

void main() {
  runApp(const EduTraceApp());
}

class EduTraceApp extends StatelessWidget {
  const EduTraceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'EduTrace XDR',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0D1117),
        appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF161B22), elevation: 2),
      ),
      home: const DashboardScreen(),
    );
  }
}

class DashboardScreen extends StatefulWidget {
 const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late io.Socket socket;
  List<Map<String, dynamic>> agTrafikListesi = [];
  List<dynamic> aktifUygulamalar = [];
  bool baglandiMi = false;

  @override
  void initState() {
    super.initState();
    _pythonBaglantisiKur();
  }

 void _pythonBaglantisiKur() async {
    debugPrint('[*] Ağ Radar Taraması Başlatılıyor... Python Motoru Aranıyor!');
    List<String> subnets = [];

    // 1. ADIM: Bilgisayardaki TÜM aktif ağları (Wi-Fi, Ethernet, Sanal Ağlar) topla
    for (var interface in await NetworkInterface.list()) {
      for (var addr in interface.addresses) {
        if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
          String ip = addr.address;
          String subnet = ip.substring(0, ip.lastIndexOf('.'));
          
          // Aynı alt ağı tekrar eklememek için kontrol
          if (!subnets.contains(subnet)) {
            subnets.add(subnet);
            debugPrint('[*] Hedef Alt Ağ Radara Eklendi: $subnet.0/24 (${interface.name})');
          }
        }
      }
    }

    if (subnets.isEmpty) {
      debugPrint('[!] HATA: Aktif bir ağ bulunamadı. Wi-Fi bağlantınızı kontrol edin.');
      return;
    }

    // 2. ADIM: Bulunan tüm alt ağlara 5000 portu için eşzamanlı "Sweep (Süpürme)" at
    bool sunucuBulundu = false;
    
    for (String subnet in subnets) {
      if (sunucuBulundu) break;
      
      for (int i = 1; i < 255; i++) {
        if (sunucuBulundu) break; 
        
        String hedefIp = '$subnet.$i';
        
        // Timeout 150ms. Asenkron olduğu için yüzlerce port taraması saniyeler içinde biter.
        Socket.connect(hedefIp, 5000, timeout: const Duration(milliseconds: 150)).then((s) {
          s.destroy(); 
          if (!sunucuBulundu) {
            sunucuBulundu = true;
            debugPrint("[+] HEDEF KİLİTLENDİ! Python XDR Motoru Bulundu -> http://$hedefIp:5000");
            _soketMotorunuBaslat("http://$hedefIp:5000"); 
          }
        }).catchError((error) {
          // Port kapalıysa sessizce atla (Ping sweep mantığı)
        });
      }
    }
  }
  
  void _soketMotorunuBaslat(String dinamikUrl) {
    socket = io.io(dinamikUrl, io.OptionBuilder()
        .setTransports(['websocket'])
        .enableAutoConnect()
        .build());

    socket.onConnect((_) {
      if (mounted) setState(() => baglandiMi = true);
      debugPrint('[+] XDR Motoru ile Otonom Bağlantı Kuruldu!');
    });

    socket.onDisconnect((_) {
      if (mounted) setState(() => baglandiMi = false);
    });

    socket.on('temiz_trafik', (data) {
      if (mounted) {
        setState(() {
          agTrafikListesi.insert(0, {"ip": data['ip'], "paket": data['paket']});
          if (agTrafikListesi.length > 20) agTrafikListesi.removeLast();
        });
      }
    });

    socket.on('aktif_uygulamalar', (data) {
      if (mounted) setState(() => aktifUygulamalar = data);
    });

    // Otonom Motor İşlemi Bitirdiğinde Raporu Ekrana Basar
    socket.on('islem_sonucu', (data) {
      if (data['durum'] == 'basarili' && data['egitici_rapor'] != null) {
        _egitimPaneliniGoster(data);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['mesaj']), backgroundColor: Colors.red),
        );
      }
    });
  }

  void _egitimPaneliniGoster(Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0D1117),
        shape: RoundedRectangleBorder(
            side: const BorderSide(color: Colors.greenAccent, width: 2), 
            borderRadius: BorderRadius.circular(12)
        ),
        title: const Row(
          children: [
            Icon(Icons.shield, color: Colors.greenAccent, size: 32),
            SizedBox(width: 10),
            Text("SİSTEM GÜVENDE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(data['mesaj'], style: const TextStyle(color: Colors.greenAccent, fontSize: 16, fontWeight: FontWeight.bold)),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12.0),
                child: Divider(color: Colors.white24, thickness: 1),
              ),
              const Text("🤖 EduTrace AI Analiz Raporu:", style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 10),
              Text(data['egitici_rapor'], style: const TextStyle(color: Colors.white70, height: 1.5)),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green[800]),
            onPressed: () => Navigator.pop(context),
            child: const Text("Dersi Tamamla ve Kapat", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("EduTrace XDR - Komuta Merkezi", style: TextStyle(color: Colors.cyanAccent)),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Row(
                children: [
                  Icon(baglandiMi ? Icons.link : Icons.link_off, 
                       color: baglandiMi ? Colors.greenAccent : Colors.redAccent),
                  const SizedBox(width: 8),
                  Text(baglandiMi ? "MOTOR AKTİF" : "BAĞLANTI BEKLENİYOR",
                      style: TextStyle(color: baglandiMi ? Colors.greenAccent : Colors.redAccent)),
                ],
              ),
            ),
          )
        ],
      ),
      body: Row(
        children: [
          Expanded(
            flex: 3,
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("🌐 CANLI AĞ RADARI", style: TextStyle(color: Colors.cyanAccent, fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF161B22),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.3)),
                      ),
                      child: ListView.builder(
                        itemCount: agTrafikListesi.length,
                        itemBuilder: (context, index) {
                          final item = agTrafikListesi[index];
                          return ListTile(
                            leading: const Icon(Icons.radar, color: Colors.cyan),
                            title: Text(item['ip'].toString()),
                            trailing: Text("${item['paket']} Paket", style: const TextStyle(color: Colors.grey)),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.all(16),
              color: const Color(0xFF161B22).withValues(alpha: 0.5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("⚙️ AĞA BAĞLI SÜREÇLER", style: TextStyle(color: Colors.orangeAccent, fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      itemCount: aktifUygulamalar.length,
                      itemBuilder: (context, index) {
                        final app = aktifUygulamalar[index];
                        return Card(
                          color: const Color(0xFF0D1117),
                          shape: RoundedRectangleBorder(
                           side: BorderSide(color: Colors.orangeAccent.withValues(alpha: 0.2)),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: ListTile(
                            leading: const Icon(Icons.memory, color: Colors.orangeAccent),
                            title: Text(app['ad'].toString(), style: const TextStyle(fontSize: 14)),
                            subtitle: Text("PID: ${app['pid']}", style: const TextStyle(fontSize: 12)),
                          ),
                        );
                      },
                    ),
                  )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  @override
  void dispose() {
    socket.disconnect();
    socket.dispose();
    super.dispose();
  }
}