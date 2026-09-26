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
  //
  // Physical Android phones must use the LAPTOP'S LAN IP (not localhost, not
  // 10.0.2.2 — that is the emulator's loopback). The LAN IP is injected at
  // compile time so it stays centralized here and nowhere else:
  //   flutter run/build --dart-define=POSHANEYE_API_LAN_IP=192.168.x.x
  // When not provided, physical devices fall back to adb-reverse, which makes
  // the phone's own 127.0.0.1:8000 tunnel to the laptop's 8000 over USB.
  static const String _lanIp = String.fromEnvironment('POSHANEYE_API_LAN_IP');

  static String get baseUrl {
    if (kIsWeb) {
      debugPrint('[API] platform = web | base URL = http://localhost:8000');
      return 'http://localhost:8000';
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      final url = _lanIp.isNotEmpty ? 'http://$_lanIp:8000' : 'http://127.0.0.1:8000';
      debugPrint('[API] platform = android | base URL = $url '
          '(${_lanIp.isNotEmpty ? 'LAN IP' : 'adb reverse tunnel'})');
      return url;
    } else {
      debugPrint('[API] platform = desktop | base URL = http://localhost:8000');
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

  /// Predict malnutrition status from image bytes.
  ///
  /// The backend runs the production hybrid pipeline (168-feature fusion), so the
  /// child's anthropometrics are sent alongside the image as optional form fields;
  /// any field left null is safely imputed server-side (training-split medians).
  static Future<PredictionResult> predictImage(
    Uint8List imageBytes, {
    String filename = 'child_image.jpg',
    Map<String, String> fields = const {},
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
      request.fields.addAll(fields);

      debugPrint('[API] predict request sent -> $uri '
          '(image ${imageBytes.length} bytes, fields: ${request.fields.keys.toList()})');
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
