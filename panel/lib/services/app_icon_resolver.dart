import 'package:flutter/material.dart';


/// Metadata for rendering an application's recognized branding icon.
class AppBrandInfo {
  final IconData icon;
  final Color color;
  final Color bgColor;
  final String? customInitials;

  const AppBrandInfo({
    required this.icon,
    required this.color,
    required this.bgColor,
    this.customInitials,
  });
}

/// Resolves brand identities, official-like colors and vector icons for popular desktop apps.
class AppIconResolver {
  AppIconResolver._();

  static AppBrandInfo resolve(String processName) {
    final lower = processName.toLowerCase();

    // 1. Web Browsers
    if (lower.contains('chrome')) {
      return const AppBrandInfo(
        icon: Icons.travel_explore,
        color: Color(0xFF4285F4),
        bgColor: Color(0x224285F4),
      );
    }
    if (lower.contains('msedge') || lower.contains('edge')) {
      return const AppBrandInfo(
        icon: Icons.language,
        color: Color(0xFF0078D7),
        bgColor: Color(0x220078D7),
      );
    }
    if (lower.contains('firefox')) {
      return const AppBrandInfo(
        icon: Icons.local_fire_department,
        color: Color(0xFFFF7139),
        bgColor: Color(0x22FF7139),
      );
    }
    if (lower.contains('opera')) {
      return const AppBrandInfo(
        icon: Icons.circle_outlined,
        color: Color(0xFFFF1B2D),
        bgColor: Color(0x22FF1B2D),
      );
    }
    if (lower.contains('brave')) {
      return const AppBrandInfo(
        icon: Icons.shield,
        color: Color(0xFFFB542B),
        bgColor: Color(0x22FB542B),
      );
    }

    // 2. Music & Streaming
    if (lower.contains('spotify')) {
      return const AppBrandInfo(
        icon: Icons.graphic_eq,
        color: Color(0xFF1DB954),
        bgColor: Color(0x221DB954),
        customInitials: 'SP',
      );
    }

    // 3. Gaming Platforms & Launchers
    if (lower.contains('epic') || lower.contains('epiconline')) {
      return const AppBrandInfo(
        icon: Icons.sports_esports,
        color: Color(0xFFFFFFFF),
        bgColor: Color(0x22FFFFFF),
        customInitials: 'EG',
      );
    }
    if (lower.contains('steam')) {
      return const AppBrandInfo(
        icon: Icons.videogame_asset,
        color: Color(0xFF171A21),
        bgColor: Color(0x3366C0F4),
      );
    }
    if (lower.contains('riot') || lower.contains('league') || lower.contains('valorant')) {
      return const AppBrandInfo(
        icon: Icons.flash_on,
        color: Color(0xFFD13639),
        bgColor: Color(0x22D13639),
      );
    }
    if (lower.contains('battle.net') || lower.contains('agent.exe')) {
      return const AppBrandInfo(
        icon: Icons.games,
        color: Color(0xFF00AEFF),
        bgColor: Color(0x2200AEFF),
      );
    }

    // 4. Communication & Social
    if (lower.contains('discord')) {
      return const AppBrandInfo(
        icon: Icons.forum,
        color: Color(0xFF5865F2),
        bgColor: Color(0x255865F2),
      );
    }
    if (lower.contains('telegram')) {
      return const AppBrandInfo(
        icon: Icons.send,
        color: Color(0xFF24A1DE),
        bgColor: Color(0x2224A1DE),
      );
    }
    if (lower.contains('whatsapp')) {
      return const AppBrandInfo(
        icon: Icons.chat,
        color: Color(0xFF25D366),
        bgColor: Color(0x2225D366),
      );
    }
    if (lower.contains('slack')) {
      return const AppBrandInfo(
        icon: Icons.grid_view,
        color: Color(0xFFECB22E),
        bgColor: Color(0x22ECB22E),
      );
    }
    if (lower.contains('teams')) {
      return const AppBrandInfo(
        icon: Icons.groups,
        color: Color(0xFF6264A7),
        bgColor: Color(0x226264A7),
      );
    }

    // 5. Developer Tools & Terminals
    if (lower.contains('code') || lower.contains('vscode')) {
      return const AppBrandInfo(
        icon: Icons.code,
        color: Color(0xFF007ACC),
        bgColor: Color(0x22007ACC),
      );
    }
    if (lower.contains('python')) {
      return const AppBrandInfo(
        icon: Icons.terminal,
        color: Color(0xFFFFD43B),
        bgColor: Color(0x22306998),
      );
    }
    if (lower.contains('cmd') || lower.contains('powershell') || lower.contains('windowsterminal')) {
      return const AppBrandInfo(
        icon: Icons.terminal_outlined,
        color: Color(0xFF4AF626),
        bgColor: Color(0x1F4AF626),
      );
    }
    if (lower.contains('git') || lower.contains('github')) {
      return const AppBrandInfo(
        icon: Icons.merge_type,
        color: Color(0xFFF05032),
        bgColor: Color(0x22F05032),
      );
    }
    if (lower.contains('language_server') || lower.contains('dart')) {
      return const AppBrandInfo(
        icon: Icons.data_object,
        color: Color(0xFF00B4AB),
        bgColor: Color(0x2200B4AB),
      );
    }

    // 6. Windows Core & System Services
    if (lower.contains('explorer')) {
      return const AppBrandInfo(
        icon: Icons.folder,
        color: Color(0xFFF9A825),
        bgColor: Color(0x22F9A825),
      );
    }
    if (lower.contains('svchost') || lower.contains('system') || lower.contains('winlogon')) {
      return const AppBrandInfo(
        icon: Icons.memory,
        color: Color(0xFF94A3B8),
        bgColor: Color(0x1894A3B8),
      );
    }

    // Default Fallback: Generate consistent deterministic palette based on app name hash
    final hash = lower.codeUnits.fold<int>(0, (prev, elem) => prev + elem);
    final fallbackColors = [
      Colors.cyanAccent,
      Colors.tealAccent,
      Colors.purpleAccent,
      Colors.pinkAccent,
      Colors.amberAccent,
      Colors.indigoAccent,
      Colors.blueAccent,
    ];
    final selectedColor = fallbackColors[hash % fallbackColors.length];

    return AppBrandInfo(
      icon: Icons.widgets_outlined,
      color: selectedColor,
      bgColor: selectedColor.withValues(alpha: 0.12),
    );
  }
}
