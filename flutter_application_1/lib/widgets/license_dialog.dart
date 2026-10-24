import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/language_service.dart';
import '../services/license_service.dart';
import '../theme.dart';
import 'ai_settings_dialog.dart';

/// Modal dialog for activating, purchasing, and managing EduTrace PRO licenses.
class LicenseDialog extends StatefulWidget {
  /// Lemon Squeezy product store URL
  static const String storeCheckoutUrl =
      'https://edutrace.lemonsqueezy.com/checkout/buy/ade0fc83-f990-4985-a675-b69ca8a67109';

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

  void _openStore() {
    try {
      if (Platform.isWindows) {
        Process.run('cmd', ['/c', 'start', LicenseDialog.storeCheckoutUrl]);
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
                                  ? 'All autonomous defense and AI features unlocked.'
                                  : 'Tüm otonom savunma ve yapay zeka özellikleri aktif.')
                              : (lang.isEnglish
                                  ? 'Advanced threat defense & unlimited AI incident coaching.'
                                  : 'Gelişmiş saldırı koruması ve sınırsız AI eğitmeni.'),
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
                      icon: Icons.auto_awesome,
                      title: lang.isEnglish
                          ? 'Unlimited Gemini AI Threat Analysis'
                          : 'Sınırsız Gemini AI Siber Savunma Analizi',
                      subtitle: lang.isEnglish
                          ? 'Deeply explains attack techniques and mitigation strategies in clear language.'
                          : 'Saldırıların tekniğini ve savunma stratejisini detaylı açıklar.',
                      isUnlocked: isPro,
                      action: InkWell(
                        onTap: () => AiSettingsDialog.show(context),
                        borderRadius: BorderRadius.circular(6),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.key, size: 12, color: AppColors.accent),
                              const SizedBox(width: 5),
                              Text(
                                lang.hasCustomGeminiKey
                                    ? (lang.isEnglish ? 'Personal API Key Active (Change)' : 'Özel API Anahtarı Aktif (Değiştir)')
                                    : (lang.isEnglish ? 'Configure Gemini AI Key' : 'Gemini API Anahtarı Ekle / Yapılandır'),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.accent,
                                  fontWeight: FontWeight.w600,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const Divider(color: AppColors.border, height: 16),
                    _FeatureRow(
                      icon: Icons.shield,
                      title: lang.isEnglish
                          ? 'Autonomous Active Defense'
                          : 'Otonom Savunma (Active Defense)',
                      subtitle: lang.isEnglish
                          ? 'Instantly intercepts attacker IPs and malicious processes with zero latency.'
                          : 'Saldırgan IP adresini ve zararlı süreçleri sıfır gecikmeyle engeller.',
                      isUnlocked: isPro,
                    ),
                    const Divider(color: AppColors.border, height: 16),
                    _FeatureRow(
                      icon: Icons.radar,
                      title: lang.isEnglish ? 'Deep Attack Signatures' : 'Derin Saldırı İmzaları',
                      subtitle: lang.isEnglish
                          ? 'Nmap Stealth (NULL/FIN/XMAS), Slow Scan, and Brute-Force detection.'
                          : 'Nmap Stealth (NULL/FIN/XMAS), Slow Scan ve Brute-Force algılama.',
                      isUnlocked: isPro,
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
                    hintText: 'EDUPRO-XXXX-XXXX-XXXX',
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
  final Widget? action;

  const _FeatureRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isUnlocked,
    this.action,
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
              if (action != null) ...[
                const SizedBox(height: 4),
                action!,
              ],
            ],
          ),
        ),
      ],
    );
  }
}
