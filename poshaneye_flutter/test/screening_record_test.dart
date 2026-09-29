import 'package:flutter_test/flutter_test.dart';
import 'package:poshaneye_flutter/state/vitals_provider.dart';

void main() {
  test('parses persisted screening result, probabilities, and optional null vitals', () {
    final record = VitalsRecord.fromJson({
      'screeningId': 'mongo-id',
      'child_id': 'CHD006',
      'screened_at': '2026-09-28T10:00:00Z',
      'vitals': {
        'age_years': 2,
        'age_months': 3,
        'gender': 'Boy',
        'height_cm': 40.0,
        'weight_kg': 2.0,
        'head_circumference_cm': null,
        'waist_cm': null,
        'muac_cm': null,
        'bmi': 12.5,
      },
      'screening_result': {
        'prediction': 'underweight',
        'label_index': 1,
        'confidence': 0.75,
        'probabilities': {'healthy': 0.1, 'underweight': 0.75},
        'class_scores_raw': {'underweight': 0.4},
        'status': 'Underweight',
        'risk': 'High Risk',
        'recommendation': 'Follow up',
        'model': 'hybrid_production_v1',
        'feature_vector_dim': 168,
      },
    });

    expect(record.childId, 'CHD006');
    expect(record.heightCm, 40.0);
    expect(record.weightKg, 2.0);
    expect(record.headCircumferenceCm, isNull);
    expect(record.probabilities['underweight'], 0.75);
    expect(record.classScoresRaw['underweight'], 0.4);
    expect(record.labelIndex, 1);
    expect(record.model, 'hybrid_production_v1');
    expect(record.featureVectorDim, 168);
    expect(record.confidence, 0.75);
    expect(record.status, 'Underweight');
    expect(record.risk, 'High Risk');
    expect(record.recommendation, 'Follow up');
    expect(record.date, DateTime.parse('2026-09-28T10:00:00Z'));
  });
}
