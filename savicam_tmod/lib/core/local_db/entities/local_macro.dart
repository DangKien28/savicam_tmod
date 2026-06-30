class LocalMacro {
  final int? id;
  final String keyword;
  final String actionType;
  final String payload;

  const LocalMacro({
    this.id,
    required this.keyword,
    required this.actionType,
    required this.payload,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'keyword': keyword,
    'actionType': actionType,
    'payload': payload,
  };

  factory LocalMacro.fromMap(Map<String, dynamic> m) => LocalMacro(
    id: m['id'] as int?,
    keyword: m['keyword'] as String? ?? '',
    actionType: m['actionType'] as String? ?? '',
    payload: m['payload'] as String? ?? '',
  );
}
