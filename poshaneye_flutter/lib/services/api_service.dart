import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../models/prediction_result.dart';

class ApiService {
  ApiService._();

  // ── Configuration ──────────────────────────────────────────────────
  // Platform-aware base URL.
  // Web/Chrome → http://localhost:8000
  // Android emulator → http://10.0.2.2:8000
  // iOS simulator / physical device → http://localhost:8000
  static String get baseUrl {
    return const String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'http://localhost:8000',
    );
  }

  static const Duration _timeout = Duration(seconds: 60);

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
  /// Send image and child measurements to the backend for prediction.
  ///
  /// [imageBytes] - the raw image bytes (works on both web and mobile)
  /// [fileName] - filename for the multipart form (e.g., 'image.jpg')
  /// [childData] - map containing child measurements:
  ///   - height (double, in cm)
  ///   - weight (double, in kg)
  ///   - age (int, in months)
  ///   - muac (double, in cm) — optional, defaults to 0
  ///   - hc (double, in cm) — optional, defaults to 0
  static Future<PredictionResult> predict({
    required Uint8List imageBytes,
    required String fileName,
    required Map<String, dynamic> childData,
  }) async {
    final uri = Uri.parse('$baseUrl/predict');
    final request = http.MultipartRequest('POST', uri);

    // Add image file as bytes (web-compatible)
    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        imageBytes,
        filename: fileName,
      ),
    );

    // Add child measurements
    request.fields['height'] = (childData['height'] ?? 0).toString();
    request.fields['weight'] = (childData['weight'] ?? 0).toString();
    request.fields['age'] = (childData['age'] ?? 0).toString();
    request.fields['muac'] = (childData['muac'] ?? 0).toString();
    request.fields['hc'] = (childData['hc'] ?? 0).toString();

    final streamedResponse = await request.send().timeout(_timeout);

    if (streamedResponse.statusCode != 200) {
      final errorBody = await streamedResponse.stream.bytesToString();
      String message;
      try {
        final errorJson = jsonDecode(errorBody) as Map<String, dynamic>;
        message = errorJson['detail'] ?? errorJson['message'] ?? 'Backend error';
      } catch (_) {
        message = 'Backend returned status ${streamedResponse.statusCode}';
      }
      throw ApiException(message);
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
