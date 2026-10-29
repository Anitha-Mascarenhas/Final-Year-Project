import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import '../services/api_service.dart';

class VitalsRecord {
  final String screeningId;
  final String childId;
  final int? ageYears, ageMonths;
  final double? heightCm, weightKg, headCircumferenceCm, waistCm, muacCm, bmi;
  final String? gender, prediction;
  final double? confidence;
  final DateTime? recordedAt;
  final Map<String, double> probabilities;
  final Map<String, double> classScoresRaw;
  final int? labelIndex, featureVectorDim;
  final String? model;
  final String? risk, recommendation, screeningStatus;

  const VitalsRecord(
      {required this.screeningId,
      required this.childId,
      this.ageYears,
      this.ageMonths,
      this.heightCm,
      this.weightKg,
      this.headCircumferenceCm,
      this.waistCm,
      this.muacCm,
      this.bmi,
      this.gender,
      this.prediction,
      this.confidence,
      this.recordedAt,
      this.probabilities = const {},
      this.classScoresRaw = const {},
      this.labelIndex,
      this.featureVectorDim,
      this.model,
      this.risk,
      this.recommendation,
      this.screeningStatus});

  static double? _number(dynamic v) => v is num ? v.toDouble() : null;
  factory VitalsRecord.fromJson(Map<String, dynamic> json) {
    final v = (json['vitals'] as Map?)?.cast<String, dynamic>() ?? json;
    dynamic vital(String snakeCase, [String? camelCase]) =>
        v[snakeCase] ?? (camelCase == null ? null : v[camelCase]) ??
        json[snakeCase] ?? (camelCase == null ? null : json[camelCase]);
    final result = (json['screening_result'] as Map?)?.cast<String, dynamic>() ?? json;
    final rawProbabilities = (result['probabilities'] as Map?)?.cast<String, dynamic>() ?? {};
    final rawScores = (result['class_scores_raw'] as Map?)?.cast<String, dynamic>() ?? {};
    DateTime? date;
    try {
      date = DateTime.parse((v['recorded_at'] ?? json['screened_at'] ?? json['createdAt']).toString());
    } catch (_) {}
    return VitalsRecord(
      screeningId: '${json['screeningId'] ?? json['_id'] ?? ''}',
      childId: '${json['childId'] ?? json['child_id'] ?? ''}',
      ageYears: (vital('age_years', 'ageYears') as num?)?.toInt(),
      ageMonths: (vital('age_months', 'ageMonths') as num?)?.toInt(),
      heightCm: _number(vital('height_cm', 'heightCm')),
      weightKg: _number(vital('weight_kg', 'weightKg')),
      headCircumferenceCm:
          _number(vital('head_circumference_cm', 'headCircumferenceCm')),
      waistCm: _number(vital('waist_cm', 'waistCm')),
      muacCm: _number(vital('muac_cm', 'muacCm')),
      bmi: _number(vital('bmi')),
      gender: vital('gender') as String?,
      prediction: result['prediction'] as String?,
      confidence: _number(result['confidence']),
      recordedAt: date,
      probabilities: rawProbabilities.map((key, value) => MapEntry(key, _number(value) ?? 0)),
      classScoresRaw: rawScores.map((key, value) => MapEntry(key, _number(value) ?? 0)),
      labelIndex: (result['label_index'] as num?)?.toInt(),
      featureVectorDim: (result['feature_vector_dim'] as num?)?.toInt(),
      model: result['model'] as String?,
      risk: result['risk'] as String?,
      recommendation: result['recommendation'] as String?,
      screeningStatus: result['status'] as String?,
    );
  }
  String get ageLabel => ageYears == null || ageMonths == null
      ? 'Not recorded'
      : '$ageYears years $ageMonths months';
  static String value(double? v, String unit) =>
      v == null ? 'Not recorded' : '${v.toStringAsFixed(1)} $unit';
  DateTime get date => recordedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
  String get formattedAge => ageLabel;
  String get formattedHeight => value(heightCm, 'cm');
  String get formattedWeight => value(weightKg, 'kg');
  String get formattedBmi => value(bmi, '').trim();
  String get status => screeningStatus ?? prediction ?? 'Not recorded';
  bool get hasVitals =>
      ageYears != null ||
      ageMonths != null ||
      heightCm != null ||
      weightKg != null ||
      headCircumferenceCm != null ||
      waistCm != null ||
      muacCm != null ||
      gender != null;
}

class VitalsNotifier extends Notifier<List<VitalsRecord>> {
  String? _child;
  int _requestId = 0;
  @override
  List<VitalsRecord> build() => const [];

  Future<void> loadForChild(String childId, String token) async {
    if (_child != childId) state = const [];
    _child = childId;
    final requestId = ++_requestId;
    ref.read(vitalsHistoryErrorProvider.notifier).clear();
    late final List<Map<String, dynamic>> rows;
    try {
      rows = await ApiService.getScreeningHistory(childId, token);
    } catch (error) {
      ref.read(vitalsHistoryErrorProvider.notifier).set(error.toString());
      rethrow;
    }
    if (_child != childId || requestId != _requestId) return;
    state = rows.map(VitalsRecord.fromJson).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    VitalsRecord? latestWithVitals;
    for (final record in state) {
      if (record.hasVitals) {
        latestWithVitals = record;
        break;
      }
    }
    debugPrint(
        '[VITALS] History loaded for $childId: ${state.length} records; latest-with-vitals=${latestWithVitals?.recordedAt?.toIso8601String() ?? 'none'}');
  }

  Future<void> recordVitals(
      String childId, String token, Map<String, dynamic> data) async {
    if (_child != childId) state = const [];
    _child = childId;
    final saved = await ApiService.recordVitals(childId, token, data);
    if (_child != childId) return;

    // The POST response is the backend-confirmed MongoDB record. Show it
    // immediately so a separate history refresh cannot hide a successful save.
    final savedRecord = VitalsRecord.fromJson(saved);
    state = [
      savedRecord,
      ...state.where((record) => record.screeningId != savedRecord.screeningId),
    ]..sort((a, b) => b.date.compareTo(a.date));

    // Refresh the complete history, but retain the confirmed POST response if
    // this follow-up read fails. A failed write still throws before state changes.
    try {
      await loadForChild(childId, token);
    } catch (error) {
      debugPrint(
          '[VITALS] Saved record is confirmed; history refresh failed: $error');
    }
  }

  void addSavedScreening(Map<String, dynamic> json) {
    final savedRecord = VitalsRecord.fromJson(json);
    state = [savedRecord, ...state.where((r) => r.screeningId != savedRecord.screeningId)]
      ..sort((a, b) => b.date.compareTo(a.date));
  }
}

class VitalsHistoryErrorNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void set(String message) => state = message;
  void clear() => state = null;
}

final vitalsHistoryErrorProvider =
    NotifierProvider<VitalsHistoryErrorNotifier, String?>(VitalsHistoryErrorNotifier.new);

final vitalsProvider =
    NotifierProvider<VitalsNotifier, List<VitalsRecord>>(VitalsNotifier.new);

final latestVitalsProvider = Provider<VitalsRecord?>((ref) {
  for (final record in ref.watch(vitalsProvider)) {
    if (record.hasVitals) return record;
  }
  return null;
});

class ChildProfileImageController extends Notifier<Uint8List?> {
  @override
  Uint8List? build() => null;
  void setImage(Uint8List? image) => state = image;
}

final childProfileImageProvider =
    NotifierProvider<ChildProfileImageController, Uint8List?>(
        ChildProfileImageController.new);
