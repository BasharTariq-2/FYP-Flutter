// lib/models/assignment.dart

class ShedAssignment {
  final int assignmentId;
  final int shedId;
  final String managerUsername;
  final String assignedBy;
  final DateTime assignedOn;
  final String status;

  ShedAssignment({
    required this.assignmentId,
    required this.shedId,
    required this.managerUsername,
    required this.assignedBy,
    required this.assignedOn,
    required this.status,
  });

  factory ShedAssignment.fromJson(Map<String, dynamic> json) {
    return ShedAssignment(
      assignmentId: json['assignment_id'],
      shedId: json['shed_id'],
      managerUsername: json['manager_username'],
      assignedBy: json['assigned_by'],
      assignedOn: DateTime.parse(json['assigned_on']),
      status: json['status'],
    );
  }
}
