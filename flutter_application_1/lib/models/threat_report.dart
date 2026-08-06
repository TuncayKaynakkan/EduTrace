/// Result payload emitted after the backend blocks a threat.
class ThreatReport {
  /// Creates a threat report shown in the education dialog.
  const ThreatReport({
    required this.message,
    required this.status,
    this.educationalReport,
  });

  /// Human-readable action summary from the XDR engine.
  final String message;

  /// Backend status flag, e.g. ``basarili``.
  final String status;

  /// Optional Gemini-generated educational explanation.
  final String? educationalReport;

  /// Whether the report should open the education dialog.
  bool get isSuccessful =>
      status == 'basarili' && (educationalReport?.isNotEmpty ?? false);

  /// Builds a [ThreatReport] from a Socket.IO payload.
  factory ThreatReport.fromJson(Map<String, dynamic> json) {
    return ThreatReport(
      message: json['mesaj']?.toString() ?? '',
      status: json['durum']?.toString() ?? '',
      educationalReport: json['egitici_rapor']?.toString(),
    );
  }
}
