import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';
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
      final url =
          _lanIp.isNotEmpty ? 'http://$_lanIp:8000' : 'http://127.0.0.1:8000';
      debugPrint('[API] platform = android | base URL = $url '
          '(${_lanIp.isNotEmpty ? 'LAN IP' : 'adb reverse tunnel'})');
      return url;
    } else {
      debugPrint('[API] platform = desktop | base URL = http://localhost:8000');
      return 'http://localhost:8000';
    }
  }

  static const Duration _timeout = Duration(seconds: 25);

  static Future<Map<String, dynamic>> _jsonRequest(String method, String path,
      {Object? body, String? token}) async {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (token != null) headers['Authorization'] = 'Bearer $token';
    final uri = Uri.parse('$baseUrl$path');
    late final http.Response response;
    try {
      response = method == 'GET'
          ? await http.get(uri, headers: headers).timeout(_timeout)
          : await http
              .post(uri, headers: headers, body: json.encode(body))
              .timeout(_timeout);
    } on http.ClientException {
      throw ApiException(
          'Cannot reach the backend at $baseUrl. Start the FastAPI server on port 8000 and check that CORS allows this browser origin.');
    } on TimeoutException {
      throw ApiException(
          'The backend at $baseUrl did not respond in time. Check that FastAPI is running.');
    }
    final decoded = response.body.isEmpty
        ? <String, dynamic>{}
        : json.decode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
          decoded is Map
              ? '${decoded['detail'] ?? 'Request failed'}'
              : 'Request failed',
          response.statusCode);
    }
    return (decoded as Map).cast<String, dynamic>();
  }

  static Future<Map<String, dynamic>> login(
          {required String id,
          required String password,
          required bool parent}) =>
      _jsonRequest('POST',
          parent ? '/api/auth/parent/login' : '/api/auth/health-worker/login',
          body: parent
              ? {'childId': id, 'password': password}
              : {'workerId': id, 'password': password});

  static Future<Map<String, dynamic>> signUp(
          {required bool parent, required Map<String, dynamic> body}) =>
      _jsonRequest('POST',
          parent ? '/api/auth/parent/signup' : '/api/auth/health-worker/signup',
          body: body);

  static Future<List<Map<String, dynamic>>> getScreeningHistory(
      String childId, String token) async {
    final uri = Uri.parse(
        '$baseUrl/api/screenings/history/${Uri.encodeComponent(childId)}');
    late final http.Response response;
    try {
      response = await http.get(uri,
          headers: {'Authorization': 'Bearer $token'}).timeout(_timeout);
    } on http.ClientException {
      throw ApiException(
          'Cannot reach the backend at $baseUrl. Start the FastAPI server on port 8000 and check that CORS allows this browser origin.');
    } on TimeoutException {
      throw ApiException(
          'The backend at $baseUrl did not respond in time. Check that FastAPI is running.');
    }
    if (response.statusCode != 200)
      throw ApiException(
          'Unable to load screening history (${response.statusCode}).',
          response.statusCode);
    return (json.decode(response.body) as List).cast<Map<String, dynamic>>();
  }

  static Future<Map<String, dynamic>> recordVitals(
          String childId, String token, Map<String, dynamic> vitals) =>
      _jsonRequest(
          'POST', '/api/screenings/vitals/${Uri.encodeComponent(childId)}',
          body: vitals, token: token);

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

      debugPrint('[TRACE] flutter_image_sha256=${sha256.convert(imageBytes)}');
      debugPrint('[TRACE] flutter_image_bytes=${imageBytes.length} '
          'fields=${request.fields} api_url=$uri');
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
      throw ApiException(
          'Unable to connect to server. Please check the backend and try again.');
    }
  }
}
