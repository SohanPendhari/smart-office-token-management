import 'json_utils.dart';

class User {
  User({required this.id, required this.name, required this.email, required this.role, this.departmentId});

  final int id;
  final String name;
  final String email;
  final String role; // ADMIN or STAFF
  final int? departmentId;

  bool get isAdmin => role == 'ADMIN';

  /// Admins manage every department; staff only their own.
  bool canManage(int deptId) => isAdmin || departmentId == deptId;

  factory User.fromJson(Map<String, dynamic> j) => User(
        id: asInt(j['id']),
        name: asStr(j['name']),
        email: asStr(j['email']),
        role: asStr(j['role']),
        departmentId: j['department_id'] == null ? null : asInt(j['department_id']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'role': role,
        'department_id': departmentId,
      };
}
