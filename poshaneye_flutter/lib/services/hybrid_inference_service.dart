import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart' show rootBundle;

/// Offline hybrid inference for PoshanEye.
///
/// Reproduces EXACTLY the Python production pipeline:
///   [128 image feats | 21 cv feats | 11 seg feats | 8 anthro feats]
///     -> per-group median imputation + standardization
///     -> multiclass RBF-SVM (one-vs-one, exact libsvm reconstruction)
///     -> 4 nutritional classes
///
/// Feature extraction stages (image/CV/segmentation) are implemented by the
/// platform channels bridge in [HybridFeatureBridge]; this file owns feature
/// fusion, preprocessing and classification so Python and Dart cannot drift.
class HybridInferenceService {
  HybridInferenceService._();

  static const List<String> cvColumns = [
    'face_width', 'face_height', 'eye_distance', 'mouth_width', 'jaw_width',
    'face_ratio', 'eye_ratio', 'mouth_ratio',
    'shoulder_width',
    'left_upper_arm_length', 'right_upper_arm_length',
    'left_forearm_length', 'right_forearm_length',
    'left_total_arm_length', 'right_total_arm_length',
    'left_upper_arm_to_shoulder_ratio', 'right_upper_arm_to_shoulder_ratio',
    'left_forearm_to_shoulder_ratio', 'right_forearm_to_shoulder_ratio',
    'left_total_arm_to_shoulder_ratio', 'right_total_arm_to_shoulder_ratio',
  ];

  static const List<String> segmentationColumns = [
    'total_arm_area_norm',
    'left_arm_area_norm', 'right_arm_area_norm',
    'left_arm_width_norm', 'right_arm_width_norm',
    'left_arm_height_norm', 'right_arm_height_norm',
    'left_arm_aspect_ratio', 'right_arm_aspect_ratio',
    'total_arm_area', 'num_arms_detected',
  ];

  static const List<String> anthropometricColumns = [
    'age_months', 'gender_male', 'height_cm', 'weight_kg',
    'head_circumference_cm', 'waist_cm', 'muac_cm', 'bmi',
  ];

  static const int imageDim = 128;
  static const int cvDim = 21;
  static const int segDim = 11;
  static const int anthroDim = 8;
  static const int totalDim = imageDim + cvDim + segDim + anthroDim; // 168

  static HybridInferenceService? _instance;
  static HybridInferenceService get instance =>
      _instance ??= HybridInferenceService._();

  bool _loaded = false;
  late final List<double> _medians; // length 168, in fused order
  late final List<double> _means;
  late final List<double> _stds;
  late final double _gamma;
  late final List<int> _classes;
  late final List<int> _nSupport;
  late final List<List<double>> _supportVectors; // [n_sv][168]
  late final List<List<double>> _dualCoefs; // [n_classes-1][n_sv]
  late final List<double> _intercepts; // [n_pairs]
  late final List<int> _starts; // class-block start offsets
  late final Map<int, String> _labelMap;

  Future<void> load() async {
    if (_loaded) return;
    final preJson = jsonDecode(
      await rootBundle.loadString('assets/models/hybrid_production_preprocessor.json'),
    ) as Map<String, dynamic>;
    final svmJson = jsonDecode(
      await rootBundle.loadString('assets/models/hybrid_production_svm_portable.json'),
    ) as Map<String, dynamic>;
    final labelJson = jsonDecode(
      await rootBundle.loadString('assets/models/hybrid_production_label_map.json'),
    ) as Map<String, dynamic>;

    final groups = preJson['groups'] as Map<String, dynamic>;
    final imageDimSaved = groups['image']['dim'] as int;
    assert(imageDimSaved == imageDim);

    _medians = _flattenGroupStats(preJson['medians'], imageDimSaved);
    _means = _flattenGroupStats(preJson['means'], imageDimSaved);
    _stds = _flattenGroupStats(preJson['stds'], imageDimSaved);

    _gamma = (svmJson['gamma'] as num).toDouble();
    _classes = (svmJson['classes'] as List).map((e) => e as int).toList();
    _nSupport = (svmJson['n_support'] as List).map((e) => e as int).toList();
    _supportVectors = (svmJson['support_vectors'] as List)
        .map((row) => (row as List).map((e) => (e as num).toDouble()).toList())
        .toList();
    _dualCoefs = (svmJson['dual_coefs'] as List)
        .map((row) => (row as List).map((e) => (e as num).toDouble()).toList())
        .toList();
    _intercepts = (svmJson['intercepts'] as List)
        .map((e) => (e as num).toDouble())
        .toList();
    _labelMap = labelJson.map((k, v) => MapEntry(int.parse(k), v as String));

    _starts = List<int>.filled(_nSupport.length + 1, 0);
    for (var i = 0; i < _nSupport.length; i++) {
      _starts[i + 1] = _starts[i] + _nSupport[i];
    }
    _loaded = true;
  }

  /// Flatten the per-group stats JSON into one vector in fused order
  /// [image (index keys) | cv | segmentation | anthropometric].
  static List<double> _flattenGroupStats(dynamic statsRoot, int imgDim) {
    final medians = statsRoot['image'] as Map<String, dynamic>;
    final out = <double>[];
    for (var i = 0; i < imgDim; i++) {
      out.add((medians['$i'] as num).toDouble());
    }
    for (final group in ['cv', 'segmentation', 'anthropometric']) {
      final g = statsRoot[group] as Map<String, dynamic>;
      final cols = group == 'cv'
          ? cvColumns
          : group == 'segmentation'
              ? segmentationColumns
              : anthropometricColumns;
      for (final c in cols) {
        out.add((g[c] as num).toDouble());
      }
    }
    return out;
  }

  /// Fuse the raw feature blocks in the fixed production order.
  static List<double> fuse({
    required List<double> imageFeatures, // 128
    required Map<String, double> cvFeatures, // 21
    required Map<String, double> segFeatures, // 11
    required Map<String, double> anthroFeatures, // 8
  }) {
    assert(imageFeatures.length == imageDim);
    final out = <double>[...imageFeatures];
    out.addAll(cvColumns.map((c) => cvFeatures[c] ?? double.nan));
    out.addAll(segmentationColumns.map((c) => segFeatures[c] ?? double.nan));
    out.addAll(
        anthropometricColumns.map((c) => anthroFeatures[c] ?? double.nan));
    assert(out.length == totalDim);
    return out;
  }

  /// Median-impute + standardize, identical to the Python preprocessor.
  List<double> preprocess(List<double> fusedRaw) {
    assert(fusedRaw.length == totalDim);
    final out = List<double>.filled(totalDim, 0);
    for (var i = 0; i < totalDim; i++) {
      var v = fusedRaw[i];
      if (v.isNaN || v.isInfinite) v = _medians[i];
      out[i] = (v - _means[i]) / _stds[i];
    }
    return out;
  }

  /// Raw one-vs-one decision values (libsvm pair order (i,j), i<j).
  /// Exact port of libsvm svm_predict_values + sklearn SVC decision layout.
  List<double> decisionFunction(List<double> x) {
    final n = _classes.length;
    final nSv = _supportVectors.length;
    final k = List<double>.filled(nSv, 0);
    for (var l = 0; l < nSv; l++) {
      var sq = 0.0;
      final sv = _supportVectors[l];
      for (var d = 0; d < totalDim; d++) {
        final diff = sv[d] - x[d];
        sq += diff * diff;
      }
      k[l] = math.exp(-_gamma * sq);
    }

    final dec = List<double>.filled(n * (n - 1) ~/ 2, 0);
    var p = 0;
    for (var i = 0; i < n; i++) {
      for (var j = i + 1; j < n; j++) {
        final si = _starts[i], sj = _starts[j];
        final ci = _nSupport[i], cj = _nSupport[j];
        final coef1 = _dualCoefs[j - 1];
        final coef2 = _dualCoefs[i];
        var s = 0.0;
        for (var t = 0; t < ci; t++) {
          s += coef1[si + t] * k[si + t];
        }
        for (var t = 0; t < cj; t++) {
          s += coef2[sj + t] * k[sj + t];
        }
        dec[p] = s + _intercepts[p];
        p++;
      }
    }
    return dec;
  }

  /// sklearn's _ovr_decision_function (votes + confidence tie-break).
  List<double> ovrScores(List<double> dec) {
    final n = _classes.length;
    final votes = List<double>.filled(n, 0);
    final soc = List<double>.filled(n, 0);
    var p = 0;
    for (var i = 0; i < n; i++) {
      for (var j = i + 1; j < n; j++) {
        soc[i] -= -dec[p];
        soc[j] += -dec[p];
        if (dec[p] > 0) {
          votes[i] += 1;
        } else {
          votes[j] += 1;
        }
        p++;
      }
    }
    for (var c = 0; c < n; c++) {
      votes[c] += soc[c] / (3 * (soc[c].abs() + 1));
    }
    return votes;
  }

  /// Classify one preprocessed fused vector. Returns the predicted class name.
  String predictLabel(List<double> preprocessed) {
    final dec = decisionFunction(preprocessed);
    final scores = ovrScores(dec);
    var best = 0;
    for (var i = 1; i < scores.length; i++) {
      if (scores[i] > scores[best]) best = i;
    }
    return _labelMap[_classes[best]] ?? _classes[best].toString();
  }

  /// Full offline pipeline from extracted raw features to a prediction.
  HybridPrediction predict({
    required List<double> imageFeatures,
    required Map<String, double> cvFeatures,
    required Map<String, double> segFeatures,
    required Map<String, double> anthroFeatures,
  }) {
    final fusedRaw = fuse(
      imageFeatures: imageFeatures,
      cvFeatures: cvFeatures,
      segFeatures: segFeatures,
      anthroFeatures: anthroFeatures,
    );
    final x = preprocess(fusedRaw);
    final label = predictLabel(x);
    return HybridPrediction(
      prediction: label,
      featureVectorDim: totalDim,
      rawFusedVector: fusedRaw,
      preprocessedVector: x,
    );
  }
}

class HybridPrediction {
  final String prediction;
  final int featureVectorDim;
  final List<double> rawFusedVector;
  final List<double> preprocessedVector;

  const HybridPrediction({
    required this.prediction,
    required this.featureVectorDim,
    required this.rawFusedVector,
    required this.preprocessedVector,
  });
}

/// BMI derived feature, computed identically to Python's derived_anthro_values.
double computeBmi(double heightCm, double weightKg) {
  if (heightCm <= 0 || heightCm.isNaN || weightKg.isNaN) return double.nan;
  final m = heightCm / 100.0;
  return weightKg / (m * m);
}
