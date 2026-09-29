class PredictionResult {
  final String prediction;
  final double? confidence;
  final Map<String, double> probabilities;
  final String status;
  final String? risk;
  final String? recommendation;

  PredictionResult({
    required this.prediction,
    required this.confidence,
    required this.probabilities,
    required this.status,
    required this.risk,
    required this.recommendation,
  });

  factory PredictionResult.fromJson(Map<String, dynamic> json) {
    final rawProbabilities = json['probabilities'] as Map<String, dynamic>? ?? {};
    final parsedProbabilities = <String, double>{};
    rawProbabilities.forEach((key, value) {
      parsedProbabilities[key] = (value as num).toDouble();
    });

    final pred = json['prediction'] as String? ?? '';

    return PredictionResult(
      prediction: pred,
      confidence: (json['confidence'] as num?)?.toDouble(),
      probabilities: parsedProbabilities,
      status: json['status'] as String? ?? _capitalize(pred),
      risk: json['risk'] as String?,
      recommendation: json['recommendation'] as String?,
    );
  }

  static String _capitalize(String text) {
    if (text.isEmpty) return text;
    return '${text[0].toUpperCase()}${text.substring(1)}';
  }

  Map<String, dynamic> toJson() {
    return {
      'prediction': prediction,
      if (confidence != null) 'confidence': confidence,
      'probabilities': probabilities,
      'status': status,
      if (risk != null) 'risk': risk,
      if (recommendation != null) 'recommendation': recommendation,
    };
  }
}

extension StringCapitalizeExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}

