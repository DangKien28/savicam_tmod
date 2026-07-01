class OfflineQueueItem {
  final int? id;
  final String endpoint;
  final String payloadJson;
  final String createdAt;
  final int retryCount;

  const OfflineQueueItem({
    this.id,
    required this.endpoint,
    required this.payloadJson,
    required this.createdAt,
    this.retryCount = 0,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'endpoint': endpoint,
    'payloadJson': payloadJson,
    'createdAt': createdAt,
    'retryCount': retryCount,
  };

  factory OfflineQueueItem.fromMap(Map<String, dynamic> m) => OfflineQueueItem(
    id: m['id'] as int?,
    endpoint: m['endpoint'] as String? ?? '',
    payloadJson: m['payloadJson'] as String? ?? '{}',
    createdAt: m['createdAt'] as String? ?? '',
    retryCount: m['retryCount'] as int? ?? 0,
  );
}
