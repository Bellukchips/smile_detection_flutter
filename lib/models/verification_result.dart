import 'package:face_detection_local/models/user.dart';

class VerificationResult {
  final bool success;
  final UserModel? user;
  final double? confidence;
  final String? message;
  final DateTime timestamp;

  VerificationResult({
    required this.success,
    this.user,
    this.confidence,
    this.message,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  @override
  String toString() {
    if (success) {
      return 'Verified: ${user?.name} (${(confidence! * 100).toStringAsFixed(1)}%)';
    } else {
      return 'Failed: $message';
    }
  }
}
