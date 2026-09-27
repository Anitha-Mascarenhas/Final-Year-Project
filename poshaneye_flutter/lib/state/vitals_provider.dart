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
      this.recordedAt});

  static double? _number(dynamic v) => v is num ? v.toDouble() : null;
  factory VitalsRecord.fromJson(Map<String, dynamic> json) {
    final v = (json['vitals'] as Map?)?.cast<String, dynamic>() ?? {};
    DateTime? date;
    try {
      date = DateTime.parse((v['recorded_at'] ?? json['createdAt']).toString());
    } catch (_) {}
    return VitalsRecord(
      screeningId: '${json['screeningId'] ?? ''}',
      childId: '${json['childId'] ?? ''}',
      ageYears: (v['age_years'] as num?)?.toInt(),
      ageMonths: (v['age_months'] as num?)?.toInt(),
      heightCm: _number(v['height_cm']),
      weightKg: _number(v['weight_kg']),
      headCircumferenceCm: _number(v['head_circumference_cm']),
      waistCm: _number(v['waist_cm']),
      muacCm: _number(v['muac_cm']),
      bmi: _number(v['bmi']),
      gender: v['gender'] as String?,
      prediction: json['prediction'] as String?,
      confidence: _number(json['confidence']),
      recordedAt: date,
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
  String get status => prediction ?? 'Not recorded';
  String? get risk => null;
  String? get recommendation => null;
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
    final rows = await ApiService.getScreeningHistory(childId, token);
    if (_child != childId || requestId != _requestId) return;
    state = rows.map(VitalsRecord.fromJson).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
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
}

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
