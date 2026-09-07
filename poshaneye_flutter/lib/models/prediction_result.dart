class PredictionResult {
  final String prediction;
  final double confidence;
  final Map<String, double> probabilities;
  final DateTime scanTimestamp;

  const PredictionResult({
    required this.prediction,
    required this.confidence,
    required this.probabilities,
    required this.scanTimestamp,
  });

  factory PredictionResult.fromJson(Map<String, dynamic> json) {
    final probs = json['probabilities'] as Map<String, dynamic>;
    return PredictionResult(
      prediction: json['prediction'] as String,
      confidence: (json['confidence'] as num).toDouble(),
      probabilities: probs.map(
        (key, value) => MapEntry(key, (value as num).toDouble()),
      ),
      scanTimestamp: DateTime.now(),
    );
  }
}
