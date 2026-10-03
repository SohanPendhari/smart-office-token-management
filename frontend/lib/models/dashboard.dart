import 'json_utils.dart';

class DepartmentSummary {
  DepartmentSummary({
    required this.id,
    required this.name,
    required this.code,
    required this.status,
    required this.waiting,
    required this.serving,
  });

  final int id;
  final String name;
  final String code;
  final String status;
  final int waiting;
  final int serving;

  bool get isPaused => status == 'PAUSED';

  factory DepartmentSummary.fromJson(Map<String, dynamic> j) => DepartmentSummary(
        id: asInt(j['id']),
        name: asStr(j['name']),
        code: asStr(j['code']),
        status: asStr(j['status']),
        waiting: asInt(j['waiting']),
        serving: asInt(j['serving']),
      );
}

class Dashboard {
  Dashboard({
    required this.waiting,
    required this.serving,
    required this.completed,
    required this.noShows,
    required this.averageWaitingMinutes,
    required this.averageServiceMinutes,
    required this.departments,
  });

  final int waiting;
  final int serving;
  final int completed;
  final int noShows;
  final double averageWaitingMinutes;
  final double averageServiceMinutes;
  final List<DepartmentSummary> departments;

  factory Dashboard.fromJson(Map<String, dynamic> j) => Dashboard(
        waiting: asInt(j['waiting']),
        serving: asInt(j['serving']),
        completed: asInt(j['completed']),
        noShows: asInt(j['no_shows']),
        averageWaitingMinutes: asDouble(j['average_waiting_minutes']),
        averageServiceMinutes: asDouble(j['average_service_minutes']),
        departments: asList(j['departments']).map(DepartmentSummary.fromJson).toList(),
      );
}
