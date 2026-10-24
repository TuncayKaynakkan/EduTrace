/// A single clean-traffic observation emitted by the XDR engine.
class TrafficEntry {
  /// Creates a traffic entry for the dashboard radar list.
  TrafficEntry({
    required this.ip,
    required this.packetCount,
    DateTime? lastSeen,
    this.totalPackets = 0,
  }) : lastSeen = lastSeen ?? DateTime.now();

  /// Source IP address observed on the network.
  final String ip;

  /// Number of packets captured during the latest scan window.
  final int packetCount;

  /// When this IP was last observed.
  final DateTime lastSeen;

  /// Total packets observed from this IP since the dashboard started.
  final int totalPackets;

  /// Builds a [TrafficEntry] from a Socket.IO payload.
  factory TrafficEntry.fromJson(Map<String, dynamic> json) {
    final packets = int.tryParse(json['paket']?.toString() ?? '') ?? 0;
    return TrafficEntry(
      ip: json['ip']?.toString() ?? 'Bilinmiyor',
      packetCount: packets,
      totalPackets: packets,
    );
  }

  /// Returns a copy merged with a newer observation of the same IP.
  TrafficEntry merge(TrafficEntry newer) {
    return TrafficEntry(
      ip: ip,
      packetCount: newer.packetCount,
      lastSeen: newer.lastSeen,
      totalPackets: totalPackets + newer.packetCount,
    );
  }
}
