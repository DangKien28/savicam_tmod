class AppSettings {
  final int id;
  final bool enableTts;
  final bool enableVibration;
  final double voiceSpeed;
  final bool isHighContrast;

  const AppSettings({
    this.id = 1,
    this.enableTts = true,
    this.enableVibration = true,
    this.voiceSpeed = 0.85,
    this.isHighContrast = true,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'enableTts': enableTts ? 1 : 0,
    'enableVibration': enableVibration ? 1 : 0,
    'voiceSpeed': voiceSpeed,
    'isHighContrast': isHighContrast ? 1 : 0,
  };

  factory AppSettings.fromMap(Map<String, dynamic> m) => AppSettings(
    id: m['id'] ?? 1,
    enableTts: (m['enableTts'] ?? 1) == 1,
    enableVibration: (m['enableVibration'] ?? 1) == 1,
    voiceSpeed: (m['voiceSpeed'] as num?)?.toDouble() ?? 0.85,
    isHighContrast: (m['isHighContrast'] ?? 1) == 1,
  );

  AppSettings copyWith({
    bool? enableTts,
    bool? enableVibration,
    double? voiceSpeed,
    bool? isHighContrast,
  }) => AppSettings(
    id: id,
    enableTts: enableTts ?? this.enableTts,
    enableVibration: enableVibration ?? this.enableVibration,
    voiceSpeed: voiceSpeed ?? this.voiceSpeed,
    isHighContrast: isHighContrast ?? this.isHighContrast,
  );
}
