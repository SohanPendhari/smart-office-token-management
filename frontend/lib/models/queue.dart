import 'department.dart';
import 'json_utils.dart';
import 'token.dart';

/// Response of GET /api/queues/{departmentId} (staff view).
class StaffQueue {
  StaffQueue({
    required this.department,
    required this.serving,
    required this.waiting,
    required this.completedToday,
    required this.noShowsToday,
  });

  final Department department;
  final List<Token> serving;
  final List<Token> waiting;
  final int completedToday;
  final int noShowsToday;

  factory StaffQueue.fromJson(Map<String, dynamic> j) => StaffQueue(
        department: Department.fromJson(j['department'] as Map<String, dynamic>),
        serving: asList(j['serving']).map(Token.fromJson).toList(),
        waiting: asList(j['waiting']).map(Token.fromJson).toList(),
        completedToday: asInt(j['completed_today']),
        noShowsToday: asInt(j['no_shows_today']),
      );
}
