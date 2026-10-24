import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Result of a license activation attempt.
class ActivationResult {
  final bool success;
  final String message;
  final String? customerName;
  final String? customerEmail;

  const ActivationResult({
    required this.success,
    required this.message,
    this.customerName,
    this.customerEmail,
  });
}

/// Service managing EduTrace Pro license validation and Lemon Squeezy integration.
class LicenseService extends ChangeNotifier {
  static const String _lemonSqueezyActivateUrl =
      'https://api.lemonsqueezy.com/v1/licenses/activate';
  static const String _lemonSqueezyValidateUrl =
      'https://api.lemonsqueezy.com/v1/licenses/validate';

  // Offline developer key, only honoured in debug builds and never stored in
  // the source: flutter run --dart-define=EDUTRACE_DEV_KEY=<your-key>
  static const String _devKey = String.fromEnvironment('EDUTRACE_DEV_KEY');
  static const String _devInstanceId = 'dev-instance-offline';

  bool _isPro = false;
  String? _licenseKey;
  String? _instanceId;
  String? _customerName;
  String? _customerEmail;
  DateTime? _expiresAt;
  bool _isLoading = false;

  /// Whether EduTrace PRO features are currently unlocked.
  bool get isPro => _isPro;

  /// The active license key (partially masked for display).
  String? get licenseKey => _licenseKey;

  /// Masked license key for display in settings (e.g. "EDUPRO-****-****-2026").
  String get maskedLicenseKey {
    if (_licenseKey == null || _licenseKey!.length < 8) return '—';
    final start = _licenseKey!.substring(0, 7);
    final end = _licenseKey!.substring(_licenseKey!.length - 4);
    return '$start-****-****-$end';
  }

  /// Registered customer name if available.
  String? get customerName => _customerName;

  /// Registered customer email if available.
  String? get customerEmail => _customerEmail;

  /// Expiry date (null = lifetime).
  DateTime? get expiresAt => _expiresAt;

  /// Whether an activation/validation request is currently pending.
  bool get isLoading => _isLoading;

  LicenseService() {
    _loadSavedLicense();
  }

  File _getLicenseFile() {
    final appData = Platform.environment['APPDATA'] ??
        Platform.environment['LOCALAPPDATA'] ??
        Platform.environment['USERPROFILE'] ??
        '.';
    final dir = Directory('$appData\\EduTrace');
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return File('${dir.path}\\license.json');
  }

  void _loadSavedLicense() {
    try {
      final file = _getLicenseFile();
      if (!file.existsSync()) return;

      final content = file.readAsStringSync();
      final data = jsonDecode(content) as Map<String, dynamic>;

      _isPro = data['is_pro'] == true;
      _licenseKey = data['license_key'] as String?;
      _instanceId = data['instance_id'] as String?;
      _customerName = data['customer_name'] as String?;
      _customerEmail = data['customer_email'] as String?;
      if (data['expires_at'] != null) {
        _expiresAt = DateTime.tryParse(data['expires_at'].toString());
      }
      // Drop offline activations saved by older builds that accepted public dev keys
      if (_instanceId == _devInstanceId &&
          (_licenseKey == null || !_isDevKey(_licenseKey!))) {
        _isPro = false;
      }
      notifyListeners();

      // Background validation if a real key is present
      if (_isPro && _licenseKey != null && !_isDevKey(_licenseKey!)) {
        _validateInBackground();
      }
    } catch (e) {
      debugPrint('[LicenseService] Saved license read error: $e');
    }
  }

  void _saveLicense() {
    try {
      final file = _getLicenseFile();
      final data = {
        'is_pro': _isPro,
        'license_key': _licenseKey,
        'instance_id': _instanceId,
        'customer_name': _customerName,
        'customer_email': _customerEmail,
        'expires_at': _expiresAt?.toIso8601String(),
        'saved_at': DateTime.now().toIso8601String(),
      };
      file.writeAsStringSync(jsonEncode(data), flush: true);
    } catch (e) {
      debugPrint('[LicenseService] License save error: $e');
    }
  }

  static bool _isDevKey(String key) {
    if (!kDebugMode || _devKey.isEmpty) return false;
    return key.trim().toUpperCase() == _devKey.trim().toUpperCase();
  }

  /// Attempts to activate a license key via Lemon Squeezy API or offline developer validation.
  Future<ActivationResult> activateLicense(String key) async {
    final cleanKey = key.trim();
    if (cleanKey.isEmpty) {
      return const ActivationResult(
        success: false,
        message: 'Lütfen geçerli bir lisans anahtarı girin.',
      );
    }

    _isLoading = true;
    notifyListeners();

    try {
      // 1. Check for Developer / VIP Offline Test Keys
      if (_isDevKey(cleanKey)) {
        _isPro = true;
        _licenseKey = cleanKey.toUpperCase();
        _customerName = 'EduTrace Pro Geliştirici / VIP';
        _customerEmail = 'pro@edutrace.local';
        _instanceId = _devInstanceId;
        _expiresAt = null; // Lifetime
        _saveLicense();
        _isLoading = false;
        notifyListeners();
        return const ActivationResult(
          success: true,
          message: 'EduTrace PRO lisansı başarıyla etkinleştirildi! Tüm profesyonel özelliklerin kilidi açıldı.',
          customerName: 'EduTrace VIP',
        );
      }

      // 2. Query Lemon Squeezy License API
      final instanceName = Platform.localHostname;
      final response = await http.post(
        Uri.parse(_lemonSqueezyActivateUrl),
        headers: {'Accept': 'application/json'},
        body: {
          'license_key': cleanKey,
          'instance_name': instanceName,
        },
      ).timeout(const Duration(seconds: 12));

      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && body['activated'] == true) {
        final licenseKeyData = body['license_key'] as Map<String, dynamic>?;
        final meta = body['meta'] as Map<String, dynamic>?;
        final instance = body['instance'] as Map<String, dynamic>?;

        _isPro = true;
        _licenseKey = cleanKey;
        _instanceId = instance?['id']?.toString() ?? 'instance-$instanceName';
        _customerName = meta?['customer_name']?.toString() ?? 'EduTrace Müşterisi';
        _customerEmail = meta?['customer_email']?.toString() ?? '';

        final expiresStr = licenseKeyData?['expires_at']?.toString();
        if (expiresStr != null) {
          _expiresAt = DateTime.tryParse(expiresStr);
        }

        _saveLicense();
        _isLoading = false;
        notifyListeners();

        return ActivationResult(
          success: true,
          message: 'Tebrikler! EduTrace PRO lisansınız başarıyla doğrulandı.',
          customerName: _customerName,
          customerEmail: _customerEmail,
        );
      } else {
        final errorMsg = body['error']?.toString() ??
            'Lisans anahtarı geçersiz veya kullanım limitine ulaşılmış.';
        _isLoading = false;
        notifyListeners();
        return ActivationResult(
          success: false,
          message: errorMsg,
        );
      }
    } on SocketException {
      _isLoading = false;
      notifyListeners();
      return const ActivationResult(
        success: false,
        message: 'İnternet bağlantısı kurulamadı. Lütfen ağ bağlantınızı kontrol edin.',
      );
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return ActivationResult(
        success: false,
        message: 'Aktivasyon sırasında bir hata oluştu: $e',
      );
    }
  }

  /// Deactivates current license and reverts back to Free plan.
  Future<void> deactivateLicense() async {
    _isPro = false;
    _licenseKey = null;
    _instanceId = null;
    _customerName = null;
    _customerEmail = null;
    _expiresAt = null;

    try {
      final file = _getLicenseFile();
      if (file.existsSync()) {
        file.deleteSync();
      }
    } catch (e) {
      debugPrint('[LicenseService] License delete error: $e');
    }

    notifyListeners();
  }

  Future<void> _validateInBackground() async {
    if (_licenseKey == null || _instanceId == null) return;
    try {
      final response = await http.post(
        Uri.parse(_lemonSqueezyValidateUrl),
        headers: {'Accept': 'application/json'},
        body: {
          'license_key': _licenseKey!,
          'instance_id': _instanceId!,
        },
      ).timeout(const Duration(seconds: 10));

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200 && body['valid'] == false) {
        // License was refunded or revoked
        _isPro = false;
        _saveLicense();
        notifyListeners();
      }
    } catch (_) {
      // In case of transient network loss, don't immediately revoke cached license
    }
  }
}
