import 'package:flutter/material.dart';

import '../models/threat_report.dart';

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
    return AlertDialog(
      backgroundColor: const Color(0xFF0D1117),
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: Colors.greenAccent, width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      title: const Row(
        children: [
          Icon(Icons.shield, color: Colors.greenAccent, size: 32),
          SizedBox(width: 10),
          Text(
            'SISTEM GUVENDE',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              report.message,
              style: const TextStyle(
                color: Colors.greenAccent,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(color: Colors.white24, thickness: 1),
            ),
            const Text(
              'EduTrace AI Analiz Raporu:',
              style: TextStyle(
                color: Colors.cyanAccent,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              report.educationalReport ?? '',
              style: const TextStyle(color: Colors.white70, height: 1.5),
            ),
          ],
        ),
      ),
      actions: [
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green[800]),
          onPressed: () => Navigator.pop(context),
          child: const Text('Dersi Tamamla ve Kapat', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
