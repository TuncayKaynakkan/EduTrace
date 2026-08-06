import 'package:flutter/material.dart';

import '../models/traffic_entry.dart';

/// Renders the live network radar list.
class TrafficListPanel extends StatelessWidget {
  /// Creates the traffic radar panel.
  const TrafficListPanel({super.key, required this.entries});

  /// Traffic observations to display.
  final List<TrafficEntry> entries;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'CANLI AG RADARI',
          style: TextStyle(
            color: Colors.cyanAccent,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF161B22),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.3)),
            ),
            child: entries.isEmpty
                ? const Center(
                    child: Text(
                      'Trafik bekleniyor...',
                      style: TextStyle(color: Colors.white54),
                    ),
                  )
                : ListView.builder(
                    itemCount: entries.length,
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      return ListTile(
                        leading: const Icon(Icons.radar, color: Colors.cyan),
                        title: Text(entry.ip),
                        trailing: Text(
                          '${entry.packetCount} Paket',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}
