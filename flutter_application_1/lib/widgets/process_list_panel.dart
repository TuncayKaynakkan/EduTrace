import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/active_app.dart';
import '../services/language_service.dart';
import '../services/socket_service.dart';
import '../theme.dart';
import 'brand_logo.dart';
import 'common.dart';

/// Lists applications that currently hold network connections.
///
/// Connections are grouped by process name, rendered with official brand logos,
/// and equipped with a 3-dot context menu to terminate the task or block associated IPs.
class ProcessListPanel extends StatelessWidget {
  /// Creates the process panel.
  const ProcessListPanel({super.key, required this.apps});

  /// Raw process/connection entries from the backend.
  final List<ActiveApp> apps;

  static String _displayName(String raw) {
    final lower = raw.toLowerCase();
    final base = lower.endsWith('.exe') ? raw.substring(0, raw.length - 4) : raw;
    return base;
  }

  void _confirmAndTerminate(BuildContext context, String appName, List<int> pids) {
    final lang = context.read<LanguageService>();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: AppColors.border),
          borderRadius: BorderRadius.circular(14),
        ),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppColors.danger, size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                lang.isEnglish
                    ? 'Terminate Process: ${_displayName(appName)}'
                    : 'İşlemi Sonlandır: ${_displayName(appName)}',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Text(
          lang.isEnglish
              ? 'Are you sure you want to forcibly terminate ${pids.length} process(es) (PID: ${pids.join(', ')}) of this application?'
              : 'Bu uygulamanın çalışan ${pids.length} sürecini (PID: ${pids.join(', ')}) zorla sonlandırmak istediğinize emin misiniz?',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              lang.isEnglish ? 'Cancel' : 'İptal',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () {
              Navigator.pop(ctx);
              context.read<SocketService>().terminateProcess(appName, pids);
            },
            child: Text(
              lang.isEnglish ? 'End Task' : 'Görevi Sonlandır',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageService>();
    final groups = <String, List<ActiveApp>>{};
    for (final app in apps) {
      groups.putIfAbsent(app.name, () => []).add(app);
    }
    final names = groups.keys.toList()
      ..sort((a, b) {
        final c = groups[b]!.length.compareTo(groups[a]!.length);
        return c != 0 ? c : a.toLowerCase().compareTo(b.toLowerCase());
      });

    return SectionCard(
      title: lang.isEnglish ? 'Network Applications' : 'Ağa Bağlı Uygulamalar',
      icon: Icons.apps,
      accent: AppColors.warning,
      trailing: Text(
        lang.isEnglish ? '${names.length} apps' : '${names.length}',
        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
      ),
      child: names.isEmpty
          ? EmptyState(
              icon: Icons.hourglass_empty,
              message: lang.isEnglish
                  ? 'Waiting for active applications…'
                  : 'Aktif uygulama bekleniyor…',
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 6),
              itemCount: names.length,
              separatorBuilder: (_, _) => const Divider(height: 1, indent: 18, endIndent: 18),
              itemBuilder: (context, i) {
                final name = names[i];
                final conns = groups[name]!;
                final pids = conns.map((a) => a.pid).where((p) => p > 0).toSet().toList();

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: Row(
                    children: [
                      // Authentic Brand Logo Widget
                      BrandLogoWidget(
                        processName: name,
                        size: 32,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _displayName(name),
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              conns.length == 1
                                  ? conns.first.remoteIp
                                  : (lang.isEnglish
                                      ? '${conns.length} connection(s) (PID: ${pids.take(2).join(', ')})'
                                      : '${conns.length} bağlantı (PID: ${pids.take(2).join(', ')})'),
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      // 3-dot context menu
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, size: 18, color: AppColors.textSecondary),
                        color: AppColors.surfaceAlt,
                        shape: RoundedRectangleBorder(
                          side: const BorderSide(color: AppColors.border),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        tooltip: lang.isEnglish ? 'Actions' : 'İşlemler',
                        onSelected: (value) {
                          if (value == 'terminate') {
                            _confirmAndTerminate(context, name, pids);
                          } else if (value.startsWith('block_ip:')) {
                            final targetIp = value.substring('block_ip:'.length);
                            context.read<SocketService>().blockIp(targetIp);
                          }
                        },
                        itemBuilder: (ctx) {
                          final items = <PopupMenuEntry<String>>[
                            PopupMenuItem(
                              value: 'terminate',
                              child: Row(
                                children: [
                                  const Icon(Icons.close_rounded, color: AppColors.danger, size: 18),
                                  const SizedBox(width: 10),
                                  Text(
                                    lang.isEnglish ? 'End Task' : 'Görevi Sonlandır',
                                    style: const TextStyle(color: AppColors.danger, fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                          ];

                          // Also allow quick-blocking active remote IPs of this process
                          final publicIps = conns
                              .map((c) => c.remoteIp)
                              .where((ip) => ip != 'Bilinmiyor' && ip != '127.0.0.1' && ip != '::1')
                              .toSet();

                          if (publicIps.isNotEmpty) {
                            items.add(const PopupMenuDivider());
                            for (final ip in publicIps.take(3)) {
                              items.add(
                                PopupMenuItem(
                                  value: 'block_ip:$ip',
                                  child: Row(
                                    children: [
                                      const Icon(Icons.shield_outlined, color: AppColors.warning, size: 16),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          lang.isEnglish ? 'Block IP: $ip' : 'IP Engelle: $ip',
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }
                          }

                          return items;
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
