import 'dart:typed_data';

import 'package:flutter/services.dart';

/// Platform bridge for MediaPipe FaceMesh + Pose landmark extraction.
///
/// The app's native side (Android MediaPipe tasks-vision / iOS MediaPipeTasks)
/// implements the `poshaneye/landmarks` MethodChannel returning:
///   { "face":   { "234": [x, y], ..., "356": [x, y] },  // normalized [0, 1]
///     "pose":   { "11": [x, y], ..., "16": [x, y] },
///     "pose_visibility": { "11": 0.98, ... } }
///
/// Only the 10 FaceMesh + 6 Pose landmark indices used by the production CV
/// features are requested, matching the training extraction exactly.
class HybridLandmarkBridge {
  HybridLandmarkBridge._();
  static const _channel = MethodChannel('poshaneye/landmarks');

  /// The exact landmark indices required by MediaPipeFeatureMath.
  static const faceIndices = [234, 454, 10, 152, 33, 263, 61, 291, 127, 356];
  static const poseIndices = [11, 12, 13, 14, 15, 16];

  static Future<LandmarkResult> extractLandmarks(Uint8List imageBytes) async {
    try {
      final raw = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'extract',
        {'imageBytes': imageBytes},
      );
      final face = _decodePoints(raw?['face']);
      final pose = _decodePoints(raw?['pose']);
      final vis = <String, double>{};
      if (raw?['pose_visibility'] is Map) {
        (raw!['pose_visibility'] as Map<dynamic, dynamic>).forEach((k, v) {
          vis['$k'] = (v as num).toDouble();
        });
      }
      if (face.isEmpty) {
        throw const HybridLandmarkException(
            'No face detected. Retake the photo with the child facing the camera.');
      }
      print('[PIPELINE] MediaPipe native landmarks detected: ${face.length} face landmarks, ${pose.length} pose landmarks');
      return LandmarkResult(face: face, pose: pose, poseVisibility: vis);
    } on MissingPluginException {
      throw const HybridLandmarkException(
          'On-device landmark model is unavailable on this platform.');
    }
  }

  static Map<String, List<double>> _decodePoints(dynamic raw) {
    final out = <String, List<double>>{};
    if (raw is Map) {
      raw.forEach((k, v) {
        if (v is List && v.length >= 2) {
          out['$k'] = [(v[0] as num).toDouble(), (v[1] as num).toDouble()];
        }
      });
    }
    return out;
  }
}

class LandmarkResult {
  final Map<String, List<double>> face;
  final Map<String, List<double>> pose;
  final Map<String, double> poseVisibility;
  const LandmarkResult({
    required this.face,
    required this.pose,
    required this.poseVisibility,
  });
}

class HybridLandmarkException implements Exception {
  final String message;
  const HybridLandmarkException(this.message);
  @override
  String toString() => 'HybridLandmarkException: $message';
}
