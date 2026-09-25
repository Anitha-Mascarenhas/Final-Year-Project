import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:poshaneye/services/hybrid_inference_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final goldenFile = File('test/services/golden_vector.json');
  final golden = jsonDecode(goldenFile.readAsStringSync()) as Map<String, dynamic>;

  test('assets are bundled and loadable', () async {
    await HybridInferenceService.instance.load();
  });

  test('fuses the 168-d vector in the exact production order', () {
    final imageFeatures =
        (golden['image_features'] as List).map((e) => (e as num).toDouble()).toList();
    final cv = _toDoubleMap(golden['cv_features']);
    final seg = _toDoubleMap(golden['segmentation_features']);
    final anthro = _toDoubleMap(golden['anthropometric_features']);

    final fused = HybridInferenceService.fuse(
      imageFeatures: imageFeatures,
      cvFeatures: cv,
      segFeatures: seg,
      anthroFeatures: anthro,
    );

    expect(fused.length, 168);
    // Head of the vector must be the image block.
    for (var i = 0; i < 128; i++) {
      expect(fused[i], closeTo(imageFeatures[i], 1e-9));
    }
  });

  test('preprocessing matches Python exactly (golden vector)', () async {
    final service = HybridInferenceService.instance;
    await service.load();

    final imageFeatures =
        (golden['image_features'] as List).map((e) => (e as num).toDouble()).toList();
    final cv = _toDoubleMap(golden['cv_features']);
    final seg = _toDoubleMap(golden['segmentation_features']);
    final anthro = _toDoubleMap(golden['anthropometric_features']);

    final fused = HybridInferenceService.fuse(
      imageFeatures: imageFeatures,
      cvFeatures: cv,
      segFeatures: seg,
      anthroFeatures: anthro,
    );
    final preprocessed = service.preprocess(fused);

    final expected =
        (golden['expected_preprocessed_vector'] as List).map((e) => (e as num).toDouble()).toList();
    expect(preprocessed.length, expected.length);
    var maxAbsDiff = 0.0;
    for (var i = 0; i < expected.length; i++) {
      maxAbsDiff = (preprocessed[i] - expected[i]).abs() > maxAbsDiff
          ? (preprocessed[i] - expected[i]).abs()
          : maxAbsDiff;
    }
    expect(maxAbsDiff, lessThan(1e-9),
        reason: 'Dart preprocessing deviates from Python by $maxAbsDiff');
  });

  test('SVM prediction matches Python exactly (golden vector)', () async {
    final service = HybridInferenceService.instance;
    await service.load();

    final expected = golden['expected_preprocessed_vector'] as List;
    final x = expected.map((e) => (e as num).toDouble()).toList();
    final dec = service.decisionFunction(x);
    expect(dec.length, 6); // 4 classes -> 6 one-vs-one pairs

    final label = service.predictLabel(x);
    expect(label, golden['expected_label']);
  });

  test('BMI derived feature matches the Python formula', () {
    expect(computeBmi(100.0, 15.0), closeTo(15.0, 1e-9));
    expect(computeBmi(0.0, 15.0).isNaN, isTrue);
  });
}

Map<String, double> _toDoubleMap(dynamic raw) {
  final out = <String, double>{};
  (raw as Map<String, dynamic>).forEach((key, value) {
    out[key] = value == null ? double.nan : (value as num).toDouble();
  });
  return out;
}
