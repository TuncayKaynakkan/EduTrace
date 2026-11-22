import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/dashboard_screen.dart';
import 'services/language_service.dart';
import 'services/license_service.dart';
import 'services/socket_service.dart';
import 'theme.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SocketService()),
        ChangeNotifierProvider(create: (_) => LicenseService()),
        ChangeNotifierProvider(create: (_) => LanguageService()),
      ],
      child: const EduTraceApp(),
    ),
  );
}

/// Root widget for the EduTrace Flutter client.
class EduTraceApp extends StatelessWidget {
  /// Creates the application shell.
  const EduTraceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'EduTrace',
      theme: buildAppTheme(),
      home: const DashboardScreen(),
    );
  }
}
