import 'dart:convert';

enum QueuedOperationType {
  issueItems,
  returnItems,
  createPayment,
  closeSession,
  adjustStock,
}

enum QueuedOperationStatus {
  pending,
  syncing,
  completed,
  failed,
}

class QueuedOperation {
  const QueuedOperation({
    required this.id,
    required this.type,
    required this.endpoint,
    required this.method,
    required this.payload,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.lastError,
    this.attemptCount = 0,
    this.nextAttemptAt,
  });

  final String id;
  final QueuedOperationType type;
  final String endpoint;
  final String method;
  final Map<String, dynamic> payload;
  final QueuedOperationStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? lastError;
  final int attemptCount;
  final DateTime? nextAttemptAt;

  bool get isReadyForRetry {
    final nextAttempt = nextAttemptAt;
    return status == QueuedOperationStatus.pending &&
        (nextAttempt == null || !DateTime.now().isBefore(nextAttempt));
  }

  Map<String, Object?> toRow() {
    return {
      'id': id,
      'type': type.name,
      'endpoint': endpoint,
      'method': method,
      'payload': jsonEncode(payload),
      'status': status.name,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'lastError': lastError,
      'attemptCount': attemptCount,
      'nextAttemptAt': nextAttemptAt?.toIso8601String(),
    };
  }

  factory QueuedOperation.fromRow(Map<String, Object?> row) {
    return QueuedOperation(
      id: row['id'] as String,
      type: QueuedOperationType.values.byName(row['type'] as String),
      endpoint: row['endpoint'] as String,
      method: row['method'] as String,
      payload: Map<String, dynamic>.from(
        jsonDecode(row['payload'] as String) as Map<dynamic, dynamic>,
      ),
      status: QueuedOperationStatus.values.byName(row['status'] as String),
      createdAt: DateTime.parse(row['createdAt'] as String),
      updatedAt: DateTime.parse(row['updatedAt'] as String),
      lastError: row['lastError'] as String?,
      attemptCount: row['attemptCount'] as int? ?? 0,
      nextAttemptAt: row['nextAttemptAt'] == null
          ? null
          : DateTime.parse(row['nextAttemptAt'] as String),
    );
  }

  QueuedOperation copyWith({
    QueuedOperationStatus? status,
    String? lastError,
    int? attemptCount,
    DateTime? nextAttemptAt,
    bool clearError = false,
  }) {
    return QueuedOperation(
      id: id,
      type: type,
      endpoint: endpoint,
      method: method,
      payload: payload,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      lastError: clearError ? null : lastError ?? this.lastError,
      attemptCount: attemptCount ?? this.attemptCount,
      nextAttemptAt: nextAttemptAt ?? this.nextAttemptAt,
    );
  }
}
