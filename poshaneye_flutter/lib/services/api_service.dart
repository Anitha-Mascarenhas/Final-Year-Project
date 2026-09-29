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
      final url = _lanIp.isNotEmpty ? 'http://$_lanIp:8000' : 'http://10.128.40.32:8000';
      debugPrint('[API] platform = web | base URL = $url');
      return url;
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
      if (response.statusCode == 404 && path.startsWith('/api/nutrition/')) {
        debugPrint(
            '[API] Nutrition route missing on ${baseUrl}; restart the backend from the updated backend/app.py.');
        throw ApiException(
            'The backend you are connected to does not have the nutrition endpoint yet. Restart FastAPI from this project’s backend folder, then tap Retry.',
            response.statusCode);
      }
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

  static Future<Map<String, dynamic>> getNutritionRecommendation({
    required String childId,
    required String token,
    required Map<String, String> region,
    List<String> allergies = const [],
    List<String> dietaryPreferences = const [],
  }) =>
      _jsonRequest(
        'POST',
        '/api/nutrition/recommendation/${Uri.encodeComponent(childId)}',
        token: token,
        body: {
          'region': region,
          'allergies': allergies,
          'dietary_preferences': dietaryPreferences,
        },
      );

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

      debugPrint('[API] predict response status code: ${response.statusCode}');
      debugPrint('[API] predict response body: ${response.body}');

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
    } catch (e, stackTrace) {
      debugPrint('[API] Exception during predictImage ($baseUrl/predict): $e');
      debugPrint('[API] StackTrace: $stackTrace');
      throw ApiException('Unable to connect to server. Please check the backend and try again.');
    }
  }

  /// Run and persist one authenticated screening for the selected child.
  static Future<Map<String, dynamic>> saveScreening(
    Uint8List imageBytes, {
    required String childId,
    required String token,
    String filename = 'child_image.jpg',
    required Map<String, String> fields,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/api/screenings/predict/${Uri.encodeComponent(childId)}'),
    )..headers['Authorization'] = 'Bearer $token';
    request.files.add(http.MultipartFile.fromBytes('file', imageBytes, filename: filename));
    request.fields.addAll(fields);
    try {
      final streamed = await request.send().timeout(_timeout);
      final response = await http.Response.fromStream(streamed);
      final body = response.body.isEmpty ? <String, dynamic>{} : json.decode(response.body);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(body is Map ? '${body['detail'] ?? 'Screening failed'}' : 'Screening failed', response.statusCode);
      }
      final saved = (body as Map).cast<String, dynamic>();
      final vitals = (saved['vitals'] as Map?)?.cast<String, dynamic>();
      final result = saved['screening_result'];
      if (saved['screeningId'] == null || result is! Map || vitals == null) {
        throw ApiException(
            'The backend returned an old screening response. Restart the updated backend before saving scans.');
      }
      for (final field in const ['height_cm', 'weight_kg']) {
        final submitted = double.tryParse(fields[field] ?? '');
        final persisted = vitals[field];
        if (submitted != null &&
            (persisted is! num || (persisted.toDouble() - submitted).abs() > 0.01)) {
          throw ApiException(
              'The backend did not confirm the saved $field value. Restart the updated backend and retry this scan.');
        }
      }
      return saved;
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw ApiException('The backend did not respond in time.');
    } catch (_) {
      throw ApiException('Unable to connect to the backend. Please try again.');
    }
  }
}
