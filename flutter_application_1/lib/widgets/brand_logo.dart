import 'package:flutter/material.dart';

/// Renders authentic, high-resolution official PNG brand logos.
class BrandLogoWidget extends StatelessWidget {
  final String processName;
  final double size;

  const BrandLogoWidget({
    super.key,
    required this.processName,
    this.size = 28,
  });

  static String? _getLogoAsset(String rawName) {
    final lower = rawName.toLowerCase();

    if (lower.contains('spotify')) return 'assets/brand_logos/spotify.png';
    if (lower.contains('chrome')) return 'assets/brand_logos/chrome.png';
    if (lower.contains('discord')) return 'assets/brand_logos/discord.png';
    if (lower.contains('steam')) return 'assets/brand_logos/steam.png';
    if (lower.contains('epic') || lower.contains('epiconline')) return 'assets/brand_logos/epic.png';
    if (lower.contains('msedge') || lower.contains('edge')) return 'assets/brand_logos/edge.png';
    if (lower.contains('vscode') || lower.contains('code.exe')) return 'assets/brand_logos/vscode.png';
    if (lower.contains('telegram')) return 'assets/brand_logos/telegram.png';
    if (lower.contains('asus') || lower.contains('armoury')) return 'assets/brand_logos/asus.png';
    if (lower.contains('svchost') ||
        lower.contains('explorer') ||
        lower.contains('system') ||
        lower.contains('taskmgr') ||
        lower.contains('winlogon')) {
      return 'assets/brand_logos/windows.png';
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final assetPath = _getLogoAsset(processName);

    if (assetPath != null) {
      return Container(
        width: size,
        height: size,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(size * 0.28),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(size * 0.22),
          child: Image.asset(
            assetPath,
            width: size,
            height: size,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => _buildFallback(),
          ),
        ),
      );
    }

    return _buildFallback();
  }

  Widget _buildFallback() {
    final firstChar = processName.isEmpty ? '?' : processName[0].toUpperCase();
    final lower = processName.toLowerCase();
    final hash = lower.codeUnits.fold<int>(0, (prev, elem) => prev + elem);
    final fallbackColors = [
      const Color(0xFF06B6D4), // Cyan
      const Color(0xFF8B5CF6), // Purple
      const Color(0xFF10B981), // Emerald
      const Color(0xFFF59E0B), // Amber
      const Color(0xFFEC4899), // Pink
      const Color(0xFF3B82F6), // Blue
    ];
    final color = fallbackColors[hash % fallbackColors.length];

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(size * 0.28),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1.2),
      ),
      child: Text(
        firstChar,
        style: TextStyle(
          color: color,
          fontSize: size * 0.48,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
