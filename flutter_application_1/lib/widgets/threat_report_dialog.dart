import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/threat_report.dart';
import '../services/language_service.dart';
import '../services/license_service.dart';
import '../theme.dart';
import 'license_dialog.dart';

/// Shows the educational report generated after a threat is blocked.
class ThreatReportDialog extends StatelessWidget {
  /// Creates the threat education dialog.
  const ThreatReportDialog({super.key, required this.report});

  /// Threat report to present to the user.
  final ThreatReport report;

  /// Opens the dialog for a successful threat report.
  static Future<void> show(BuildContext context, ThreatReport report) {
    return showDialog<void>(
      context: context,
      builder: (_) => ThreatReportDialog(report: report),
    );
  }

  @override
  Widget build(BuildContext context) {
    final license = context.watch<LicenseService>();
    final lang = context.watch<LanguageService>();
    final isPro = license.isPro;

    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: isPro ? Colors.amber.withValues(alpha: 0.5) : AppColors.border,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 640),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: (isPro ? Colors.amber : AppColors.success).withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isPro ? Icons.workspace_premium : Icons.shield,
                      color: isPro ? Colors.amber : AppColors.success,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              lang.isEnglish ? 'Threat Intercepted' : 'Tehdit engellendi',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                            ),
                            if (isPro) ...[
                              const SizedBox(width: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
                                ),
                                child: Text(
                                  lang.isEnglish ? 'PRO SHIELD' : 'PRO KALKAN',
                                  style: const TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.amber,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          report.attackType,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.danger,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  report.message,
                  style: const TextStyle(fontSize: 13, height: 1.45),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  const Icon(Icons.school_outlined, size: 18, color: AppColors.accent),
                  const SizedBox(width: 8),
                  Text(
                    lang.isEnglish ? 'EduTrace AI Incident Analysis' : 'EduTrace AI Analiz Raporu',
                    style: const TextStyle(
                      color: AppColors.accent,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Flexible(
                child: SingleChildScrollView(
                  child: SelectableText(
                    report.educationalReport ?? '',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      height: 1.6,
                      fontSize: 13.5,
                    ),
                  ),
                ),
              ),
              Row(
                children: [
                  if (!isPro)
                    TextButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        LicenseDialog.show(context);
                      },
                      icon: const Icon(Icons.star, size: 16, color: Colors.amber),
                      label: Text(
                        lang.isEnglish
                            ? 'Upgrade to PRO for Active Defense'
                            : "Otonom Koruma için PRO'ya Geç",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.amber.shade300,
                        ),
                      ),
                    ),
                  const Spacer(),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: isPro ? Colors.amber.shade600 : AppColors.accent,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      lang.isEnglish ? 'Got it' : 'Anladım',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

