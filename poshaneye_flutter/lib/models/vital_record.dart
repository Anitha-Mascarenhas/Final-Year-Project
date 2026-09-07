class VitalRecord {
  final double weight;
  final double height;
  final double muac;
  final double? headCircumference; // nullable — not always recorded
  final String date;
  final double bmi;
  final String percentile;

  VitalRecord({
    required this.weight,
    required this.height,
    required this.muac,
    this.headCircumference,
    required this.date,
    required this.bmi,
    required this.percentile,
  });

  VitalRecord copyWith({
    double? weight,
    double? height,
    double? muac,
    double? headCircumference,
    bool clearHeadCircumference = false,
    String? date,
    double? bmi,
    String? percentile,
  }) {
    return VitalRecord(
      weight: weight ?? this.weight,
      height: height ?? this.height,
      muac: muac ?? this.muac,
      headCircumference: clearHeadCircumference ? null : (headCircumference ?? this.headCircumference),
      date: date ?? this.date,
      bmi: bmi ?? this.bmi,
      percentile: percentile ?? this.percentile,
    );
  }
}
