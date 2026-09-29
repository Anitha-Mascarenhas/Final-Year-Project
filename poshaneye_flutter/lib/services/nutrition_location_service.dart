import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

class NutritionLocationService {
  static const _channel = MethodChannel('poshaneye/location');

  /// Requests foreground location once and returns only a region, never GPS.
  static Future<Map<String, String>?> requestRegion() async {
    if (kIsWeb) return null;
    final permission = await Permission.locationWhenInUse.request();
    if (!permission.isGranted) return null;
    try {
      final result = await _channel
          .invokeMapMethod<String, dynamic>('getRegion')
          .timeout(const Duration(seconds: 12));
      if (result == null) return null;
      return result.map((key, value) => MapEntry(key, value.toString()))
        ..removeWhere((key, value) => value.trim().isEmpty);
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    } on TimeoutException {
      return null;
    }
  }
}

