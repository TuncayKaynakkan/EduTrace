import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../models/active_app.dart';
import '../models/threat_report.dart';
import '../models/traffic_entry.dart';
import 'network_discovery_service.dart';

/// Manages Socket.IO communication with the EduTrace Python backend.
class SocketService extends ChangeNotifier {
  SocketService({NetworkDiscoveryService? discoveryService})
      : _discoveryService = discoveryService ?? NetworkDiscoveryService();

  final NetworkDiscoveryService _discoveryService;
  io.Socket? _socket;
  bool _isConnecting = false;

  static const int _maxTrafficEntries = 20;

  bool _isConnected = false;
  final List<TrafficEntry> _trafficEntries = [];
  final List<ActiveApp> _activeApps = [];
  ThreatReport? _latestThreatReport;

  /// Whether the dashboard is connected to the backend.
  bool get isConnected => _isConnected;

  /// Latest clean-traffic observations for the radar panel.
  List<TrafficEntry> get trafficEntries => List.unmodifiable(_trafficEntries);

  /// Active network processes reported by the backend.
  List<ActiveApp> get activeApps => List.unmodifiable(_activeApps);

  /// Most recent threat report, if any.
  ThreatReport? get latestThreatReport => _latestThreatReport;

  /// Starts subnet discovery and connects to the first available backend.
  Future<void> connect() async {
    if (_isConnecting || _isConnected) {
      return;
    }

    _isConnecting = true;
    debugPrint('[*] Python XDR motoru araniyor...');

    final backendUrl = await _discoveryService.discoverBackendUrl();
    _isConnecting = false;

    if (backendUrl == null) {
      debugPrint('[!] Backend bulunamadi. Wi-Fi baglantinizi kontrol edin.');
      notifyListeners();
      return;
    }

    debugPrint('[+] Backend bulundu: $backendUrl');
    _startSocket(backendUrl);
  }

  void _startSocket(String backendUrl) {
    _socket?.dispose();

    final socket = io.io(
      backendUrl,
      io.OptionBuilder().setTransports(['websocket']).enableAutoConnect().build(),
    );
    _socket = socket;

    socket.onConnect((_) {
      _isConnected = true;
      notifyListeners();
      debugPrint('[+] XDR motoru ile baglanti kuruldu.');
    });

    socket.onDisconnect((_) {
      _isConnected = false;
      notifyListeners();
    });

    socket.on('temiz_trafik', (data) {
      if (data is! Map) {
        return;
      }

      _trafficEntries.insert(
        0,
        TrafficEntry.fromJson(Map<String, dynamic>.from(data)),
      );
      if (_trafficEntries.length > _maxTrafficEntries) {
        _trafficEntries.removeLast();
      }
      notifyListeners();
    });

    socket.on('aktif_uygulamalar', (data) {
      if (data is! List) {
        return;
      }

      _activeApps
        ..clear()
        ..addAll(
          data.map(
            (item) => ActiveApp.fromJson(Map<String, dynamic>.from(item as Map)),
          ),
        );
      notifyListeners();
    });

    socket.on('islem_sonucu', (data) {
      if (data is! Map) {
        return;
      }

      _latestThreatReport = ThreatReport.fromJson(Map<String, dynamic>.from(data));
      notifyListeners();
    });
  }

  /// Clears the latest threat report after it has been shown to the user.
  void clearLatestThreatReport() {
    _latestThreatReport = null;
  }

  @override
  void dispose() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    super.dispose();
  }
}
