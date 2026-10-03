import 'json_utils.dart';

class Department {
  Department({
    required this.id,
    required this.name,
    required this.code,
    required this.status,
    required this.waiting,
    required this.serving,
    required this.currentlyServing,
    required this.estimatedWaitSeconds,
    required this.allowVisitorPriority,
  });

  final int id;
  final String name;
  final String code;
  final String status; // ACTIVE | PAUSED
  final int waiting;
  final int serving;
  final List<String> currentlyServing;
  final int estimatedWaitSeconds;
  final bool allowVisitorPriority;

  bool get isPaused => status == 'PAUSED';

  factory Department.fromJson(Map<String, dynamic> j) => Department(
        id: asInt(j['id']),
        name: asStr(j['name']),
        code: asStr(j['code']),
        status: asStr(j['status']),
        waiting: asInt(j['waiting']),
        serving: asInt(j['serving']),
        currentlyServing: asStrList(j['currently_serving']),
        estimatedWaitSeconds: asInt(j['estimated_wait_seconds']),
        allowVisitorPriority: j['allow_visitor_priority'] == null ? true : asBool(j['allow_visitor_priority']),
      );
}
