/// A network-connected process reported by the backend monitor.
class ActiveApp {
  /// Creates an active application entry.
  const ActiveApp({
    required this.name,
    required this.pid,
    required this.remoteIp,
  });

  /// Process executable name.
  final String name;

  /// Operating-system process identifier.
  final int pid;

  /// Remote IP address associated with the connection.
  final String remoteIp;

  /// Builds an [ActiveApp] from a Socket.IO payload item.
  factory ActiveApp.fromJson(Map<String, dynamic> json) {
    return ActiveApp(
      name: json['ad']?.toString() ?? 'Bilinmiyor',
      pid: int.tryParse(json['pid']?.toString() ?? '') ?? 0,
      remoteIp: json['ip']?.toString() ?? 'Bilinmiyor',
    );
  }
}
