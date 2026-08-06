import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/dashboard_screen.dart';
import 'services/socket_service.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => SocketService(),
      child: const EduTraceApp(),
    ),
  );
}

/// Root widget for the EduTrace XDR Flutter client.
class EduTraceApp extends StatelessWidget {
  /// Creates the application shell.
  const EduTraceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'EduTrace XDR',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0D1117),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF161B22),
          elevation: 2,
        ),
      ),
      home: const DashboardScreen(),
    );
  }
}
