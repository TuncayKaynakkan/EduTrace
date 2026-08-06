/// A single clean-traffic observation emitted by the XDR engine.
class TrafficEntry {
  /// Creates a traffic entry for the dashboard radar list.
  const TrafficEntry({required this.ip, required this.packetCount});

  /// Source IP address observed on the network.
  final String ip;

  /// Number of packets captured during the scan window.
  final int packetCount;

  /// Builds a [TrafficEntry] from a Socket.IO payload.
  factory TrafficEntry.fromJson(Map<String, dynamic> json) {
    return TrafficEntry(
      ip: json['ip']?.toString() ?? 'Bilinmiyor',
      packetCount: int.tryParse(json['paket']?.toString() ?? '') ?? 0,
    );
  }
}
