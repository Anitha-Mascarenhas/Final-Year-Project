import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class VitalsRecord {
  final String id;
  final String childName;
  final String gender;
  final int ageYears;
  final int ageMonths;
  final double weight;
  final double height;
  final double bmi;
  final String status;
  final DateTime date;

  VitalsRecord({
    required this.id,
    required this.childName,
    required this.gender,
    required this.ageYears,
    required this.ageMonths,
    required this.weight,
    required this.height,
    required this.bmi,
    required this.status,
    required this.date,
  });

  String get formattedAge => '${ageYears}y ${ageMonths}m';
  String get formattedWeight => '${weight.toStringAsFixed(1)} kg';
  String get formattedHeight => '${height.toStringAsFixed(1)} cm';
  String get formattedBmi => bmi.toStringAsFixed(1);
}

class VitalsNotifier extends Notifier<List<VitalsRecord>> {
  @override
  List<VitalsRecord> build() {
    return [
      VitalsRecord(
        id: '1',
        childName: 'Aarav',
        gender: 'Boy',
        ageYears: 2,
        ageMonths: 3,
        weight: 14.2,
        height: 92.5,
        bmi: 16.6,
        status: 'On Track',
        date: DateTime.now().subtract(const Duration(minutes: 15)),
      ),
      VitalsRecord(
        id: '2',
        childName: 'Aarav',
        gender: 'Boy',
        ageYears: 2,
        ageMonths: 2,
        weight: 14.0,
        height: 88.0,
        bmi: 18.1,
        status: 'On Track',
        date: DateTime.now().subtract(const Duration(days: 30)),
      ),
      VitalsRecord(
        id: '3',
        childName: 'Aarav',
        gender: 'Boy',
        ageYears: 1,
        ageMonths: 11,
        weight: 13.2,
        height: 85.5,
        bmi: 18.1,
        status: 'Healthy',
        date: DateTime.now().subtract(const Duration(days: 90)),
      ),
    ];
  }

  void addRecord({
    required String childName,
    required String gender,
    required int ageYears,
    required int ageMonths,
    required double weight,
    required double height,
    String status = 'On Track',
  }) {
    final heightInMeters = height / 100.0;
    final bmi = (heightInMeters > 0) ? (weight / (heightInMeters * heightInMeters)) : 0.0;

    final record = VitalsRecord(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      childName: childName,
      gender: gender,
      ageYears: ageYears,
      ageMonths: ageMonths,
      weight: weight,
      height: height,
      bmi: bmi,
      status: status,
      date: DateTime.now(),
    );

    state = [record, ...state];
  }
}

final vitalsProvider = NotifierProvider<VitalsNotifier, List<VitalsRecord>>(
  VitalsNotifier.new,
);

class ChildImageNotifier extends Notifier<Uint8List?> {
  @override
  Uint8List? build() => null;

  void setImage(Uint8List? bytes) {
    state = bytes;
  }
}

final childProfileImageProvider =
    NotifierProvider<ChildImageNotifier, Uint8List?>(
  ChildImageNotifier.new,
);
