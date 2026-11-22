import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/language_service.dart';
import '../theme.dart';

/// Displays the current backend connection status in the header.
class ConnectionStatusBadge extends StatelessWidget {
  /// Creates a connection badge for the dashboard header.
  const ConnectionStatusBadge({super.key, required this.isConnected});

  /// Whether the backend connection is active.
  final bool isConnected;

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageService>();
    final color = isConnected ? AppColors.success : AppColors.warning;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            isConnected ? lang.text('connected') : lang.text('connecting'),
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
