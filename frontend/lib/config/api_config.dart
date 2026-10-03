import 'package:flutter/foundation.dart' show kIsWeb;

/// Where the Go backend lives.
///
/// The URL can be changed at any time inside the app (Home -> gear icon -> Server settings),
/// or at build time:  flutter run -d chrome --dart-define=API_BASE_URL=http://192.168.1.10:8080
class ApiConfig {
  /// Browser on the same PC as the backend.
  static const String localUrl = 'http://localhost:8080';

  /// 10.0.2.2 is how the Android EMULATOR reaches the host PC's localhost.
  static const String emulatorUrl = 'http://10.0.2.2:8080';

  static const String _fromEnv = String.fromEnvironment('API_BASE_URL');

  /// --dart-define value if given, otherwise localhost for web and 10.0.2.2 for Android.
  static String get defaultBaseUrl => _fromEnv.isNotEmpty ? _fromEnv : (kIsWeb ? localUrl : emulatorUrl);

  static const Duration requestTimeout = Duration(seconds: 10);

  /// "192.168.1.10:8080/" -> "http://192.168.1.10:8080"
  static String normalize(String input) {
    var url = input.trim();
    if (url.isEmpty) return defaultBaseUrl;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'http://$url';
    }
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    return url;
  }
}
