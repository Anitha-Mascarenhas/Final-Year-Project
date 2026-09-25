import 'dart:math' as math;

import 'package:flutter/services.dart' show rootBundle;
import 'package:tflite_flutter/tflite_flutter.dart';

import 'hybrid_inference_service.dart';

/// On-device feature extraction for the production hybrid pipeline.
///
/// Stage 1 (image):  hybrid_production_image_feature_extractor.tflite
///                   input [1,224,224,3] float32 (MobileNetV2 preprocess: [-1,1])
///                   output [1,128] float32  <- the fused vector's image block
/// Stage 2 (segmentation): hybrid_production_segmentation.tflite (DeepLabV3+)
///                   input [1,512,512,3] float32 (ImageNet mean/std normalize)
///                   output [1,512,512,2] logits -> argmax mask -> 11 features
/// Stage 3 (CV):     MediaPipe FaceMesh/Pose landmarks (platform view or plugin)
///                   -> the 21 CV features computed by [MediaPipeFeatureMath]
///                      with the SAME landmark indices/formulas as training.
class HybridFeatureExtractor {
  HybridFeatureExtractor._();
  static final HybridFeatureExtractor instance = HybridFeatureExtractor._();

  Interpreter? _imageInterpreter;
  Interpreter? _segInterpreter;
  bool _loaded = false;

  static const imageInputSize = 224;
  static const segInputSize = 512;

  Future<void> load() async {
    if (_loaded) {
      print('[TFLITE] Interpreters already loaded, skipping re-initialization.');
      return;
    }

    const imageAssetPath = 'assets/models/hybrid_production_image_feature_extractor.tflite';
    print('[TFLITE] Loading MobileNet asset from: $imageAssetPath');
    try {
      final imageByteData = await rootBundle.load(imageAssetPath);
      final imageBytes = imageByteData.buffer.asUint8List(
        imageByteData.offsetInBytes,
        imageByteData.lengthInBytes,
      );
      print('[TFLITE] MobileNet asset read: ${imageBytes.length} bytes');

      print('[TFLITE] Creating MobileNet interpreter');
      _imageInterpreter = Interpreter.fromBuffer(imageBytes);
      print('[TFLITE] MobileNet interpreter created successfully');

      final inTensors = _imageInterpreter!.getInputTensors();
      final outTensors = _imageInterpreter!.getOutputTensors();
      print('[TFLITE] MobileNet input tensor: shape=${inTensors.map((t) => t.shape).toList()}, type=${inTensors.map((t) => t.type).toList()}');
      print('[TFLITE] MobileNet output tensor: shape=${outTensors.map((t) => t.shape).toList()}, type=${outTensors.map((t) => t.type).toList()}');
    } catch (e, stack) {
      print('[TFLITE] MobileNet interpreter creation FAILED: $e');
      print('[TFLITE] Stack trace:\n$stack');
      rethrow;
    }

    const segAssetPath = 'assets/models/hybrid_production_segmentation.tflite';
    print('[TFLITE] Loading segmentation asset from: $segAssetPath');
    try {
      final segByteData = await rootBundle.load(segAssetPath);
      final segBytes = segByteData.buffer.asUint8List(
        segByteData.offsetInBytes,
        segByteData.lengthInBytes,
      );
      print('[TFLITE] Segmentation asset read: ${segBytes.length} bytes');

      print('[TFLITE] Creating segmentation interpreter');
      _segInterpreter = Interpreter.fromBuffer(segBytes);
      print('[TFLITE] Segmentation interpreter created successfully');

      final inTensors = _segInterpreter!.getInputTensors();
      final outTensors = _segInterpreter!.getOutputTensors();
      print('[TFLITE] Segmentation input tensor: shape=${inTensors.map((t) => t.shape).toList()}, type=${inTensors.map((t) => t.type).toList()}');
      print('[TFLITE] Segmentation output tensor: shape=${outTensors.map((t) => t.shape).toList()}, type=${outTensors.map((t) => t.type).toList()}');
    } catch (e, stack) {
      print('[TFLITE] Segmentation interpreter creation FAILED: $e');
      print('[TFLITE] Stack trace:\n$stack');
      rethrow;
    }

    _loaded = true;
    print('[TFLITE] All TFLite interpreters loaded and ready.');
  }

  bool get isLoaded => _loaded;

  // ------------------------------------------------------------------ image branch
  /// [rgbPlanar] = H*W*3 RGB bytes resized to 224x224 (row-major, 3 channels interleaved).
  /// Returns the 128-d image embedding (the head of the fused vector).
  List<double> extractImageFeatures(List<int> rgbBytes, int srcWidth, int srcHeight) {
    final input = _resizeAndPreprocessMobilenet(rgbBytes, srcWidth, srcHeight);
    final output = List<List<double>>.filled(1, List<double>.filled(128, 0));
    _imageInterpreter!.run([input], output);
    return output[0];
  }

  /// MobileNetV2 preprocess_input: scale uint8 RGB to [-1, 1].
  static List<List<List<List<double>>>> _resizeAndPreprocessMobilenet(
      List<int> rgb, int srcW, int srcH) {
    final resized = _resizeRgb(rgb, srcW, srcH, imageInputSize, imageInputSize);
    final out = List.generate(
      1,
      (_) => List.generate(
        imageInputSize,
        (y) => List.generate(
          imageInputSize,
          (x) {
            final idx = (y * imageInputSize + x) * 3;
            return [
              (resized[idx] - 127.5) / 127.5,
              (resized[idx + 1] - 127.5) / 127.5,
              (resized[idx + 2] - 127.5) / 127.5,
            ];
          },
        ),
      ),
    );
    return out;
  }

  // ------------------------------------------------------------------ segmentation branch
  /// Returns the 11 segmentation features from the DeepLabV3+ TFLite mask.
  /// [shoulderWidthPx] is the MediaPipe shoulder_width reference used for
  /// scale normalization (same as training).
  Map<String, double> extractSegmentationFeatures(
      List<int> rgbBytes, int srcWidth, int srcHeight, double? shoulderWidthPx) {
    final input = _resizeAndNormalizeImagenet(rgbBytes, srcWidth, srcHeight);
    final output = List.generate(
      1,
      (_) => List.generate(
        segInputSize,
        (y) => List.generate(segInputSize, (x) => List<double>.filled(2, 0)),
      ),
    );
    _segInterpreter!.run([input], output);

    // argmax over the 2 logit channels -> binary mask
    final mask = List<List<int>>.generate(
      segInputSize,
      (y) => List<int>.generate(
        segInputSize,
        (x) => output[0][y][x][0] > output[0][y][x][1] ? 0 : 1,
      ),
    );
    return maskToFeatures(mask, shoulderWidthPx);
  }

  /// ImageNet mean/std normalization, identical to the training extractor.
  static List<List<List<List<double>>>> _resizeAndNormalizeImagenet(
      List<int> rgb, int srcW, int srcH) {
    final resized = _resizeRgb(rgb, srcW, srcH, segInputSize, segInputSize);
    const mean = [0.485, 0.456, 0.406];
    const std = [0.229, 0.224, 0.225];
    final out = List.generate(
      1,
      (_) => List.generate(
        segInputSize,
        (y) => List.generate(
          segInputSize,
          (x) {
            final idx = (y * segInputSize + x) * 3;
            return [
              (resized[idx] / 255.0 - mean[0]) / std[0],
              (resized[idx + 1] / 255.0 - mean[1]) / std[1],
              (resized[idx + 2] / 255.0 - mean[2]) / std[2],
            ];
          },
        ),
      ),
    );
    return out;
  }

  // ------------------------------------------------------------------ mask -> features
  /// Connected-component geometry identical to the training feature extractor
  /// (deeplabv3/extract_segmentation_features.py):
  ///   min component area 150, top-2 components, viewer-left/right split at x=256,
  ///   scale-normalized by shoulder_width (areas / sw^2, lengths / sw).
  static Map<String, double> maskToFeatures(List<List<int>> mask, double? shoulderWidth) {
    const n = segInputSize;
    final labels = List<List<int>>.generate(n, (_) => List<int>.filled(n, 0));
    var nextLabel = 0;
    final comps = <_Component>[];

    for (var y = 0; y < n; y++) {
      for (var x = 0; x < n; x++) {
        if (mask[y][x] == 1 && labels[y][x] == 0) {
          nextLabel++;
          final q = <List<int>>[[y, x]];
          labels[y][x] = nextLabel;
          var area = 0, minX = n, maxX = -1, minY = n, maxY = -1;
          var sumX = 0.0;
          while (q.isNotEmpty) {
            final pix = q.removeLast();
            final py = pix[0], px = pix[1];
            area++;
            sumX += px;
            if (px < minX) minX = px;
            if (px > maxX) maxX = px;
            if (py < minY) minY = py;
            if (py > maxY) maxY = py;
            for (final d in const [[-1, 0], [1, 0], [0, -1], [0, 1]]) {
              final ny = py + d[0], nx = px + d[1];
              if (ny >= 0 && ny < n && nx >= 0 && nx < n &&
                  mask[ny][nx] == 1 && labels[ny][nx] == 0) {
                labels[ny][nx] = nextLabel;
                q.add([ny, nx]);
              }
            }
          }
          if (area >= 150) {
            comps.add(_Component(
              area: area,
              cx: sumX / area,
              width: (maxX - minX + 1).toDouble(),
              height: (maxY - minY + 1).toDouble(),
            ));
          }
        }
      }
    }

    final out = <String, double>{
      'total_arm_area': 0.0,
      'num_arms_detected': 0.0,
      for (final c in HybridInferenceService.segmentationColumns)
        if (c != 'total_arm_area' && c != 'num_arms_detected') c: double.nan,
    };

    if (comps.isEmpty) return out;

    comps.sort((a, b) => b.area.compareTo(a.area));
    final kept = comps.take(2).toList();
    out['total_arm_area'] = kept.fold<double>(0, (s, c) => s + c.area);
    out['num_arms_detected'] = kept.length.toDouble();

    _Component? left, right;
    if (kept.length == 2) {
      kept.sort((a, b) => a.cx.compareTo(b.cx));
      left = kept[0];
      right = kept[1];
    } else {
      final c = kept[0];
      if (c.cx < 256.0) {
        left = c;
      } else {
        right = c;
      }
    }

    if (left != null) {
      out['left_arm_area'] = left.area.toDouble();
      out['left_arm_width'] = left.width;
      out['left_arm_height'] = left.height;
      out['left_arm_aspect_ratio'] = left.width > 0 ? left.height / left.width : double.nan;
    }
    if (right != null) {
      out['right_arm_area'] = right.area.toDouble();
      out['right_arm_width'] = right.width;
      out['right_arm_height'] = right.height;
      out['right_arm_aspect_ratio'] = right.width > 0 ? right.height / right.width : double.nan;
    }

    if (shoulderWidth != null && !shoulderWidth.isNaN && shoulderWidth > 0) {
      final sw = shoulderWidth, swSq = shoulderWidth * shoulderWidth;
      out['total_arm_area_norm'] = out['total_arm_area']! / swSq;
      if (out['left_arm_area']!.isFinite) {
        out['left_arm_area_norm'] = out['left_arm_area']! / swSq;
        out['left_arm_width_norm'] = out['left_arm_width']! / sw;
        out['left_arm_height_norm'] = out['left_arm_height']! / sw;
      }
      if (out['right_arm_area']!.isFinite) {
        out['right_arm_area_norm'] = out['right_arm_area']! / swSq;
        out['right_arm_width_norm'] = out['right_arm_width']! / sw;
        out['right_arm_height_norm'] = out['right_arm_height']! / sw;
      }
    }
    return out;
  }

  /// Bilinear resize of interleaved RGB bytes (simple, correct, offline).
  static List<int> _resizeRgb(List<int> rgb, int srcW, int srcH, int dstW, int dstH) {
    final out = List<int>.filled(dstW * dstH * 3, 0);
    for (var y = 0; y < dstH; y++) {
      final sy = y * srcH / dstH;
      final y0 = sy.floor().clamp(0, srcH - 1);
      final y1 = (y0 + 1).clamp(0, srcH - 1);
      final fy = sy - y0;
      for (var x = 0; x < dstW; x++) {
        final sx = x * srcW / dstW;
        final x0 = sx.floor().clamp(0, srcW - 1);
        final x1 = (x0 + 1).clamp(0, srcW - 1);
        final fx = sx - x0;
        for (var c = 0; c < 3; c++) {
          final p00 = rgb[(y0 * srcW + x0) * 3 + c].toDouble();
          final p01 = rgb[(y0 * srcW + x1) * 3 + c].toDouble();
          final p10 = rgb[(y1 * srcW + x0) * 3 + c].toDouble();
          final p11 = rgb[(y1 * srcW + x1) * 3 + c].toDouble();
          final top = p00 + (p01 - p00) * fx;
          final bot = p10 + (p11 - p10) * fx;
          out[(y * dstW + x) * 3 + c] = (top + (bot - top) * fy).round().clamp(0, 255);
        }
      }
    }
    return out;
  }

  void dispose() {
    _imageInterpreter?.close();
    _segInterpreter?.close();
    _imageInterpreter = null;
    _segInterpreter = null;
    _loaded = false;
  }
}

class _Component {
  final int area;
  final double cx;
  final double width;
  final double height;
  const _Component({
    required this.area,
    required this.cx,
    required this.width,
    required this.height,
  });
}

/// MediaPipe landmark math for the 21 CV features.
///
/// Uses the SAME landmark indices as training (scripts/generate_cv_features.py and
/// experiments/cv_features_clean/run_experiment.py). The platform must supply the
/// normalized FaceMesh + Pose landmarks; this class only does the geometry so the
/// formulas cannot drift from training.
class MediaPipeFeatureMath {
  static const faceLandmarks = {
    'left_face': 234, 'right_face': 454, 'forehead': 10, 'chin': 152,
    'left_eye': 33, 'right_eye': 263, 'mouth_left': 61, 'mouth_right': 291,
    'left_jaw': 127, 'right_jaw': 356,
  };
  static const poseLandmarks = {
    'l_shoulder': 11, 'r_shoulder': 12,
    'l_elbow': 13, 'r_elbow': 14, 'l_wrist': 15, 'r_wrist': 16,
  };
  static const minPoseVisibility = 0.3;

  /// [facePoints]/[posePoints] are normalized landmark coords (x,y in [0,1]) mapped
  /// to pixel space by the caller (x * imageWidth, y * imageHeight), matching
  /// training. [poseVisibility] may be null for face points.
  static Map<String, double> computeFeatures({
    required Map<String, List<double>> facePoints, // pixel coords
    required Map<String, List<double>> posePoints, // pixel coords
    required double imageWidth,
    required double imageHeight,
  }) {
    double dist(List<double> a, List<double> b) =>
        math.sqrt(math.pow(a[0] - b[0], 2) + math.pow(a[1] - b[1], 2));

    final out = <String, double>{
      for (final c in HybridInferenceService.cvColumns) c: double.nan,
    };

    if (facePoints.length == faceLandmarks.length) {
      final fw = dist(facePoints['left_face']!, facePoints['right_face']!);
      final fh = dist(facePoints['forehead']!, facePoints['chin']!);
      final ed = dist(facePoints['left_eye']!, facePoints['right_eye']!);
      final mw = dist(facePoints['mouth_left']!, facePoints['mouth_right']!);
      final jw = dist(facePoints['left_jaw']!, facePoints['right_jaw']!);
      if (fw > 0 && fh > 0) {
        out['face_width'] = fw;
        out['face_height'] = fh;
        out['eye_distance'] = ed;
        out['mouth_width'] = mw;
        out['jaw_width'] = jw;
        out['face_ratio'] = fw / fh;
        out['eye_ratio'] = ed / fw;
        out['mouth_ratio'] = mw / fw;
      }
    }

    final ls = posePoints['l_shoulder'], rs = posePoints['r_shoulder'];
    if (ls != null && rs != null) {
      final sw = dist(ls, rs);
      out['shoulder_width'] = sw;
      for (final side in const ['left', 'right']) {
        final sh = posePoints['${side == 'left' ? 'l' : 'r'}_shoulder'];
        final el = posePoints['${side == 'left' ? 'l' : 'r'}_elbow'];
        final wr = posePoints['${side == 'left' ? 'l' : 'r'}_wrist'];
        if (sh == null || el == null) continue;
        final upper = dist(sh, el);
        out['${side}_upper_arm_length'] = upper;
        if (wr != null) {
          final fore = dist(el, wr);
          out['${side}_forearm_length'] = fore;
          out['${side}_total_arm_length'] = upper + fore;
        }
        if (sw.isFinite && sw > 0) {
          out['${side}_upper_arm_to_shoulder_ratio'] = upper / sw;
          if (out['${side}_forearm_length']!.isFinite) {
            out['${side}_forearm_to_shoulder_ratio'] =
                out['${side}_forearm_length']! / sw;
          }
          if (out['${side}_total_arm_length']!.isFinite) {
            out['${side}_total_arm_to_shoulder_ratio'] =
                out['${side}_total_arm_length']! / sw;
          }
        }
      }
    }
    return out;
  }
}
