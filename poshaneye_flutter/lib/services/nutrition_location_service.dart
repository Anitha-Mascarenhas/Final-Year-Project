import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

class NutritionLocationService {
  static const _channel = MethodChannel('poshaneye/location');

  /// Requests foreground location once and returns only a region, never GPS.
  static Future<Map<String, String>?> requestRegion() async {
    if (kIsWeb) return null;
    var permission = await Permission.locationWhenInUse.status;
    if (permission.isDenied) {
      permission = await Permission.locationWhenInUse.request();
    }
    if (permission.isPermanentlyDenied) {
      await openAppSettings();
      return null;
    }
    if (!permission.isGranted) return null;
    try {
      final result = await _channel
          .invokeMapMethod<String, dynamic>('getRegion')
          .timeout(const Duration(seconds: 5));
      if (result == null) return null;
      final region = result.map((key, value) => MapEntry(key, value.toString()))
        ..removeWhere((key, value) => value.trim().isEmpty);
      return region.isEmpty ? null : region;
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    } on TimeoutException {
      return null;
    }
  }
}
