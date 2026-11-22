import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/language_service.dart';
import '../services/socket_service.dart';
import '../theme.dart';

/// Modal dialog presented on first launch or via header to select interface language.
class LanguageSelectDialog extends StatefulWidget {
  final bool isDismissible;

  const LanguageSelectDialog({super.key, this.isDismissible = true});

  /// Displays the language selection modal.
  static Future<void> show(BuildContext context, {bool isDismissible = true}) {
    return showDialog<void>(
      context: context,
      barrierDismissible: isDismissible,
      builder: (_) => LanguageSelectDialog(isDismissible: isDismissible),
    );
  }

  @override
  State<LanguageSelectDialog> createState() => _LanguageSelectDialogState();
}

class _LanguageSelectDialogState extends State<LanguageSelectDialog> {
  late AppLanguage _selected;

  @override
  void initState() {
    super.initState();
    _selected = context.read<LanguageService>().currentLanguage;
  }

  void _applySelection() {
    final langService = context.read<LanguageService>();
    langService.setLanguage(_selected);

    // Notify backend engine of language preference
    final socket = context.read<SocketService>();
    socket.emitLanguageChange(_selected.code);

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.all(26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Icon and Title
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: const Icon(Icons.language, color: AppColors.accent, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Select Language / Dil Seçimi',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                        ),
                        const SizedBox(height: 3),
                        const Text(
                          'Choose interface language / Tercihinizi belirleyin',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  if (widget.isDismissible)
                    IconButton(
                      icon: const Icon(Icons.close, color: AppColors.textSecondary),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                ],
              ),
              const SizedBox(height: 22),

              // Turkish Option Card
              _LanguageCard(
                flag: '🇹🇷',
                title: 'Türkçe',
                subtitle: 'Varsayılan Türkçe arayüz ve Türkçe AI analizi',
                isSelected: _selected == AppLanguage.tr,
                onTap: () => setState(() => _selected = AppLanguage.tr),
              ),
              const SizedBox(height: 12),

              // English Option Card
              _LanguageCard(
                flag: '🇬🇧',
                title: 'English',
                subtitle: 'International English interface and English AI reports',
                isSelected: _selected == AppLanguage.en,
                onTap: () => setState(() => _selected = AppLanguage.en),
              ),
              const SizedBox(height: 24),

              // Submit Button
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _applySelection,
                child: Text(
                  _selected == AppLanguage.en ? 'Continue / Devam Et' : 'Seçimi Kaydet ve Başla',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LanguageCard extends StatelessWidget {
  final String flag;
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _LanguageCard({
    required this.flag,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.accent.withValues(alpha: 0.08)
              : AppColors.background.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.accent : AppColors.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Text(flag, style: const TextStyle(fontSize: 26)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            Icon(
              isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
              color: isSelected ? AppColors.accent : AppColors.textSecondary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
