import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

enum AppLanguage {
  tr,
  en;

  String get code => name;
  String get displayName => this == AppLanguage.tr ? 'Türkçe' : 'English';
  String get flag => this == AppLanguage.tr ? '🇹🇷' : '🇬🇧';
}

/// Central internationalization and localization service for EduTrace.
class LanguageService extends ChangeNotifier {
  AppLanguage _currentLanguage = AppLanguage.tr;
  bool _isFirstLaunch = false;
  String? _geminiApiKey;

  AppLanguage get currentLanguage => _currentLanguage;
  bool get isFirstLaunch => _isFirstLaunch;
  bool get isEnglish => _currentLanguage == AppLanguage.en;
  String? get geminiApiKey => _geminiApiKey;
  bool get hasCustomGeminiKey => _geminiApiKey != null && _geminiApiKey!.trim().isNotEmpty;

  LanguageService() {
    _loadLanguage();
  }

  File _getSettingsFile() {
    final appData = Platform.environment['APPDATA'] ??
        Platform.environment['LOCALAPPDATA'] ??
        Platform.environment['USERPROFILE'] ??
        '.';
    final dir = Directory('$appData\\EduTrace');
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return File('${dir.path}\\settings.json');
  }

  void _loadLanguage() {
    try {
      final file = _getSettingsFile();
      if (!file.existsSync()) {
        _isFirstLaunch = true;
        // Default to system locale if English
        final systemLocale = Platform.localeName.toLowerCase();
        if (systemLocale.startsWith('en')) {
          _currentLanguage = AppLanguage.en;
        } else {
          _currentLanguage = AppLanguage.tr;
        }
        notifyListeners();
        return;
      }

      final content = file.readAsStringSync();
      final data = jsonDecode(content) as Map<String, dynamic>;
      final langStr = data['language'] as String?;
      if (langStr == 'en') {
        _currentLanguage = AppLanguage.en;
      } else if (langStr == 'tr') {
        _currentLanguage = AppLanguage.tr;
      } else {
        _isFirstLaunch = true;
      }
      _geminiApiKey = data['gemini_api_key'] as String?;
      notifyListeners();
    } catch (e) {
      debugPrint('[LanguageService] Error loading settings: $e');
    }
  }

  void setLanguage(AppLanguage lang) {
    _currentLanguage = lang;
    _isFirstLaunch = false;

    try {
      final file = _getSettingsFile();
      Map<String, dynamic> data = {};
      if (file.existsSync()) {
        try {
          data = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
        } catch (_) {}
      }
      data['language'] = lang.code;
      data['updated_at'] = DateTime.now().toIso8601String();
      file.writeAsStringSync(jsonEncode(data), flush: true);
    } catch (e) {
      debugPrint('[LanguageService] Error saving language: $e');
    }

    notifyListeners();
  }

  void setGeminiApiKey(String? key) {
    _geminiApiKey = key?.trim();
    try {
      final file = _getSettingsFile();
      Map<String, dynamic> data = {};
      if (file.existsSync()) {
        try {
          data = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
        } catch (_) {}
      }
      data['gemini_api_key'] = _geminiApiKey;
      data['updated_at'] = DateTime.now().toIso8601String();
      file.writeAsStringSync(jsonEncode(data), flush: true);
    } catch (e) {
      debugPrint('[LanguageService] Error saving Gemini key: $e');
    }
    notifyListeners();
  }

  // Dictionary lookup
  String text(String key) {
    final map = isEnglish ? _en : _tr;
    return map[key] ?? _tr[key] ?? key;
  }

  // --- Localization dictionaries ---
  static const Map<String, String> _tr = {
    // Header
    'app_title': 'EduTrace',
    'app_subtitle': 'Akıllı ağ güvenliği ve eğitim asistanı',
    'connected': 'Koruma aktif',
    'connecting': 'Motora bağlanılıyor…',
    'pro_active': 'PRO AKTİF',
    'upgrade_pro': "PRO'ya Yükselt",

    // Stat cards
    'stat_hosts': 'Tespit edilen cihaz',
    'stat_packets': 'Analiz edilen paket',
    'stat_apps': 'Ağa bağlı uygulama',
    'stat_threats': 'Engellenen tehdit',

    // Radar & Traffic Panel
    'radar_title': 'Ağ Radarı',
    'radar_devices_count': '{n} cihaz',
    'radar_empty': 'Ağ trafiği izleniyor…\nİlk veriler birkaç saniye içinde görünecek.',
    'radar_now': 'şimdi',
    'radar_sec_ago': '{n} sn önce',
    'radar_min_ago': '{n} dk önce',

    // Process List Panel
    'process_title': 'Aktif Uygulamalar',
    'process_count': '{n} uygulama',
    'process_empty': 'Ağa bağlı uygulama tespit edilmedi.',
    'terminate_task': 'Görevi Sonlandır',
    'block_ip': 'IP Engelle',
    'terminate_dialog_title': 'İşlemi Sonlandır: {name}',
    'terminate_dialog_desc': 'Bu uygulamanın çalışan {count} sürecini (PID: {pids}) zorla sonlandırmak istediğinize emin misiniz?',
    'cancel': 'İptal',
    'end_task_btn': 'Görevi Sonlandır',

    // Threat History Panel
    'threat_title': 'Tehdit Geçmişi',
    'threat_empty': 'Henüz tehdit tespit edilmedi.\nSisteminiz güvende.',

    // Threat Report Dialog
    'threat_blocked': 'Tehdit engellendi',
    'pro_shield': 'PRO KALKAN',
    'ai_report_title': 'EduTrace AI Analiz Raporu',
    'upgrade_active_defense': "Otonom Koruma için PRO'ya Geç",
    'got_it': 'Anladım',

    // Language Dialog
    'select_language_title': 'Dil Seçimi / Select Language',
    'select_language_sub': 'Lütfen kullanmak istediğiniz dili seçin / Please select your preferred language.',
    'lang_turkish': 'Türkçe (Varsayılan)',
    'lang_english': 'English (International)',
    'save_choice': 'Devam Et / Continue',
  };

  static const Map<String, String> _en = {
    // Header
    'app_title': 'EduTrace',
    'app_subtitle': 'Intelligent network security & AI threat assistant',
    'connected': 'Protection Active',
    'connecting': 'Connecting to engine…',
    'pro_active': 'PRO ACTIVE',
    'upgrade_pro': 'Upgrade to PRO',

    // Stat cards
    'stat_hosts': 'Discovered hosts',
    'stat_packets': 'Analyzed packets',
    'stat_apps': 'Active network apps',
    'stat_threats': 'Blocked threats',

    // Radar & Traffic Panel
    'radar_title': 'Network Radar',
    'radar_devices_count': '{n} hosts',
    'radar_empty': 'Monitoring network traffic…\nInitial telemetry will appear shortly.',
    'radar_now': 'now',
    'radar_sec_ago': '{n}s ago',
    'radar_min_ago': '{n}m ago',

    // Process List Panel
    'process_title': 'Active Applications',
    'process_count': '{n} apps',
    'process_empty': 'No network-connected applications detected.',
    'terminate_task': 'End Task',
    'block_ip': 'Block IP',
    'terminate_dialog_title': 'Terminate Process: {name}',
    'terminate_dialog_desc': 'Are you sure you want to forcibly terminate {count} running process(es) (PID: {pids}) for this application?',
    'cancel': 'Cancel',
    'end_task_btn': 'End Task',

    // Threat History Panel
    'threat_title': 'Threat History',
    'threat_empty': 'No threats detected yet.\nYour system is secure.',

    // Threat Report Dialog
    'threat_blocked': 'Threat Blocked',
    'pro_shield': 'PRO SHIELD',
    'ai_report_title': 'EduTrace AI Incident Analysis',
    'upgrade_active_defense': 'Upgrade to PRO for Active Defense',
    'got_it': 'Got it',

    // Language Dialog
    'select_language_title': 'Select Language / Dil Seçimi',
    'select_language_sub': 'Please select your preferred interface language.',
    'lang_turkish': 'Turkish (Türkçe)',
    'lang_english': 'English (International)',
    'save_choice': 'Continue / Devam Et',
  };
}
