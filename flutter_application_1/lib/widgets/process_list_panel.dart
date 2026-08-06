import 'package:flutter/material.dart';

import '../models/active_app.dart';

/// Renders the list of active network-connected processes.
class ProcessListPanel extends StatelessWidget {
  /// Creates the active process panel.
  const ProcessListPanel({super.key, required this.apps});

  /// Active applications reported by the backend.
  final List<ActiveApp> apps;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'AGA BAGLI SURECLER',
          style: TextStyle(
            color: Colors.orangeAccent,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: apps.isEmpty
              ? const Center(
                  child: Text(
                    'Aktif surec bekleniyor...',
                    style: TextStyle(color: Colors.white54),
                  ),
                )
              : ListView.builder(
                  itemCount: apps.length,
                  itemBuilder: (context, index) {
                    final app = apps[index];
                    return Card(
                      color: const Color(0xFF0D1117),
                      shape: RoundedRectangleBorder(
                        side: BorderSide(
                          color: Colors.orangeAccent.withValues(alpha: 0.2),
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: ListTile(
                        leading: const Icon(Icons.memory, color: Colors.orangeAccent),
                        title: Text(app.name, style: const TextStyle(fontSize: 14)),
                        subtitle: Text(
                          'PID: ${app.pid} | IP: ${app.remoteIp}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
