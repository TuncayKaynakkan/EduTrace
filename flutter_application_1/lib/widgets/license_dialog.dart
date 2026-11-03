import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/language_service.dart';
import '../services/license_service.dart';
import '../theme.dart';

/// Modal dialog for activating, purchasing, and managing EduTrace PRO licenses.
class LicenseDialog extends StatefulWidget {
  /// Lemon Squeezy product store URL
  static const String storeCheckoutUrl =
      'https://edutrace.lemonsqueezy.com/checkout/buy/ade0fc83-f990-4985-a675-b69ca8a67109';

  /// Privacy notice (KVKK): what leaves the computer and why
  static const String privacyUrl = 'https://github.com/TuncayKaynakkan/EduTrace/blob/main/PRIVACY.md';

  const LicenseDialog({super.key});

  /// Displays the license modal.
  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => const LicenseDialog(),
    );
  }

  @override
  State<LicenseDialog> createState() => _LicenseDialogState();
}

class _LicenseDialogState extends State<LicenseDialog> {
  late final TextEditingController _keyController;
  String? _statusError;
  String? _statusSuccess;

  @override
  void initState() {
    super.initState();
    _keyController = TextEditingController();
  }

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  void _openStore() => _openUrl(LicenseDialog.storeCheckoutUrl);

  void _openUrl(String url) {
    try {
      if (Platform.isWindows) {
        Process.run('cmd', ['/c', 'start', url]);
      }
    } catch (e) {
      debugPrint('Browser open error: $e');
    }
  }

  Future<void> _handleActivate() async {
    final licenseService = context.read<LicenseService>();
    final lang = context.read<LanguageService>();
    setState(() {
      _statusError = null;
      _statusSuccess = null;
    });

    final result = await licenseService.activateLicense(_keyController.text);
    if (!mounted) return;

    if (result.success) {
      setState(() {
        _statusSuccess = lang.isEnglish
            ? 'Congratulations! EduTrace PRO license verified successfully.'
            : result.message;
      });
    } else {
      setState(() {
        _statusError = lang.isEnglish
            ? (_keyController.text.trim().isEmpty
                ? 'Please enter a valid license key.'
                : 'Invalid license key or activation limit reached.')
            : result.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final license = context.watch<LicenseService>();
    final lang = context.watch<LanguageService>();
    final isPro = license.isPro;

    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isPro ? Colors.amber.withValues(alpha: 0.5) : AppColors.border,
        ),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Bar with Icon and Title
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isPro
                            ? [Colors.amber.shade400, Colors.deepOrange.shade400]
                            : [AppColors.accent, AppColors.accent.withValues(alpha: 0.7)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isPro ? Icons.workspace_premium : Icons.security_outlined,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'EduTrace PRO',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: isPro ? Colors.amber.shade300 : Colors.white,
                                  ),
                            ),
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: isPro
                                    ? Colors.amber.withValues(alpha: 0.2)
                                    : AppColors.border,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: isPro
                                      ? Colors.amber.withValues(alpha: 0.6)
                                      : AppColors.textSecondary,
                                ),
                              ),
                              child: Text(
                                isPro
                                    ? (lang.isEnglish ? 'ACTIVE LICENSE' : 'AKTİF LİSANS')
                                    : (lang.isEnglish ? 'FREE PLAN' : 'ÜCRETSİZ PLAN'),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: isPro ? Colors.amber.shade200 : AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isPro
                              ? (lang.isEnglish
                                  ? 'Pro features are active. Open their settings with the ⚙ icon next to PRO.'
                                  : 'Pro özellikleri aktif. Ayarları PRO yanındaki ⚙ simgesinden açabilirsin.')
                              : (lang.isEnglish
                                  ? 'Alerts on your phone, 30-day history, auto response and custom rules.'
                                  : 'Telefona alarm, 30 gün geçmiş, otomatik müdahale ve özel kurallar.'),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.textSecondary),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Pro Features Highlights Grid
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.background.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    _FeatureRow(
                      icon: Icons.notifications_active_outlined,
                      title: lang.isEnglish ? 'Telegram & E-mail Alerts' : 'Telegram ve E-posta Bildirimi',
                      subtitle: lang.isEnglish
                          ? 'Get told about an attack even when you are away from the computer.'
                          : 'Bilgisayar başında değilken de saldırı haberi telefonuna veya e-postana gelir.',
                      isUnlocked: isPro,
                    ),
                    const Divider(color: AppColors.border, height: 16),
                    _FeatureRow(
                      icon: Icons.history,
                      title: lang.isEnglish ? '30-Day History & CSV/PDF Reports' : '30 Gün Geçmiş ve CSV/PDF Rapor',
                      subtitle: lang.isEnglish
                          ? 'The free plan shows the last 24 hours; Pro keeps 30 days and exports reports.'
                          : 'Ücretsiz plan son 24 saati gösterir; Pro 30 günü saklar ve rapor çıkarır.',
                      isUnlocked: isPro,
                    ),
                    const Divider(color: AppColors.border, height: 16),
                    _FeatureRow(
                      icon: Icons.shield_outlined,
                      title: lang.isEnglish ? 'Automatic Response (opt-in)' : 'Otomatik Müdahale (isteğe bağlı)',
                      subtitle: lang.isEnglish
                          ? 'When you turn it on, attacker IPs are blocked in Windows Firewall and the process '
                              'behind an attack is stopped. Whitelist exceptions; every block can be undone.'
                          : "Açarsan saldırgan IP Windows Güvenlik Duvarı'nda engellenir, saldırıya aracılık eden "
                              'süreç durdurulur. Beyaz listeyle istisna tanımlanır; her engel geri alınabilir.',
                      isUnlocked: isPro,
                    ),
                    const Divider(color: AppColors.border, height: 16),
                    _FeatureRow(
                      icon: Icons.tune,
                      title: lang.isEnglish ? 'Custom Rule Editor' : 'Özel Kural Editörü',
                      subtitle: lang.isEnglish
                          ? 'Tune detection thresholds and write your own port rules.'
                          : 'Algılama eşiklerini ayarla, kendi port kurallarını yaz.',
                      isUnlocked: isPro,
                    ),
                    const Divider(color: AppColors.border, height: 16),
                    Text(
                      lang.isEnglish
                          ? 'Live detection, attack signatures, threat lists and AI lessons are free for everyone.'
                          : 'Canlı tespit, saldırı imzaları, tehdit listeleri ve AI eğitim raporu herkes için ücretsiz.',
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: () => _openUrl(LicenseDialog.privacyUrl),
                      child: Text(
                        lang.isEnglish ? 'Privacy notice' : 'Gizlilik ve aydınlatma metni (KVKK)',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.accent,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              if (isPro) ...[
                // Active License Info
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.verified, color: Colors.amber, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            (license.customerName != null &&
                                    license.customerName!.contains('Geliştirici'))
                                ? (lang.isEnglish
                                    ? 'EduTrace PRO Developer / VIP'
                                    : license.customerName!)
                                : (license.customerName ??
                                    (lang.isEnglish
                                        ? 'EduTrace PRO Owner'
                                        : 'EduTrace PRO Sahibi')),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        lang.isEnglish
                            ? 'License Key: ${license.maskedLicenseKey}'
                            : 'Lisans Anahtarı: ${license.maskedLicenseKey}',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () {
                        license.deactivateLicense();
                        setState(() {
                          _statusSuccess = lang.isEnglish
                              ? 'License removed. Reverted to free tier.'
                              : 'Lisans kaldırıldı. Ücretsiz plana geçildi.';
                        });
                      },
                      icon: const Icon(Icons.link_off, size: 16, color: AppColors.danger),
                      label: Text(
                        lang.isEnglish ? 'Remove License' : 'Lisansı Kaldır',
                        style: const TextStyle(color: AppColors.danger, fontSize: 12),
                      ),
                    ),
                    const Spacer(),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.amber.shade700,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        lang.isEnglish ? 'Done' : 'Tamam',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                // License Key Input Field
                TextField(
                  controller: _keyController,
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'monospace'),
                  decoration: InputDecoration(
                    labelText: lang.isEnglish ? 'License Key' : 'Lisans Anahtarı',
                    labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    hintText: 'XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX',
                    hintStyle: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    filled: true,
                    fillColor: AppColors.background,
                    prefixIcon: const Icon(Icons.key, color: AppColors.accent, size: 18),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
                    ),
                  ),
                ),

                if (_statusError != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _statusError!,
                    style: const TextStyle(color: AppColors.danger, fontSize: 12),
                  ),
                ],
                if (_statusSuccess != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _statusSuccess!,
                    style: const TextStyle(color: AppColors.success, fontSize: 12),
                  ),
                ],

                const SizedBox(height: 16),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: _openStore,
                      icon: const Icon(Icons.shopping_bag_outlined, size: 16),
                      label: Text(lang.isEnglish ? 'Purchase License' : 'Lisans Satın Al'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: AppColors.border),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                    const Spacer(),
                    FilledButton.icon(
                      onPressed: license.isLoading ? null : _handleActivate,
                      icon: license.isLoading
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                            )
                          : const Icon(Icons.check, size: 16),
                      label: Text(
                        license.isLoading
                            ? (lang.isEnglish ? 'Verifying...' : 'Doğrulanıyor...')
                            : (lang.isEnglish ? 'Activate' : 'Etkinleştir'),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isUnlocked;

  const _FeatureRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isUnlocked,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 18,
          color: isUnlocked ? Colors.amber : AppColors.accent,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    isUnlocked ? Icons.check_circle : Icons.lock_outline,
                    size: 14,
                    color: isUnlocked ? Colors.amber : AppColors.textSecondary,
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
