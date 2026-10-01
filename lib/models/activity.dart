// lib/models/activity.dart

class ActivityLog {
  final int logId;
  final int? batchId;
  final int? shedId;
  final int? farmId;
  final String userAction;
  final String actionType;
  final String description;
  final DateTime createdOn;

  ActivityLog({
    required this.logId,
    this.batchId,
    this.shedId,
    this.farmId,
    required this.userAction,
    required this.actionType,
    required this.description,
    required this.createdOn,
  });

  factory ActivityLog.fromJson(Map<String, dynamic> json) {
    return ActivityLog(
      logId: json['log_id'],
      batchId: json['batch_id'],
      shedId: json['shed_id'],
      farmId: json['farm_id'],
      userAction: json['user_action'],
      actionType: json['action_type'],
      description: json['description'],
      createdOn: DateTime.parse(json['created_on']),
    );
  }
}
