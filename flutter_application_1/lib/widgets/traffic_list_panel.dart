import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/traffic_entry.dart';
import '../services/language_service.dart';
import '../theme.dart';
import 'common.dart';

/// Lists unique remote hosts observed by the XDR engine.
class TrafficListPanel extends StatelessWidget {
  /// Creates the network radar panel.
  const TrafficListPanel({super.key, required this.entries});

  /// Hosts to display, most recent first.
  final List<TrafficEntry> entries;

  static bool _isLocal(String ip) =>
      ip.startsWith('192.168.') ||
      ip.startsWith('10.') ||
      ip.startsWith('127.') ||
      RegExp(r'^172\.(1[6-9]|2\d|3[01])\.').hasMatch(ip);

  static String _ago(DateTime t, LanguageService lang) {
    final s = DateTime.now().difference(t).inSeconds;
    if (s < 5) return lang.text('radar_now');
    if (s < 60) return lang.text('radar_sec_ago').replaceAll('{n}', '$s');
    return lang.text('radar_min_ago').replaceAll('{n}', '${s ~/ 60}');
  }

  static String _packets(int n) =>
      n >= 1000 ? '${(n / 1000).toStringAsFixed(1)} B' : '$n';

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageService>();

    return SectionCard(
      title: lang.text('radar_title'),
      icon: Icons.radar,
      trailing: Text(
        lang.text('radar_devices_count').replaceAll('{n}', '${entries.length}'),
        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
      ),
      child: entries.isEmpty
          ? EmptyState(
              icon: Icons.wifi_tethering,
              message: lang.text('radar_empty'),
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 6),
              itemCount: entries.length,
              separatorBuilder: (_, _) => const Divider(height: 1, indent: 18, endIndent: 18),
              itemBuilder: (context, i) {
                final e = entries[i];
                final local = _isLocal(e.ip);
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                  child: Row(
                    children: [
                      Icon(
                        local ? Icons.lan_outlined : Icons.public,
                        size: 18,
                        color: local ? AppColors.textSecondary : AppColors.accent,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          e.ip,
                          style: const TextStyle(
                            fontFamily: 'Segoe UI',
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        _packets(e.packetCount),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.accent,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Text(
                        _ago(e.lastSeen, lang),
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
