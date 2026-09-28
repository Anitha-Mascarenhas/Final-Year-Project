import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'api_service.dart';

/// Exception thrown when ephemeral token retrieval fails.
class EphemeralTokenException implements Exception {
  final String message;
  EphemeralTokenException(this.message);

  @override
  String toString() => message;
}

/// Service abstraction for securing ephemeral Gemini Live tokens from the backend.
///
/// SECURE ARCHITECTURE:
/// Never embed a permanent Gemini API key in mobile/client code.
/// The Flutter client requests an ephemeral, short-lived session token from
/// the PoshanEye backend endpoint `/api/auth/ephemeral-token`.
class EphemeralTokenService {
  /// Compile-time override for direct testing/deployment if configured:
  /// flutter run --dart-define=GEMINI_LIVE_EPHEMERAL_TOKEN=your_token
  static const String _overrideToken = String.fromEnvironment('GEMINI_LIVE_EPHEMERAL_TOKEN');

  /// Fetches an ephemeral Gemini Live session token from the backend server.
  static Future<String> getEphemeralToken() async {
    // Return compile-time provided ephemeral token if set for local testing
    if (_overrideToken.isNotEmpty) {
      debugPrint('[EphemeralTokenService] Using compile-time ephemeral token override');
      return _overrideToken;
    }

    final String tokenUrl = '${ApiService.baseUrl}/api/auth/ephemeral-token';
    debugPrint('[EphemeralTokenService] Requesting ephemeral token from: $tokenUrl');

    try {
      final response = await http
          .get(Uri.parse(tokenUrl))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final String? token = data['token'] ?? data['ephemeral_token'];
        if (token != null && token.isNotEmpty) {
          debugPrint('[EphemeralTokenService] Successfully retrieved ephemeral token');
          return token;
        }
      }

      throw EphemeralTokenException(
        'Backend returned HTTP ${response.statusCode}: ${response.body}',
      );
    } catch (e) {
      debugPrint('[EphemeralTokenService] Error fetching token: $e');
      throw EphemeralTokenException(
        'Failed to obtain ephemeral token from backend ($tokenUrl). '
        'Ensure backend is running and GEMINI_API_KEY is configured on server.',
      );
    }
  }
}
