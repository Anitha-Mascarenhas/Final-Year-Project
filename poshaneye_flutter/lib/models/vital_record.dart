class VitalRecord {
  final double weight;
  final double height;
  final double muac;
  final double? headCircumference; // nullable — not always recorded
  final double? waistCircumference; // reserved for the hybrid model's waist slot
  final String date;
  final double bmi;
  final String percentile;

  VitalRecord({
    required this.weight,
    required this.height,
    required this.muac,
    this.headCircumference,
    this.waistCircumference,
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
    double? waistCircumference,
    bool clearWaistCircumference = false,
    String? date,
    double? bmi,
    String? percentile,
  }) {
    return VitalRecord(
      weight: weight ?? this.weight,
      height: height ?? this.height,
      muac: muac ?? this.muac,
      headCircumference: clearHeadCircumference ? null : (headCircumference ?? this.headCircumference),
      waistCircumference: clearWaistCircumference ? null : (waistCircumference ?? this.waistCircumference),
      date: date ?? this.date,
      bmi: bmi ?? this.bmi,
      percentile: percentile ?? this.percentile,
    );
  }
}
