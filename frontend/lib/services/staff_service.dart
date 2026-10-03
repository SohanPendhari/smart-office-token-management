import '../models/dashboard.dart';
import '../models/department.dart';
import '../models/queue.dart';
import '../models/token.dart';
import 'api_service.dart';

/// Everything a logged-in staff member / admin can do. All rules are enforced by the backend.
class StaffService {
  StaffService(this._api);
  final ApiService _api;

  Future<Dashboard> dashboard() async => Dashboard.fromJson(await _api.get('/api/dashboard') as Map<String, dynamic>);

  Future<StaffQueue> queue(int departmentId) async =>
      StaffQueue.fromJson(await _api.get('/api/queues/$departmentId') as Map<String, dynamic>);

  Future<Token> callNext(int departmentId) async =>
      Token.fromJson(await _api.post('/api/queues/$departmentId/call-next') as Map<String, dynamic>);

  Future<Token> complete(int tokenId) async =>
      Token.fromJson(await _api.post('/api/tokens/$tokenId/complete') as Map<String, dynamic>);

  Future<Token> noShow(int tokenId) async =>
      Token.fromJson(await _api.post('/api/tokens/$tokenId/no-show') as Map<String, dynamic>);

  Future<Token> transfer(int tokenId, int toDepartmentId, {String reason = ''}) async =>
      Token.fromJson(await _api.post('/api/tokens/$tokenId/transfer', {
        'department_id': toDepartmentId,
        'reason': reason,
      }) as Map<String, dynamic>);

  Future<Token> setPriority(int tokenId, bool priority) async =>
      Token.fromJson(await _api.post('/api/tokens/$tokenId/priority', {'priority': priority}) as Map<String, dynamic>);

  Future<Department> pause(int departmentId) async =>
      Department.fromJson(await _api.patch('/api/departments/$departmentId/pause') as Map<String, dynamic>);

  Future<Department> resume(int departmentId) async =>
      Department.fromJson(await _api.patch('/api/departments/$departmentId/resume') as Map<String, dynamic>);
}
