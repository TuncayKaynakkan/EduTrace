import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/socket_service.dart';
import '../widgets/connection_status_badge.dart';
import '../widgets/process_list_panel.dart';
import '../widgets/threat_report_dialog.dart';
import '../widgets/traffic_list_panel.dart';

/// Main command-center screen for the EduTrace XDR dashboard.
class DashboardScreen extends StatefulWidget {
  /// Creates the dashboard screen.
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  SocketService? _socketService;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final socketService = context.read<SocketService>();
      _socketService = socketService;
      socketService.addListener(_onSocketUpdate);
      socketService.connect();
    });
  }

  void _onSocketUpdate() {
    if (!mounted || _socketService == null) {
      return;
    }

    final report = _socketService!.latestThreatReport;
    if (report == null) {
      return;
    }

    if (report.isSuccessful) {
      ThreatReportDialog.show(context, report).whenComplete(
        _socketService!.clearLatestThreatReport,
      );
      return;
    }

    if (report.message.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(report.message),
          backgroundColor: Colors.red,
        ),
      );
    }
    _socketService!.clearLatestThreatReport();
  }

  @override
  void dispose() {
    _socketService?.removeListener(_onSocketUpdate);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final socketService = context.watch<SocketService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'EduTrace XDR - Komuta Merkezi',
          style: TextStyle(color: Colors.cyanAccent),
        ),
        actions: [
          ConnectionStatusBadge(isConnected: socketService.isConnected),
        ],
      ),
      body: Row(
        children: [
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: TrafficListPanel(entries: socketService.trafficEntries),
            ),
          ),
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.all(16),
              color: const Color(0xFF161B22).withValues(alpha: 0.5),
              child: ProcessListPanel(apps: socketService.activeApps),
            ),
          ),
        ],
      ),
    );
  }
}
