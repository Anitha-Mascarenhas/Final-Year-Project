import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/prediction_result.dart';

class ApiService {
  ApiService._();

  // ── Configuration ──────────────────────────────────────────────────
  // Change this single constant to switch environments.
  // Android emulator → http://10.0.2.2:8000
  // iOS simulator / physical device on same LAN → http://<machine-ip>:8000
  // Web → http://127.0.0.1:8000
  static const String baseUrl = 'http://10.0.2.2:8000';

  static const Duration _timeout = Duration(seconds: 30);

  // ── Health check ───────────────────────────────────────────────────
  static Future<bool> checkHealth() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/health'))
          .timeout(_timeout);
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ── Predict ────────────────────────────────────────────────────────
  static Future<PredictionResult> predict(String imagePath) async {
    final uri = Uri.parse('$baseUrl/predict');
    final request = http.MultipartRequest('POST', uri);

    request.files.add(
      await http.MultipartFile.fromPath('file', imagePath),
    );

    final streamedResponse = await request.send().timeout(_timeout);

    if (streamedResponse.statusCode != 200) {
      await streamedResponse.stream.bytesToString();
      throw ApiException(
        'Backend returned status ${streamedResponse.statusCode}.',
      );
    }

    final body = await streamedResponse.stream.bytesToString();
    final json = jsonDecode(body) as Map<String, dynamic>;

    // Validate required fields
    if (!json.containsKey('prediction') ||
        !json.containsKey('confidence') ||
        !json.containsKey('probabilities')) {
      throw const ApiException('Invalid response: missing required fields');
    }

    return PredictionResult.fromJson(json);
  }
}

class ApiException implements Exception {
  final String message;
  const ApiException(this.message);

  @override
  String toString() => 'ApiException: $message';
}
