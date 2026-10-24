import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/language_service.dart';
import '../services/license_service.dart';
import '../services/socket_service.dart';
import '../theme.dart';
import '../widgets/ai_settings_dialog.dart';
import '../widgets/connection_status_badge.dart';
import '../widgets/language_select_dialog.dart';
import '../widgets/license_dialog.dart';
import '../widgets/process_list_panel.dart';
import '../widgets/stat_card.dart';
import '../widgets/threat_history_panel.dart';
import '../widgets/threat_report_dialog.dart';
import '../widgets/traffic_list_panel.dart';

/// Main command-center screen for the EduTrace dashboard.
class DashboardScreen extends StatefulWidget {
  /// Creates the dashboard screen.
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  SocketService? _socketService;
  bool _isDialogShowing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final socketService = context.read<SocketService>();
      final licenseService = context.read<LicenseService>();
      final languageService = context.read<LanguageService>();
      _socketService = socketService;
      socketService.addListener(_onSocketUpdate);
      socketService.notifyLicenseStatus(licenseService.isPro);
      socketService.emitLanguageChange(languageService.currentLanguage.code);

      licenseService.addListener(() {
        if (mounted) {
          socketService.notifyLicenseStatus(licenseService.isPro);
        }
      });
      languageService.addListener(() {
        if (mounted) {
          socketService.emitLanguageChange(languageService.currentLanguage.code);
        }
      });
      socketService.connect();

      // Ask for language on first launch
      if (languageService.isFirstLaunch) {
        LanguageSelectDialog.show(context, isDismissible: false);
      }
    });
  }

  void _onSocketUpdate() {
    if (!mounted || _socketService == null) {
      return;
    }

    final report = _socketService!.latestThreatReport;
    if (report != null) {
      // Clear immediately to prevent subsequent socket events (clean traffic, process list)
      // from re-triggering this same report.
      _socketService!.clearLatestThreatReport();

      if (report.isSuccessful) {
        if (!_isDialogShowing) {
          _isDialogShowing = true;
          ThreatReportDialog.show(context, report).whenComplete(() {
            if (mounted) {
              setState(() {
                _isDialogShowing = false;
              });
            }
          });
        }
        return;
      }

      if (report.message.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(report.message)),
        );
      }
    }

    final notif = _socketService!.lastNotification;
    if (notif != null) {
      final isHata = notif['durum'] == 'hata';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(notif['mesaj']?.toString() ?? ''),
          backgroundColor: isHata ? AppColors.danger : AppColors.success,
        ),
      );
      _socketService!.clearNotification();
    }
  }

  @override
  void dispose() {
    _socketService?.removeListener(_onSocketUpdate);
    super.dispose();
  }

  static String _compact(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)} Mn';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)} B';
    return '$n';
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SocketService>();
    final lang = context.watch<LanguageService>();
    final threats = s.threatCount;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              _Header(isConnected: s.isConnected),
              const SizedBox(height: 18),
              SizedBox(
                height: 82,
                child: Row(
                  children: [
                    Expanded(
                      child: StatCard(
                        label: lang.text('stat_hosts'),
                        value: '${s.uniqueHostCount}',
                        icon: Icons.devices_other,
                        color: AppColors.accent,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: StatCard(
                        label: lang.text('stat_packets'),
                        value: _compact(s.totalPackets),
                        icon: Icons.swap_vert,
                        color: AppColors.success,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: StatCard(
                        label: lang.text('stat_apps'),
                        value: '${s.activeApps.map((a) => a.name).toSet().length}',
                        icon: Icons.apps,
                        color: AppColors.warning,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: StatCard(
                        label: lang.text('stat_threats'),
                        value: '$threats',
                        icon: Icons.gpp_good_outlined,
                        color: threats == 0 ? AppColors.success : AppColors.danger,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(flex: 5, child: TrafficListPanel(entries: s.trafficEntries)),
                    const SizedBox(width: 18),
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: ProcessListPanel(apps: s.activeApps)),
                          const SizedBox(height: 18),
                          Expanded(child: ThreatHistoryPanel(threats: s.threatHistory)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.isConnected});

  final bool isConnected;

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageService>();

    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.asset(
            'assets/app_logo.png',
            width: 46,
            height: 46,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'EduTrace',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: 0.3),
            ),
            Text(
              lang.text('app_subtitle'),
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
        const Spacer(),
        const _ThreatSimulationButton(),
        const SizedBox(width: 8),
        const _AiSettingsButton(),
        const SizedBox(width: 10),
        const _LanguageButton(),
        const SizedBox(width: 10),
        const _ProBadgeButton(),
        const SizedBox(width: 12),
        ConnectionStatusBadge(isConnected: isConnected),
      ],
    );
  }
}

class _AiSettingsButton extends StatelessWidget {
  const _AiSettingsButton();

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageService>();
    final hasKey = lang.hasCustomGeminiKey;

    return Material(
      color: Colors.transparent,
      child: Tooltip(
        message: lang.isEnglish
            ? (hasKey ? 'Gemini AI: Live API Key Active' : 'Gemini AI Settings & API Key')
            : (hasKey ? 'Gemini AI: Canlı API Anahtarı Aktif' : 'Gemini AI Ayarları & API Anahtarı'),
        child: InkWell(
          onTap: () => AiSettingsDialog.show(context),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6.5),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: hasKey
                    ? AppColors.success.withValues(alpha: 0.5)
                    : AppColors.border,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.auto_awesome,
                  size: 14,
                  color: hasKey ? AppColors.success : AppColors.accent,
                ),
                const SizedBox(width: 5),
                Text(
                  'AI',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: hasKey ? AppColors.success : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ThreatSimulationButton extends StatelessWidget {
  const _ThreatSimulationButton();

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageService>();

    return Material(
      color: Colors.transparent,
      child: Tooltip(
        message: lang.isEnglish
            ? 'Test real-time autonomous defense with a safe simulated probe'
            : 'Güvenli simüle edilmiş saldırıyla otonom savunmayı canlı test edin',
        child: InkWell(
          onTap: () {
            final isPro = context.read<LicenseService>().isPro;
            final isEnglish = lang.isEnglish;
            context.read<SocketService>().startThreatSimulation(
                  isPro: isPro,
                  isEnglish: isEnglish,
                );
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  isEnglish
                      ? 'Simulating reconnaissance probe (Nmap Stealth Scan)...'
                      : 'Tehdit simülasyonu başlatılıyor (Nmap Stealth Scan)...',
                ),
                duration: const Duration(seconds: 2),
                backgroundColor: const Color(0xFF0F172A),
              ),
            );
          },
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6.5),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.accent.withValues(alpha: 0.45)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.flash_on_rounded, size: 15, color: AppColors.accent),
                const SizedBox(width: 5),
                Text(
                  lang.isEnglish ? 'Simulate Threat' : 'Tehdit Simülasyonu',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.accent,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LanguageButton extends StatelessWidget {
  const _LanguageButton();

  @override
  Widget build(BuildContext context) {
    final langService = context.watch<LanguageService>();
    final current = langService.currentLanguage;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => LanguageSelectDialog.show(context),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(current.flag, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
              Text(
                current.name.toUpperCase(),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 2),
              const Icon(Icons.arrow_drop_down, size: 16, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProBadgeButton extends StatelessWidget {
  const _ProBadgeButton();

  @override
  Widget build(BuildContext context) {
    final license = context.watch<LicenseService>();
    final lang = context.watch<LanguageService>();
    final isPro = license.isPro;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => LicenseDialog.show(context),
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            gradient: isPro
                ? const LinearGradient(
                    colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                  )
                : null,
            color: isPro ? null : AppColors.border.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isPro ? const Color(0xFFFDE68A) : Colors.amber.withValues(alpha: 0.6),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: (isPro ? const Color(0xFFF59E0B) : Colors.amber).withValues(alpha: 0.25),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isPro ? Icons.workspace_premium : Icons.star,
                size: 16,
                color: isPro ? Colors.white : Colors.amber.shade400,
              ),
              const SizedBox(width: 6),
              Text(
                isPro ? lang.text('pro_active') : lang.text('upgrade_pro'),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.4,
                  color: isPro ? Colors.white : Colors.amber.shade300,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
