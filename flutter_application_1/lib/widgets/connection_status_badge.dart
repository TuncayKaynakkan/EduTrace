import 'package:flutter/material.dart';

/// Displays the current Socket.IO connection status in the app bar.
class ConnectionStatusBadge extends StatelessWidget {
  /// Creates a connection badge for the dashboard header.
  const ConnectionStatusBadge({super.key, required this.isConnected});

  /// Whether the backend connection is active.
  final bool isConnected;

  @override
  Widget build(BuildContext context) {
    final color = isConnected ? Colors.greenAccent : Colors.redAccent;

    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: Row(
        children: [
          Icon(isConnected ? Icons.link : Icons.link_off, color: color),
          const SizedBox(width: 8),
          Text(
            isConnected ? 'MOTOR AKTIF' : 'BAGLANTI BEKLENIYOR',
            style: TextStyle(color: color),
          ),
        ],
      ),
    );
  }
}
