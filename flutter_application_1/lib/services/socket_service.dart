import 'dart:async';
import 'dart:io';

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

  /// Name of the scheduled task that runs the engine elevated and hidden.
  static const String engineTaskName = 'EduTraceEngine';

  final NetworkDiscoveryService _discoveryService;
  io.Socket? _socket;
  bool _isConnecting = false;
  bool _disposed = false;
  bool _engineStartAttempted = false;
  Timer? _retryTimer;
  static const Duration _retryDelay = Duration(seconds: 3);

  static const int _maxTrafficEntries = 40;
  static const int _maxThreatHistory = 50;

  bool _isConnected = false;
  final Map<String, TrafficEntry> _trafficByIp = {};
  final List<ActiveApp> _activeApps = [];
  final List<ThreatReport> _threatHistory = [];
  ThreatReport? _latestThreatReport;
  int _totalPackets = 0;

  /// Whether the dashboard is connected to the backend.
  bool get isConnected => _isConnected;

  /// Unique remote hosts, most recently seen first.
  List<TrafficEntry> get trafficEntries {
    final list = _trafficByIp.values.toList()
      ..sort((a, b) => b.lastSeen.compareTo(a.lastSeen));
    return List.unmodifiable(list);
  }

  /// Active network processes reported by the backend.
  List<ActiveApp> get activeApps => List.unmodifiable(_activeApps);

  /// All threats handled during this session, newest first.
  List<ThreatReport> get threatHistory => List.unmodifiable(_threatHistory);

  /// Most recent threat report, if any.
  ThreatReport? get latestThreatReport => _latestThreatReport;

  /// Total number of packets observed this session.
  int get totalPackets => _totalPackets;

  /// Number of threats handled this session.
  int get threatCount => _threatHistory.length;

  /// Number of distinct remote hosts seen this session.
  int get uniqueHostCount => _trafficByIp.length;

  /// Starts subnet discovery and connects to the first available backend.
  ///
  /// If no backend is found, tries to start the installed engine once and
  /// then retries every few seconds until one appears.
  Process? _engineProcess;

  /// Tests if local backend is responding on port 5000.
  Future<String?> _checkLocalBackend() async {
    try {
      final s = await Socket.connect(
        '127.0.0.1',
        5000,
        timeout: const Duration(milliseconds: 350),
      );
      await s.close();
      return 'http://127.0.0.1:5000';
    } catch (_) {
      return null;
    }
  }

  /// Connects to the backend engine. Automatically launches the local engine
  /// if it is not already running.
  Future<void> connect() async {
    if (_isConnecting || _isConnected || _disposed) {
      return;
    }

    _isConnecting = true;

    // 1. Check if backend is already listening locally
    var backendUrl = await _checkLocalBackend();

    // 2. If not running locally, start the engine immediately!
    if (backendUrl == null && Platform.isWindows) {
      await _tryStartEngine();
      // Poll every 250ms for up to 4 seconds for backend to be ready
      for (var i = 0; i < 16; i++) {
        if (_disposed) break;
        await Future.delayed(const Duration(milliseconds: 250));
        backendUrl = await _checkLocalBackend();
        if (backendUrl != null) break;
      }
    }

    // 3. Fallback to subnet discovery if still not found
    backendUrl ??= await _discoveryService.discoverBackendUrl();
    _isConnecting = false;

    if (_disposed) {
      return;
    }

    if (backendUrl == null) {
      notifyListeners();
      _retryTimer?.cancel();
      _retryTimer = Timer(_retryDelay, connect);
      return;
    }

    _startSocket(backendUrl);
  }

  /// Locates and launches EduTraceEngine.exe in the background.
  Future<void> _tryStartEngine() async {
    if (_engineStartAttempted || !Platform.isWindows) {
      return;
    }
    _engineStartAttempted = true;

    try {
      final appDir = File(Platform.resolvedExecutable).parent;
      final candidates = [
        // Installed layout: <appDir>\..\engine\EduTraceEngine.exe
        File('${appDir.parent.path}\\engine\\EduTraceEngine.exe'),
        // Dev build layout: <project>\installer\build\EduTraceEngine\EduTraceEngine.exe
        File('${appDir.parent.parent.parent.parent.path}\\installer\\build\\EduTraceEngine\\EduTraceEngine.exe'),
        // Same folder:
        File('${appDir.path}\\EduTraceEngine.exe'),
      ];

      for (final engineExe in candidates) {
        if (engineExe.existsSync()) {
          _engineProcess = await Process.start(
            engineExe.path,
            [],
            mode: ProcessStartMode.detached,
          );
          return;
        }
      }

      // Development python script fallback
      final pyScript = File('${appDir.parent.parent.parent.parent.path}\\backend\\edutrace_ultimate.py');
      if (pyScript.existsSync()) {
        _engineProcess = await Process.start(
          'python',
          [pyScript.path],
          mode: ProcessStartMode.detached,
        );
        return;
      }

      // Try scheduled task as fallback
      await Process.run('schtasks', ['/run', '/tn', engineTaskName]);
    } catch (_) {
      // Best effort
    }
  }

  /// Reads the per-run secret the engine writes to %PROGRAMDATA%\EduTrace\auth.token.
  ///
  /// Read on every (re)connect because the engine creates a new token each start.
  static String _readAuthToken() {
    try {
      final root = Platform.environment['PROGRAMDATA'] ??
          Platform.environment['HOME'] ??
          '.';
      final sep = Platform.pathSeparator;
      final file = File('$root${sep}EduTrace${sep}auth.token');
      return file.existsSync() ? file.readAsStringSync().trim() : '';
    } catch (e) {
      debugPrint('[SocketService] Auth token read error: $e');
      return '';
    }
  }

  void _startSocket(String backendUrl) {
    _socket?.dispose();

    final socket = io.io(
      backendUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuthFn((callback) => callback({'token': _readAuthToken()}))
          .enableAutoConnect()
          .build(),
    );
    _socket = socket;

    socket.onConnect((_) {
      _isConnected = true;
      if (_lastProStatus) {
        _socket?.emit('lisans_durumu', {'is_pro': true});
      }
      if (_lastLangCode != null) {
        _socket?.emit('dil_degistir', {'dil': _lastLangCode});
      }
      notifyListeners();
    });

    socket.onDisconnect((_) {
      _isConnected = false;
      notifyListeners();
    });

    socket.on('temiz_trafik', (data) {
      if (data is! Map) {
        return;
      }

      final entry = TrafficEntry.fromJson(Map<String, dynamic>.from(data));
      final existing = _trafficByIp[entry.ip];
      _trafficByIp[entry.ip] = existing == null ? entry : existing.merge(entry);
      _totalPackets += entry.packetCount;

      if (_trafficByIp.length > _maxTrafficEntries) {
        final oldest = trafficEntries.last;
        _trafficByIp.remove(oldest.ip);
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

      final report = ThreatReport.fromJson(Map<String, dynamic>.from(data));
      _latestThreatReport = report;
      _threatHistory.insert(0, report);
      if (_threatHistory.length > _maxThreatHistory) {
        _threatHistory.removeLast();
      }
      notifyListeners();
    });

    socket.on('islem_bildirimi', (data) {
      if (data is! Map) {
        return;
      }
      _lastNotification = Map<String, dynamic>.from(data);
      notifyListeners();
    });
  }

  Map<String, dynamic>? _lastNotification;

  /// Last user notification from manual actions (terminate process, block IP).
  Map<String, dynamic>? get lastNotification => _lastNotification;

  /// Clears notification after displaying it.
  void clearNotification() {
    _lastNotification = null;
  }

  /// Sends request to terminate process(es) by PID.
  void terminateProcess(String appName, List<int> pids) {
    if (_socket != null && _isConnected) {
      _socket!.emit('surec_sonlandir', {'ad': appName, 'pids': pids});
    }
  }

  /// Sends request to block an IP address on Windows Firewall.
  void blockIp(String ip) {
    if (_socket != null && _isConnected) {
      _socket!.emit('ip_engelle', {'ip': ip});
    }
  }

  bool _lastProStatus = false;
  String? _lastLangCode;

  /// Notifies the backend engine about current Pro license status.
  void notifyLicenseStatus(bool isPro) {
    _lastProStatus = isPro;
    if (_socket != null && _isConnected) {
      _socket!.emit('lisans_durumu', {'is_pro': isPro});
    }
  }

  /// Notifies backend engine about interface language preference.
  void emitLanguageChange(String langCode) {
    _lastLangCode = langCode;
    if (_socket != null && _isConnected) {
      _socket!.emit('dil_degistir', {'dil': langCode});
    }
  }

  /// Triggers a safe educational threat simulation on the backend.
  /// If the backend is offline or delayed, smoothly presents the local educational simulation.
  void startThreatSimulation({
    String tip = 'nmap_stealth',
    bool isPro = false,
    bool isEnglish = false,
  }) {
    if (_socket != null && _isConnected) {
      _socket!.emit('simulasyon_baslat', {'tip': tip});
    }

    final hadExistingReport = _latestThreatReport != null;

    // Fallback timer: if backend does not emit islem_sonucu within 1.2s, or immediately if offline:
    Timer(Duration(milliseconds: _isConnected ? 1200 : 500), () {
      if (_disposed) return;
      if (!hadExistingReport && _latestThreatReport != null) {
        // Backend answered in time!
        return;
      }

      const simIp = '203.0.113.42';
      final attackType = isEnglish
          ? 'Nmap Stealth Scan (SYN/FIN Probe)'
          : 'Gizli Ağ Taraması (Nmap Stealth Scan)';
      final description = isEnglish
          ? 'Security Simulation: Detected covert port probe from $simIp attempting to map open services.'
          : 'Güvenlik Simülasyonu: $simIp adresinden açık portları tespit etmeye çalışan gizli TCP bayrak kombinasyonları yakalandı.';
      final message = isEnglish
          ? (isPro
              ? '[PRO SHIELD] Autonomous active defense isolated $simIp and intercepted suspicious reconnaissance.'
              : 'Security threat intercepted ($simIp). Threat: $attackType.')
          : (isPro
              ? '[PRO KALKAN] Otonom savunma devreye girdi; $simIp adresi izole edildi ve saldırı engellendi.'
              : 'Dış kaynaklı saldırı engellendi ($simIp). Tehdit: $attackType.');

      final educationalReport = isEnglish
          ? '''EduTrace Autonomous Incident Report:

1. [Attack Diagnostics]: Detected '$attackType' pattern originating from $simIp targeting local ports.
2. [Potential Impact]: Covert reconnaissance scans attempt to discover unpatched services, vulnerable listeners, and open ports without completing the standard 3-way TCP handshake.
3. [Prevention Strategy]: Restrict unused inbound ports, configure stateful firewall rules to drop abnormal TCP flag combinations (SYN+FIN / NULL scans), and enforce rate limiting.'''
          : '''EduTrace Otonom Olay Raporu:

1. [Saldırı Teşhisi]: $simIp adresinden gelen '$attackType' kalıbı yakalandı. Saldırgan standart 3 yönlü el sıkışmayı (3-way handshake) tamamlamadan açık portları tespit etmeyi amaçlıyor.
2. [Olası Hasar]: Bu gizli taramalar log kayıtlarında iz bırakmadan sistemdeki zafiyetli servisleri haritalandırıp hedefli sızma girişimlerine zemin hazırlar.
3. [Gelecek Önlemi]: Kullanılmayan tüm portları güvenlik duvarında kapatın, anormal TCP bayrak kombinasyonlarını (SYN+FIN / NULL) otomatik düşüren kurallar uygulayın ve IDS/IPS aktif tutun.''';

      // Insert simulated traffic entry so radar & traffic table show the attacker
      final simEntry = TrafficEntry(ip: simIp, packetCount: 1420);
      final existing = _trafficByIp[simIp];
      _trafficByIp[simIp] = existing == null ? simEntry : existing.merge(simEntry);
      _totalPackets += 1420;

      final report = ThreatReport(
        message: message,
        status: 'basarili',
        attackType: attackType,
        description: description,
        educationalReport: educationalReport,
      );

      _latestThreatReport = report;
      _threatHistory.insert(0, report);
      if (_threatHistory.length > _maxThreatHistory) {
        _threatHistory.removeLast();
      }
      notifyListeners();
    });
  }

  /// Sends updated Gemini API key to the backend engine.
  void updateGeminiApiKey(String apiKey) {
    if (_socket != null && _isConnected) {
      _socket!.emit('gemini_key_guncelle', {'api_key': apiKey});
    }
  }

  /// Clears the latest threat report after it has been shown to the user.
  void clearLatestThreatReport() {
    _latestThreatReport = null;
  }

  @override
  void dispose() {
    _disposed = true;
    _retryTimer?.cancel();
    _engineProcess?.kill();
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    super.dispose();
  }
}
