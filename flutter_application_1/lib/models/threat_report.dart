/// Result payload emitted after the backend blocks a threat.
class ThreatReport {
  /// Creates a threat report shown in the education dialog.
  ThreatReport({
    required this.message,
    required this.status,
    this.attackType = 'Şüpheli Ağ Taraması',
    this.description = '',
    this.educationalReport,
    DateTime? receivedAt,
  }) : receivedAt = receivedAt ?? DateTime.now();

  /// Human-readable action summary from the XDR engine.
  final String message;

  /// Backend status flag, e.g. ``basarili``.
  final String status;

  /// Specific diagnosed attack signature, e.g. "TCP SYN Flood", "RDP Brute Force".
  final String attackType;

  /// Description / forensic detail of the captured packets.
  final String description;

  /// Optional Gemini-generated educational explanation.
  final String? educationalReport;

  /// When the dashboard received this report.
  final DateTime receivedAt;

  /// Whether the report should open the education dialog.
  bool get isSuccessful =>
      status == 'basarili' && (educationalReport?.isNotEmpty ?? false);

  /// Builds a [ThreatReport] from a Socket.IO payload.
  factory ThreatReport.fromJson(Map<String, dynamic> json) {
    return ThreatReport(
      message: json['mesaj']?.toString() ?? '',
      status: json['durum']?.toString() ?? '',
      attackType: json['saldiri_turu']?.toString() ?? 'Şüpheli Ağ Taraması',
      description: json['aciklama']?.toString() ?? '',
      educationalReport: json['egitici_rapor']?.toString(),
    );
  }
}
