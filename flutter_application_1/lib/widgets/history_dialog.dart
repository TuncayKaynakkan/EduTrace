import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/language_service.dart';
import '../services/socket_service.dart';
import '../theme.dart';

/// Stored alert history. Free shows the last 24 hours; Pro shows 30 days and exports CSV/PDF.
class HistoryDialog extends StatefulWidget {
  const HistoryDialog({super.key});

  /// Displays the history dialog and asks the engine for the default window.
  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (_) => const HistoryDialog(),
    );
  }

  @override
  State<HistoryDialog> createState() => _HistoryDialogState();
}

class _HistoryDialogState extends State<HistoryDialog> {
  static const _windows = [1, 7, 30];
  int _days = 1;

  @override
  void initState() {
    super.initState();
    context.read<SocketService>().requestHistory(_days);
  }

  void _select(int days) {
    setState(() => _days = days);
    context.read<SocketService>().requestHistory(days);
  }

  static String _time(num seconds) {
    final t = DateTime.fromMillisecondsSinceEpoch((seconds * 1000).round());
    String two(int v) => v.toString().padLeft(2, '0');
    return '${t.year}-${two(t.month)}-${two(t.day)} ${two(t.hour)}:${two(t.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageService>();
    final socket = context.watch<SocketService>();
    final isPro = socket.engineIsPro;
    final en = lang.isEnglish;
    final events = socket.history;

    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760, maxHeight: 640),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.history, color: AppColors.accent),
                  const SizedBox(width: 8),
                  Text(
                    en ? 'Alert History' : 'Alarm Geçmişi',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => _BlockedIpsDialog.show(context),
                    icon: const Icon(Icons.block, size: 16),
                    label: Text(en ? 'Blocked IPs' : "Engellenen IP'ler"),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: AppColors.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  for (final d in _windows)
                    ChoiceChip(
                      label: Text(
                        d == 1
                            ? (en ? '24 hours' : '24 saat')
                            : (en ? '$d days' : '$d gün') + (isPro ? '' : ' · PRO'),
                      ),
                      selected: _days == d,
                      onSelected: d == 1 || isPro ? (_) => _select(d) : null,
                    ),
                  const SizedBox(width: 12),
                  Tooltip(
                    message: isPro ? '' : (en ? 'Exports require Pro' : 'Dışa aktarma Pro gerektirir'),
                    child: OutlinedButton.icon(
                      onPressed: isPro ? () => socket.requestReport(_days, 'csv') : null,
                      icon: const Icon(Icons.table_chart_outlined, size: 16),
                      label: const Text('CSV'),
                    ),
                  ),
                  Tooltip(
                    message: isPro ? '' : (en ? 'Exports require Pro' : 'Dışa aktarma Pro gerektirir'),
                    child: OutlinedButton.icon(
                      onPressed: isPro ? () => socket.requestReport(_days, 'pdf') : null,
                      icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
                      label: const Text('PDF'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: events.isEmpty
                    ? Center(
                        child: Text(
                          en ? 'No alerts in this period.' : 'Bu dönemde alarm yok.',
                          style: const TextStyle(color: AppColors.textSecondary),
                        ),
                      )
                    : ListView.separated(
                        itemCount: events.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final e = events[i];
                          final blocked = e['engellendi'] == true;
                          return ListTile(
                            dense: true,
                            leading: Icon(
                              blocked ? Icons.block : Icons.visibility_outlined,
                              color: blocked ? AppColors.danger : AppColors.warning,
                              size: 18,
                            ),
                            title: Text(
                              '${e['saldiri_turu']} — ${e['ip']}',
                              style: const TextStyle(fontSize: 13),
                            ),
                            subtitle: Text(
                              '${e['islem']}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                            ),
                            trailing: Text(
                              _time(e['zaman'] as num? ?? 0),
                              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// IPs EduTrace blocked in Windows Firewall; every user can undo a block.
class _BlockedIpsDialog extends StatefulWidget {
  const _BlockedIpsDialog();

  static Future<void> show(BuildContext context) {
    return showDialog<void>(context: context, builder: (_) => const _BlockedIpsDialog());
  }

  @override
  State<_BlockedIpsDialog> createState() => _BlockedIpsDialogState();
}

class _BlockedIpsDialogState extends State<_BlockedIpsDialog> {
  @override
  void initState() {
    super.initState();
    context.read<SocketService>().requestBlockedIps();
  }

  @override
  Widget build(BuildContext context) {
    final en = context.watch<LanguageService>().isEnglish;
    final socket = context.watch<SocketService>();
    final blocked = socket.blockedIps;
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text(en ? 'Blocked IPs' : "Engellenen IP'ler"),
      content: SizedBox(
        width: 480,
        height: 360,
        child: blocked.isEmpty
            ? Center(
                child: Text(
                  en ? 'EduTrace has not blocked any IP.' : 'EduTrace henüz bir IP engellemedi.',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              )
            : ListView.separated(
                itemCount: blocked.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final b = blocked[i];
                  final ip = b['ip']?.toString() ?? '';
                  return ListTile(
                    dense: true,
                    title: Text(ip, style: const TextStyle(fontFamily: 'Consolas')),
                    subtitle: Text(
                      '${b['neden'] ?? ''} · ${_HistoryDialogState._time(b['zaman'] as num? ?? 0)}',
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                    trailing: TextButton(
                      onPressed: () => socket.unblockIp(ip),
                      child: Text(en ? 'Unblock' : 'Engeli kaldır'),
                    ),
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(en ? 'Close' : 'Kapat'),
        ),
      ],
    );
  }
}
