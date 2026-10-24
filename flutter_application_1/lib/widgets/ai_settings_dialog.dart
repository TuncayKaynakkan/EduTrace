import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/language_service.dart';
import '../services/socket_service.dart';
import '../theme.dart';

/// Modal dialog allowing users to enter and configure their personal Google Gemini API key.
class AiSettingsDialog extends StatefulWidget {
  const AiSettingsDialog({super.key});

  /// Displays the AI settings modal dialog.
  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => const AiSettingsDialog(),
    );
  }

  @override
  State<AiSettingsDialog> createState() => _AiSettingsDialogState();
}

class _AiSettingsDialogState extends State<AiSettingsDialog> {
  late final TextEditingController _controller;
  bool _obscureText = true;
  String? _statusMessage;
  bool _isSuccess = false;

  @override
  void initState() {
    super.initState();
    final langService = context.read<LanguageService>();
    _controller = TextEditingController(text: langService.geminiApiKey ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _openAiStudio() {
    try {
      if (Platform.isWindows) {
        Process.run('cmd', ['/c', 'start', 'https://aistudio.google.com/app/apikey']);
      }
    } catch (e) {
      debugPrint('[AiSettingsDialog] Error opening browser: $e');
    }
  }

  void _handleSave() {
    final langService = context.read<LanguageService>();
    final socketService = context.read<SocketService>();
    final key = _controller.text.trim();

    langService.setGeminiApiKey(key.isEmpty ? null : key);
    socketService.updateGeminiApiKey(key);

    setState(() {
      _isSuccess = true;
      _statusMessage = langService.isEnglish
          ? (key.isNotEmpty
              ? 'Gemini API key saved & connected to engine!'
              : 'API key removed. Reverted to built-in template.')
          : (key.isNotEmpty
              ? 'Gemini API anahtarı kaydedildi ve motora bağlandı!'
              : 'API anahtarı kaldırıldı. Dahili şablona dönüldü.');
    });
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageService>();
    final hasKey = lang.hasCustomGeminiKey;

    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.accent, Color(0xFF6366F1)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.auto_awesome, color: Colors.black, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lang.isEnglish ? 'Google Gemini AI Settings' : 'Google Gemini AI Ayarları',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          lang.isEnglish
                              ? 'Connect your personal Google AI key for live incident reports'
                              : 'Canlı tehdit analizleri için kendi Google AI anahtarınızı bağlayın',
                          style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.textSecondary),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Current Status Banner
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: hasKey
                      ? AppColors.success.withValues(alpha: 0.1)
                      : AppColors.accent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: hasKey
                        ? AppColors.success.withValues(alpha: 0.3)
                        : AppColors.accent.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      hasKey ? Icons.check_circle : Icons.offline_bolt_outlined,
                      size: 18,
                      color: hasKey ? AppColors.success : AppColors.accent,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        hasKey
                            ? (lang.isEnglish
                                ? 'Live Gemini 2.5 Flash Engine Active'
                                : 'Canlı Gemini 2.5 Flash AI Eğitmen Aktif')
                            : (lang.isEnglish
                                ? 'Offline Mode: Built-in Educational Templates Active'
                                : 'Çevrimdışı Mod: Dahili Eğitici Şablonlar Devrede'),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: hasKey ? AppColors.success : AppColors.accent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // API Key Input
              TextField(
                controller: _controller,
                obscureText: _obscureText,
                style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
                decoration: InputDecoration(
                  labelText: lang.isEnglish ? 'Gemini API Key' : 'Gemini API Anahtarı',
                  labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  hintText: 'AIzaSy...',
                  hintStyle: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  filled: true,
                  fillColor: AppColors.background,
                  prefixIcon: const Icon(Icons.key, color: AppColors.accent, size: 18),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureText ? Icons.visibility_off : Icons.visibility,
                      color: AppColors.textSecondary,
                      size: 18,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureText = !_obscureText;
                      });
                    },
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
                  ),
                ),
              ),

              if (_statusMessage != null) ...[
                const SizedBox(height: 10),
                Text(
                  _statusMessage!,
                  style: TextStyle(
                    color: _isSuccess ? AppColors.success : AppColors.danger,
                    fontSize: 12,
                  ),
                ),
              ],

              const SizedBox(height: 14),

              // Link to get free Google AI Studio Key
              InkWell(
                onTap: _openAiStudio,
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.open_in_new, size: 14, color: AppColors.accent),
                      const SizedBox(width: 6),
                      Text(
                        lang.isEnglish
                            ? 'Get a 100% Free Gemini API key at Google AI Studio'
                            : "Google AI Studio'dan Ücretsiz Gemini API Anahtarı Alın",
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppColors.accent,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (hasKey)
                    TextButton(
                      onPressed: () {
                        _controller.clear();
                        _handleSave();
                      },
                      child: Text(
                        lang.isEnglish ? 'Clear Key' : 'Anahtarı Kaldır',
                        style: const TextStyle(color: AppColors.danger, fontSize: 12),
                      ),
                    ),
                  const Spacer(),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    onPressed: _handleSave,
                    icon: const Icon(Icons.check, size: 16),
                    label: Text(
                      lang.isEnglish ? 'Save & Connect' : 'Kaydet & Bağlan',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
