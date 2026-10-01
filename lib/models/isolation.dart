class IsolationRecord {
  final int isolationId;
  final int batchId;
  final int hensCount;
  final String reason;
  final DateTime isolatedOn;
  final DateTime? recoveredOn;
  final String isolatedBy;

  IsolationRecord({
    required this.isolationId,
    required this.batchId,
    required this.hensCount,
    required this.reason,
    required this.isolatedOn,
    this.recoveredOn,
    required this.isolatedBy,
  });

  factory IsolationRecord.fromJson(Map<String, dynamic> json) {
    return IsolationRecord(
      isolationId: json['isolation_id'] ?? 0,
      batchId: json['batch_id'] ?? 0,
      hensCount: json['hens_count'] ?? 0,
      reason: json['reason'] ?? '',
      isolatedOn: DateTime.parse(json['isolated_on'] ?? DateTime.now().toIso8601String()),
      recoveredOn: json['recovered_on'] != null ? DateTime.parse(json['recovered_on']) : null,
      isolatedBy: json['isolated_by'] ?? '',
    );
  }
}
