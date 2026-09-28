import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'web_landmark_extractor_stub.dart'
    if (dart.library.html) 'web_landmark_extractor.dart' as web_landmarks;

/// Platform bridge for MediaPipe face and pose landmark extraction.
///
/// Android uses the native MethodChannel; Flutter Web uses Tasks Vision in
/// the browser. Both return:
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

  static Future<LandmarkResult> extractLandmarks(Uint8List imageBytes,
      {bool allowNoFace = false}) async {
    try {
      final raw = kIsWeb
          ? await web_landmarks.extract(imageBytes)
          : await _channel.invokeMethod<Map<dynamic, dynamic>>(
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
      final imageWidth = raw?['image_width'] is num
          ? (raw!['image_width'] as num).toInt()
          : null;
      final imageHeight = raw?['image_height'] is num
          ? (raw!['image_height'] as num).toInt()
          : null;
      if (face.isEmpty && !allowNoFace) {
        throw const HybridLandmarkException(
            'No face detected. Retake the photo with the child facing the camera.');
      }
      return LandmarkResult(
        face: face,
        pose: pose,
        poseVisibility: vis,
        imageWidth: imageWidth,
        imageHeight: imageHeight,
      );
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

/// One place to tune the live acquisition cadence and stability gate.
class LiveLandmarkTuning {
  static const sampleInterval = Duration(milliseconds: 450);
  static const minimumPoseVisibility = 0.3;
  static const captureStatusDuration = Duration(milliseconds: 450);
}

class LandmarkResult {
  final Map<String, List<double>> face;
  final Map<String, List<double>> pose;
  final Map<String, double> poseVisibility;
  final int? imageWidth;
  final int? imageHeight;
  const LandmarkResult({
    required this.face,
    required this.pose,
    required this.poseVisibility,
    this.imageWidth,
    this.imageHeight,
  });

  bool get hasValidRequiredPoints {
    bool validPoint(List<double>? point) =>
        point != null &&
        point.length >= 2 &&
        point[0].isFinite &&
        point[1].isFinite &&
        point[0] >= 0 &&
        point[0] <= 1 &&
        point[1] >= 0 &&
        point[1] <= 1;

    final completeFace = HybridLandmarkBridge.faceIndices
        .every((index) => validPoint(face['$index']));
    // Both shoulders and elbows are required so both upper arms are in view.
    final upperArms = const ['11', '12', '13', '14'].every((index) =>
        validPoint(pose[index]) &&
        (poseVisibility[index] ?? 0) >=
            LiveLandmarkTuning.minimumPoseVisibility);
    return completeFace && upperArms;
  }
}

class HybridLandmarkException implements Exception {
  final String message;
  const HybridLandmarkException(this.message);
  @override
  String toString() => 'HybridLandmarkException: $message';
}
