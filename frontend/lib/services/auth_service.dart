import '../models/user.dart';
import 'api_service.dart';

class LoginResult {
  LoginResult(this.token, this.user);
  final String token;
  final User user;
}

class AuthService {
  AuthService(this._api);
  final ApiService _api;

  Future<LoginResult> login(String email, String password) async {
    final json = await _api.post('/api/auth/login', {'email': email.trim(), 'password': password});
    final map = json as Map<String, dynamic>;
    return LoginResult(map['token'] as String, User.fromJson(map['user'] as Map<String, dynamic>));
  }
}
