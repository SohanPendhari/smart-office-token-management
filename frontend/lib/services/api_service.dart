import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  bool get isUnauthorized => statusCode == 401;

  @override
  String toString() => message;
}

/// Thin JSON-over-HTTP client. Business logic stays in the Go backend.
class ApiService {
  ApiService({required this.baseUrl, required this.authToken, http.Client? client})
      : _client = client ?? http.Client();

  /// Closures, so a changed API URL or a fresh login is picked up without rebuilding the client.
  final String Function() baseUrl;
  final String? Function() authToken;
  final http.Client _client;

  Future<dynamic> get(String path) => _send('GET', path);
  Future<dynamic> post(String path, [Map<String, dynamic>? body]) => _send('POST', path, body);
  Future<dynamic> patch(String path, [Map<String, dynamic>? body]) => _send('PATCH', path, body);

  Future<dynamic> _send(String method, String path, [Map<String, dynamic>? body]) async {
    final base = baseUrl();
    final Uri uri;
    try {
      uri = Uri.parse('$base$path');
    } on FormatException {
      throw ApiException('The API URL "$base" is not valid. Fix it in Server settings.');
    }

    final request = http.Request(method, uri);
    request.headers['Accept'] = 'application/json';
    final jwt = authToken();
    if (jwt != null && jwt.isNotEmpty) request.headers['Authorization'] = 'Bearer $jwt';
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }

    http.Response response;
    try {
      final streamed = await _client.send(request).timeout(ApiConfig.requestTimeout);
      response = await http.Response.fromStream(streamed).timeout(ApiConfig.requestTimeout);
    } on TimeoutException {
      throw ApiException('The server at $base did not answer in time. Check the API URL in Server settings.');
    } on http.ClientException {
      throw ApiException('Cannot reach the server at $base. Is the backend running and is the API URL correct?');
    }

    dynamic decoded;
    if (response.bodyBytes.isNotEmpty) {
      try {
        decoded = jsonDecode(utf8.decode(response.bodyBytes));
      } on FormatException {
        decoded = null;
      }
    }

    if (response.statusCode >= 400) {
      final message = decoded is Map && decoded['error'] is String
          ? decoded['error'] as String
          : 'Request failed (${response.statusCode})';
      throw ApiException(message, statusCode: response.statusCode);
    }
    return decoded;
  }
}
