import 'package:flutter/material.dart';
import 'package:flutter_application_1/main.dart';
import 'package:flutter_application_1/services/language_service.dart';
import 'package:flutter_application_1/services/license_service.dart';
import 'package:flutter_application_1/services/socket_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// A socket service that never touches the network or starts the engine.
class _OfflineSocketService extends SocketService {
  @override
  Future<void> connect() async {}
}

void main() {
  testWidgets('Dashboard renders its stat cards and panels', (tester) async {
    // The dashboard is a wide desktop layout; the default test surface is too small.
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    late LanguageService lang;

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SocketService>(create: (_) => _OfflineSocketService()),
          ChangeNotifierProvider<LicenseService>(create: (_) => LicenseService()),
          ChangeNotifierProvider<LanguageService>(create: (_) => lang = LanguageService()),
        ],
        child: const EduTraceApp(),
      ),
    );
    // Runs the dashboard's post-frame setup (listeners, language dialog on first launch).
    await tester.pump();

    // Texts come from the language service, so the test passes in Turkish and English.
    for (final key in [
      'stat_hosts',
      'stat_packets',
      'stat_apps',
      'stat_threats',
      'radar_title',
    ]) {
      expect(find.text(lang.text(key)), findsWidgets, reason: 'missing "$key"');
    }
    // The process panel title is not in the language dictionary yet.
    expect(
      find.text(lang.isEnglish ? 'Network Applications' : 'Ağa Bağlı Uygulamalar'),
      findsWidgets,
    );
  });
}
