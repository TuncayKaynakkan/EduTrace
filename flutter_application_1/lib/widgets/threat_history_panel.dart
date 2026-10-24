import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/threat_report.dart';
import '../services/language_service.dart';
import '../services/license_service.dart';
import '../services/socket_service.dart';
import '../theme.dart';
import 'common.dart';
import 'threat_report_dialog.dart';

/// Shows threats handled during this session with attack type badges; tapping opens the AI lesson.
class ThreatHistoryPanel extends StatelessWidget {
  /// Creates the threat history panel.
  const ThreatHistoryPanel({super.key, required this.threats});

  /// Handled threats, newest first.
  final List<ThreatReport> threats;

  static String _time(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageService>();

    return SectionCard(
      title: lang.isEnglish ? 'Threat History' : 'Tehdit Geçmişi',
      icon: Icons.shield_outlined,
      accent: AppColors.danger,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: lang.isEnglish ? 'Simulate Threat Attack' : 'Tehdit Simülasyonu Başlat',
            icon: const Icon(Icons.flash_on, size: 16, color: AppColors.accent),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () {
              final isPro = context.read<LicenseService>().isPro;
              context.read<SocketService>().startThreatSimulation(
                    isPro: isPro,
                    isEnglish: lang.isEnglish,
                  );
            },
          ),
          const SizedBox(width: 8),
          Text(
            '${threats.length}',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
        ],
      ),
      child: threats.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    EmptyState(
                      icon: Icons.verified_user_outlined,
                      message: lang.isEnglish
                          ? 'No threats detected yet.\nYour system is secure.'
                          : 'Henüz tehdit tespit edilmedi.\nSisteminiz güvende.',
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: () {
                        final isPro = context.read<LicenseService>().isPro;
                        context.read<SocketService>().startThreatSimulation(
                              isPro: isPro,
                              isEnglish: lang.isEnglish,
                            );
                      },
                      icon: const Icon(Icons.flash_on, size: 14, color: AppColors.accent),
                      label: Text(
                        lang.isEnglish ? 'Simulate Threat Attack' : 'Saldırı Simülasyonu Başlat',
                        style: const TextStyle(fontSize: 12, color: AppColors.accent),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: AppColors.accent.withValues(alpha: 0.35)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 6),
              itemCount: threats.length,
              separatorBuilder: (_, _) => const Divider(height: 1, indent: 18, endIndent: 18),
              itemBuilder: (context, i) {
                final t = threats[i];
                return InkWell(
                  onTap: t.isSuccessful ? () => ThreatReportDialog.show(context, t) : null,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(top: 2),
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.danger.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.gpp_maybe_outlined, size: 18, color: AppColors.danger),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      t.attackType,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.danger,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    _time(t.receivedAt),
                                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                t.message,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
                              ),
                              if (t.description.isNotEmpty) ...[
                                const SizedBox(height: 3),
                                Text(
                                  t.description,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (t.isSuccessful) ...[
                          const SizedBox(width: 8),
                          const Icon(Icons.chevron_right, size: 18, color: AppColors.textSecondary),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
