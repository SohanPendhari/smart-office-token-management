import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import '../config/app_config.dart';
import '../models/dashboard.dart';
import '../models/department.dart';
import '../models/queue.dart';
import '../models/token.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/staff_service.dart';
import '../services/token_service.dart';

// ---------------------------------------------------------------- storage

/// Overridden in main() with the real instance.
final sharedPrefsProvider = Provider<SharedPreferences>((ref) => throw UnimplementedError('override in main()'));

// ---------------------------------------------------------------- API URL

class ApiBaseUrlNotifier extends Notifier<String> {
  @override
  String build() => ref.watch(sharedPrefsProvider).getString(AppConfig.prefApiUrl) ?? ApiConfig.defaultBaseUrl;

  Future<void> save(String url) async {
    final normalized = ApiConfig.normalize(url);
    await ref.read(sharedPrefsProvider).setString(AppConfig.prefApiUrl, normalized);
    state = normalized;
  }
}

final apiBaseUrlProvider = NotifierProvider<ApiBaseUrlNotifier, String>(ApiBaseUrlNotifier.new);

// ---------------------------------------------------------------- auth

class AuthState {
  const AuthState({this.user, this.token});
  final User? user;
  final String? token;
  bool get isLoggedIn => user != null && token != null;
}

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    final prefs = ref.read(sharedPrefsProvider);
    final token = prefs.getString(AppConfig.prefAuthToken);
    final raw = prefs.getString(AppConfig.prefAuthUser);
    if (token != null && raw != null) {
      try {
        return AuthState(user: User.fromJson(jsonDecode(raw) as Map<String, dynamic>), token: token);
      } catch (_) {
        // corrupted value: fall through to logged-out
      }
    }
    return const AuthState();
  }

  Future<void> login(String email, String password) async {
    final result = await ref.read(authServiceProvider).login(email, password);
    final prefs = ref.read(sharedPrefsProvider);
    await prefs.setString(AppConfig.prefAuthToken, result.token);
    await prefs.setString(AppConfig.prefAuthUser, jsonEncode(result.user.toJson()));
    state = AuthState(user: result.user, token: result.token);
  }

  Future<void> logout() async {
    final prefs = ref.read(sharedPrefsProvider);
    await prefs.remove(AppConfig.prefAuthToken);
    await prefs.remove(AppConfig.prefAuthUser);
    state = const AuthState();
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);

// ---------------------------------------------------------------- services

final apiServiceProvider = Provider<ApiService>((ref) {
  final url = ref.watch(apiBaseUrlProvider);
  return ApiService(baseUrl: () => url, authToken: () => ref.read(authProvider).token);
});

final authServiceProvider = Provider<AuthService>((ref) => AuthService(ref.watch(apiServiceProvider)));
final tokenServiceProvider = Provider<TokenService>((ref) => TokenService(ref.watch(apiServiceProvider)));
final staffServiceProvider = Provider<StaffService>((ref) => StaffService(ref.watch(apiServiceProvider)));

// ---------------------------------------------------------------- live data (REST polling)

/// Re-runs the calling provider every [AppConfig.pollInterval]. While it reloads, the previous
/// value stays on screen, so lists do not flicker.
void _poll(Ref ref) {
  final timer = Timer(AppConfig.pollInterval, ref.invalidateSelf);
  ref.onDispose(timer.cancel);
}

final departmentsProvider = FutureProvider.autoDispose<List<Department>>((ref) {
  _poll(ref);
  return ref.watch(tokenServiceProvider).departments();
});

final departmentProvider = FutureProvider.autoDispose.family<Department, int>((ref, id) {
  _poll(ref);
  return ref.watch(tokenServiceProvider).department(id);
});

final tokenProvider = FutureProvider.autoDispose.family<Token, int>((ref, id) {
  _poll(ref);
  return ref.watch(tokenServiceProvider).token(id);
});

final liveQueueProvider = FutureProvider.autoDispose.family<LiveQueue, int>((ref, id) {
  _poll(ref);
  return ref.watch(tokenServiceProvider).liveQueue(id);
});

final dashboardProvider = FutureProvider.autoDispose<Dashboard>((ref) {
  _poll(ref);
  return ref.watch(staffServiceProvider).dashboard();
});

final staffQueueProvider = FutureProvider.autoDispose.family<StaffQueue, int>((ref, departmentId) {
  _poll(ref);
  return ref.watch(staffServiceProvider).queue(departmentId);
});

// ---------------------------------------------------------------- "My tokens" (stored on the phone)

class MyTokensNotifier extends Notifier<List<int>> {
  @override
  List<int> build() {
    final raw = ref.read(sharedPrefsProvider).getStringList(AppConfig.prefMyTokens) ?? <String>[];
    return raw.map(int.tryParse).whereType<int>().toList();
  }

  Future<void> add(int id) async {
    if (state.contains(id)) return;
    state = [id, ...state];
    await _save();
  }

  Future<void> remove(int id) async {
    state = state.where((e) => e != id).toList();
    await _save();
  }

  Future<void> _save() =>
      ref.read(sharedPrefsProvider).setStringList(AppConfig.prefMyTokens, state.map((e) => e.toString()).toList());
}

final myTokensProvider = NotifierProvider<MyTokensNotifier, List<int>>(MyTokensNotifier.new);
