import '../widgets/child_id_dialog.dart';

/// Runs parent registration and accepts only the Child ID assigned by the API.
Future<String> registerParentAndReadChildId({
  required Future<Map<String, dynamic>> Function() register,
}) async {
  final response = await register();
  final childId = response['childId']?.toString().trim();
  if (!isValidChildId(childId)) {
    throw const FormatException(
      'The server did not return a valid assigned Child ID.',
    );
  }
  return childId!;
}
