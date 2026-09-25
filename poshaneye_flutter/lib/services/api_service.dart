import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/prediction_result.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, [this.statusCode]);

  @override
  String toString() => message;
}

class ApiService {
  // Centralized Base URL configuration.
  // Change here or set at runtime if needed.
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:8000';
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000';
    } else {
      return 'http://localhost:8000';
    }
  }

  static const Duration _timeout = Duration(seconds: 25);

  /// Check backend health status
  static Future<bool> checkHealth() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/health'))
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Backend health check failed: $e');
      return false;
    }
  }

  /// Predict malnutrition status from image bytes
  static Future<PredictionResult> predictImage(
    Uint8List imageBytes, {
    String filename = 'child_image.jpg',
  }) async {
    if (imageBytes.isEmpty) {
      throw ApiException('Please select or capture a valid image first.');
    }

    try {
      final uri = Uri.parse('$baseUrl/predict');
      final request = http.MultipartRequest('POST', uri);

      final multipartFile = http.MultipartFile.fromBytes(
        'file',
        imageBytes,
        filename: filename,
      );

      request.files.add(multipartFile);

      final streamedResponse = await request.send().timeout(_timeout);
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonBody = json.decode(response.body);
        return PredictionResult.fromJson(jsonBody);
      } else {
        String detail = 'Server returned error code ${response.statusCode}';
        try {
          final errJson = json.decode(response.body);
          if (errJson is Map && errJson.containsKey('detail')) {
            detail = errJson['detail'].toString();
          }
        } catch (_) {}
        throw ApiException(detail, response.statusCode);
      }
    } on ApiException {
      rethrow;
    } catch (e) {
      debugPrint('API request error: $e');
      throw ApiException('Unable to connect to server. Please check the backend and try again.');
    }
  }
}
