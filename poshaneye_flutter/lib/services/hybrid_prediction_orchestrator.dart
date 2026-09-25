import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'hybrid_feature_extractor.dart';
import 'hybrid_inference_service.dart';

/// Offline end-to-end PoshanEye prediction.
///
/// Flutter image
///   -> MediaPipe CV extraction (21 features)          [MediaPipeFeatureMath]
///   -> DeepLabV3+ TFLite segmentation (11 features)   [HybridFeatureExtractor]
///   -> MobileNetV2 TFLite image embedding (128)       [HybridFeatureExtractor]
///   -> anthropometric input (+ derived BMI)
///   -> identical preprocessing (JSON medians/means/stds)
///   -> portable RBF-SVM in Dart
///   -> 4 nutritional classes
///
/// There is NO image-only fallback: if any extractor fails, this throws and the UI
/// must surface the error instead of silently predicting from the image alone.
class HybridPredictionOrchestrator {
  HybridPredictionOrchestrator._();
  static final HybridPredictionOrchestrator instance =
      HybridPredictionOrchestrator._();

  bool _ready = false;

  Future<void> ensureReady() async {
    if (_ready) return;
    await HybridInferenceService.instance.load();
    await HybridFeatureExtractor.instance.load();
    _ready = true;
  }

  /// [imageBytes] = JPEG/PNG bytes captured or uploaded in the app.
  /// [anthropometrics] keys: ageMonths, genderMale, heightCm, weightKg,
  /// headCircumferenceCm, waistCm (optional), muacCm.
  /// [faceLandmarks]/[poseLandmarks]: normalized MediaPipe landmark maps from the
  /// platform MediaPipe plugin (see MediaPipeFeatureMath docs).
  Future<HybridPrediction> predict({
    required Uint8List imageBytes,
    required Map<String, double> anthropometrics,
    required Map<String, List<double>> faceLandmarks,
    required Map<String, List<double>> poseLandmarks,
    Map<String, double>? poseVisibility,
  }) async {
    await ensureReady();

    final decoded = img.decodeImage(imageBytes);
    if (decoded == null) {
      throw const HybridInferenceException('Could not decode image');
    }
    final rgb = decoded.getBytes(order: img.ChannelOrder.rgb);
    final width = decoded.width, height = decoded.height;

    // 1. CV features (MediaPipe geometry; landmarks come from the platform plugin)
    final cvFeatures = MediaPipeFeatureMath.computeFeatures(
      facePoints: {
        for (final e in faceLandmarks.entries)
          e.key: [e.value[0] * width, e.value[1] * height],
      },
      posePoints: _filterVisible(poseLandmarks, poseVisibility),
      imageWidth: width.toDouble(),
      imageHeight: height.toDouble(),
    );
    print('[PIPELINE] MediaPipe CV features computed: ${cvFeatures.length}');

    // 2. Segmentation features (scale-normalized by the MediaPipe shoulder width)
    final shoulderWidth = cvFeatures['shoulder_width'];
    final segFeatures = HybridFeatureExtractor.instance.extractSegmentationFeatures(
      rgb,
      width,
      height,
      shoulderWidth != null && shoulderWidth.isFinite ? shoulderWidth : null,
    );
    print('[PIPELINE] DeepLabV3+ segmentation features: ${segFeatures.length} (arms: ${segFeatures['num_arms_detected']})');

    // 3. Image embedding (128-d, frozen MobileNetV2 feature extractor)
    final imageFeatures =
        HybridFeatureExtractor.instance.extractImageFeatures(rgb, width, height);
    print('[PIPELINE] MobileNetV2 embedding extracted: ${imageFeatures.length}-dim');

    // 4. Anthropometrics + derived BMI (identical formula to training)
    final anthro = <String, double>{
      'age_months': anthropometrics['ageMonths'] ?? double.nan,
      'gender_male': anthropometrics['genderMale'] ?? double.nan,
      'height_cm': anthropometrics['heightCm'] ?? double.nan,
      'weight_kg': anthropometrics['weightKg'] ?? double.nan,
      'head_circumference_cm': anthropometrics['headCircumferenceCm'] ?? double.nan,
      'waist_cm': anthropometrics['waistCm'] ?? double.nan,
      'muac_cm': anthropometrics['muacCm'] ?? double.nan,
      'bmi': computeBmi(
        anthropometrics['heightCm'] ?? double.nan,
        anthropometrics['weightKg'] ?? double.nan,
      ),
    };
    print('[PIPELINE] Anthropometric features prepared: ${anthro.length}');

    // 5-6. Fusion + preprocessing + portable SVM (all offline)
    final prediction = HybridInferenceService.instance.predict(
      imageFeatures: imageFeatures,
      cvFeatures: cvFeatures,
      segFeatures: segFeatures,
      anthroFeatures: anthro,
    );
    print('[PIPELINE] 168-d vector fused, preprocessed, and classified by SVM: ${prediction.prediction}');
    return prediction;
  }

  static Map<String, List<double>> _filterVisible(
      Map<String, List<double>> pose, Map<String, double>? visibility) {
    if (visibility == null) return pose;
    return {
      for (final e in pose.entries)
        if ((visibility[e.key] ?? 1.0) >= MediaPipeFeatureMath.minPoseVisibility)
          e.key: e.value,
    };
  }
}

class HybridInferenceException implements Exception {
  final String message;
  const HybridInferenceException(this.message);
  @override
  String toString() => 'HybridInferenceException: $message';
}
