class LiveSessionLogEntry {
  const LiveSessionLogEntry({
    required this.offset,
    required this.stream,
    required this.line,
    required this.at,
  });

  final int offset;
  final String stream;
  final String line;
  final DateTime at;

  static LiveSessionLogEntry fromJson(Map<String, Object?> json) {
    final int? offset = json['offset'] is int ? json['offset']! as int : null;
    final String? stream =
        json['stream'] is String && (json['stream']! as String).isNotEmpty
        ? json['stream']! as String
        : null;
    final String? line = json['line'] is String ? json['line']! as String : null;
    final DateTime? at =
        json['at'] is String ? DateTime.tryParse(json['at']! as String) : null;
    if (offset == null || stream == null || line == null || at == null) {
      throw const FormatException('invalid_session_log_payload');
    }
    return LiveSessionLogEntry(offset: offset, stream: stream, line: line, at: at);
  }
}
