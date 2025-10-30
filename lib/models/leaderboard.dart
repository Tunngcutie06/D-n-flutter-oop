class LeaderboardEntry {
  final int wave;
  final DateTime timestamp;
  LeaderboardEntry({required this.wave, required this.timestamp});
  Map<String, dynamic> toJson() => {
    'wave': wave,
    'timestamp': timestamp.toIso8601String(),
  };
  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntry(
      wave: json['wave'],
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}

