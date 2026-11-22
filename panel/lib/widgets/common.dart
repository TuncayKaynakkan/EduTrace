import 'package:flutter/material.dart';

import '../theme.dart';

/// A titled card container used for every dashboard section.
class SectionCard extends StatelessWidget {
  /// Creates a section card with a header and body.
  const SectionCard({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
    this.trailing,
    this.accent = AppColors.accent,
  });

  /// Section heading.
  final String title;

  /// Heading icon.
  final IconData icon;

  /// Section body.
  final Widget child;

  /// Optional widget at the right end of the header (e.g. a count).
  final Widget? trailing;

  /// Accent color of the icon.
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
            child: Row(
              children: [
                Icon(icon, size: 18, color: accent),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
                const Spacer(),
                ?trailing,
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(child: child),
        ],
      ),
    );
  }
}

/// Small rounded label, e.g. "Yerel ağ".
class Chip2 extends StatelessWidget {
  /// Creates a tinted chip.
  const Chip2({super.key, required this.label, required this.color});

  /// Chip text.
  final String label;

  /// Tint color.
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// Centered empty-state message with an icon.
class EmptyState extends StatelessWidget {
  /// Creates an empty-state placeholder.
  const EmptyState({super.key, required this.icon, required this.message});

  /// Illustrative icon.
  final IconData icon;

  /// Explanation text.
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 36, color: AppColors.border),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
