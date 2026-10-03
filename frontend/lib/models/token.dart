import 'json_utils.dart';

class Token {
  Token({
    required this.id,
    required this.tokenNumber,
    required this.visitorName,
    required this.visitorMobile,
    required this.departmentId,
    required this.departmentName,
    required this.departmentCode,
    required this.priority,
    required this.status,
    required this.noShowCount,
    required this.queuePosition,
    required this.peopleAhead,
    required this.estimatedWaitSeconds,
    this.generatedAt,
    this.servingAt,
  });

  final int id;
  final String tokenNumber;
  final String visitorName;
  final String visitorMobile;
  final int departmentId;
  final String departmentName;
  final String departmentCode;
  final bool priority;
  final String status; // WAITING | SERVING | COMPLETED | CANCELLED
  final int noShowCount;
  final int queuePosition;
  final int peopleAhead;
  final int estimatedWaitSeconds;
  final DateTime? generatedAt;
  final DateTime? servingAt;

  bool get isWaiting => status == 'WAITING';
  bool get isServing => status == 'SERVING';
  bool get isFinished => status == 'COMPLETED' || status == 'CANCELLED';

  factory Token.fromJson(Map<String, dynamic> j) => Token(
        id: asInt(j['id']),
        tokenNumber: asStr(j['token_number']),
        visitorName: asStr(j['visitor_name']),
        visitorMobile: asStr(j['visitor_mobile']),
        departmentId: asInt(j['department_id']),
        departmentName: asStr(j['department_name']),
        departmentCode: asStr(j['department_code']),
        priority: asBool(j['priority']),
        status: asStr(j['status']),
        noShowCount: asInt(j['no_show_count']),
        queuePosition: asInt(j['queue_position']),
        peopleAhead: asInt(j['people_ahead']),
        estimatedWaitSeconds: asInt(j['estimated_wait_seconds']),
        generatedAt: asDate(j['generated_at']),
        servingAt: asDate(j['serving_at']),
      );
}

/// One anonymous row in the visitor's live queue list.
class QueueEntry {
  QueueEntry({required this.tokenNumber, required this.status, required this.priority, required this.isYou});

  final String tokenNumber;
  final String status;
  final bool priority;
  final bool isYou;

  factory QueueEntry.fromJson(Map<String, dynamic> j) => QueueEntry(
        tokenNumber: asStr(j['token_number']),
        status: asStr(j['status']),
        priority: asBool(j['priority']),
        isYou: asBool(j['is_you']),
      );
}

/// Response of GET /api/tokens/{id}/queue-position.
class LiveQueue {
  LiveQueue({
    required this.tokenId,
    required this.tokenNumber,
    required this.departmentName,
    required this.departmentStatus,
    required this.status,
    required this.queuePosition,
    required this.peopleAhead,
    required this.estimatedWaitSeconds,
    required this.currentlyServing,
    required this.queue,
  });

  final int tokenId;
  final String tokenNumber;
  final String departmentName;
  final String departmentStatus;
  final String status;
  final int queuePosition;
  final int peopleAhead;
  final int estimatedWaitSeconds;
  final List<String> currentlyServing;
  final List<QueueEntry> queue;

  factory LiveQueue.fromJson(Map<String, dynamic> j) => LiveQueue(
        tokenId: asInt(j['token_id']),
        tokenNumber: asStr(j['token_number']),
        departmentName: asStr(j['department_name']),
        departmentStatus: asStr(j['department_status']),
        status: asStr(j['status']),
        queuePosition: asInt(j['queue_position']),
        peopleAhead: asInt(j['people_ahead']),
        estimatedWaitSeconds: asInt(j['estimated_wait_seconds']),
        currentlyServing: asStrList(j['currently_serving']),
        queue: asList(j['queue']).map(QueueEntry.fromJson).toList(),
      );
}
