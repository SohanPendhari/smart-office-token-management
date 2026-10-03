class AppConfig {
  static const String appName = 'Smart Office';
  static const String tagline = 'Queue & Token Management';

  /// REST polling interval for live screens (no WebSocket needed for the assessment).
  static const Duration pollInterval = Duration(seconds: 5);

  static const String prefApiUrl = 'api_base_url';
  static const String prefAuthToken = 'auth_token';
  static const String prefAuthUser = 'auth_user';
  static const String prefMyTokens = 'my_token_ids';
}
