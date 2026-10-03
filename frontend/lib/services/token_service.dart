import '../models/department.dart';
import '../models/token.dart';
import '../models/visitor.dart';
import 'api_service.dart';

/// Everything a visitor can do.
class TokenService {
  TokenService(this._api);
  final ApiService _api;

  Future<List<Department>> departments() async {
    final json = await _api.get('/api/departments');
    return (json as List).map((e) => Department.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Department> department(int id) async =>
      Department.fromJson(await _api.get('/api/departments/$id') as Map<String, dynamic>);

  /// The backend generates the token number (e.g. IT-021); the app never does.
  Future<Token> generate(int departmentId, VisitorInput visitor) async {
    final json = await _api.post('/api/tokens', {
      'department_id': departmentId,
      'name': visitor.name,
      'mobile': visitor.mobile,
      'priority': visitor.priority,
    });
    return Token.fromJson(json as Map<String, dynamic>);
  }

  Future<Token> token(int id) async => Token.fromJson(await _api.get('/api/tokens/$id') as Map<String, dynamic>);

  Future<Token> cancel(int id) async =>
      Token.fromJson(await _api.patch('/api/tokens/$id/cancel') as Map<String, dynamic>);

  Future<LiveQueue> liveQueue(int id) async =>
      LiveQueue.fromJson(await _api.get('/api/tokens/$id/queue-position') as Map<String, dynamic>);
}
