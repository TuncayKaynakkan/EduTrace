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

/// Service managing EduTrace Pro license activation with Polar.
///
/// The panel only activates the key and remembers the activation id; the
/// engine (Pro add-on) does the authoritative check with Polar itself.
class LicenseService extends ChangeNotifier {
  // Public customer-portal endpoints: no secret needed, meant for desktop apps
  static const String _polarActivateUrl =
      'https://api.polar.sh/v1/customer-portal/license-keys/activate';
  static const String _polarValidateUrl =
      'https://api.polar.sh/v1/customer-portal/license-keys/validate';

  /// EduTrace's Polar organization; keys from any other seller are refused.
  static const String polarOrganizationId = 'a844738a-2521-4133-8ab0-3b24cf221ee7';

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

  /// Polar activation id of this machine.
  String? get instanceId => _instanceId;

  /// Masked license key for display in settings (e.g. "EDUPRO-****-****-2026").
  String get maskedLicenseKey {
    if (_licenseKey == null || _licenseKey!.length < 8) return '—';
    // Polar keys start with "EDUPRO-"; keep that prefix without doubling the dash
    final start = _licenseKey!.substring(0, 7).replaceAll(RegExp(r'-+$'), '');
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

  /// Attempts to activate a license key via the Polar API or offline developer validation.
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

      // 2. Activate this computer with Polar
      final instanceName = Platform.localHostname;
      final response = await http.post(
        Uri.parse(_polarActivateUrl),
        headers: {'Accept': 'application/json', 'Content-Type': 'application/json'},
        body: jsonEncode({
          'key': cleanKey,
          'organization_id': polarOrganizationId,
          'label': instanceName,
        }),
      ).timeout(const Duration(seconds: 12));

      final decoded = response.body.isEmpty ? null : jsonDecode(response.body);
      final body = decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
      final licenseKeyData = body['license_key'] as Map<String, dynamic>?;

      if (response.statusCode == 200 && body['id'] != null && licenseKeyData?['status'] == 'granted') {
        _isPro = true;
        _licenseKey = cleanKey;
        _instanceId = body['id'].toString();
        _customerName = null;
        _customerEmail = null;
        final expiresStr = licenseKeyData?['expires_at']?.toString();
        _expiresAt = expiresStr == null ? null : DateTime.tryParse(expiresStr);

        // The activation answer has no customer details; validate fills them in
        await _validateInBackground();
        _saveLicense();
        _isLoading = false;
        notifyListeners();

        return ActivationResult(
          success: _isPro,
          message: _isPro
              ? 'Tebrikler! EduTrace PRO lisansınız başarıyla doğrulandı.'
              : 'Lisans etkinleştirildi ama doğrulanamadı. Lütfen tekrar deneyin.',
          customerName: _customerName,
          customerEmail: _customerEmail,
        );
      }

      _isLoading = false;
      notifyListeners();
      return ActivationResult(
        success: false,
        message: _activationError(response.statusCode, body),
      );
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

  /// Turns a Polar error answer into a message the user can act on.
  static String _activationError(int status, Map<String, dynamic> body) {
    final detail = body['detail'];
    if (status == 403) {
      return 'Bu lisans izin verilen bilgisayar sayısına ulaştı. '
          'Eski bir bilgisayardaki etkinleştirmeyi Polar müşteri portalından kaldırın.';
    }
    if (status == 404) {
      return 'Lisans anahtarı bulunamadı veya iptal edilmiş.';
    }
    if (detail is String && detail.isNotEmpty) {
      return 'Lisans etkinleştirilemedi: $detail';
    }
    return 'Lisans etkinleştirilemedi (HTTP $status).';
  }

  Future<void> _validateInBackground() async {
    if (_licenseKey == null || _instanceId == null) return;
    try {
      final response = await http.post(
        Uri.parse(_polarValidateUrl),
        headers: {'Accept': 'application/json', 'Content-Type': 'application/json'},
        body: jsonEncode({
          'key': _licenseKey!,
          'organization_id': polarOrganizationId,
          'activation_id': _instanceId!,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 404 || response.statusCode == 422) {
        // Refunded, revoked, expired, or this activation was removed
        _isPro = false;
        _saveLicense();
        notifyListeners();
        return;
      }
      if (response.statusCode != 200) {
        return; // Server trouble is not a verdict on the key
      }
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (body['status'] != 'granted' || body['organization_id'] != polarOrganizationId) {
        _isPro = false;
      } else {
        final customer = body['customer'] as Map<String, dynamic>?;
        _customerName = customer?['name']?.toString() ?? _customerName;
        _customerEmail = customer?['email']?.toString() ?? _customerEmail;
      }
      _saveLicense();
      notifyListeners();
    } catch (_) {
      // In case of transient network loss, don't immediately revoke cached license
    }
  }
}
