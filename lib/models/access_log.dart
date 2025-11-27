// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';

class AccessLogModel {
  final String id;
  final String? userId;
  final String? userName;
  final String? action;
  final double? confidenceScore;
  final String? photoPath;
  final DateTime timestamp;
  final String? reason;

  AccessLogModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.action,
    required this.confidenceScore,
    required this.photoPath,
    required this.timestamp,
    required this.reason,
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'user_id': userId,
      'user_name': userName,
      'action': action,
      'confidence_score': confidenceScore,
      'photo_path': photoPath,
      'timestamp': timestamp.toIso8601String(),
      'reason': reason,
    };
  }

  factory AccessLogModel.fromMap(Map<String, dynamic> map) {
    return AccessLogModel(
      id: map['id'] as String,
      userId: map['user_id'] != null ? map['user_id'] as String : null,
      userName: map['user_name'] != null ? map['user_name'] as String : null,
      action: map['action'] != null ? map['action'] as String : null,
      confidenceScore: map['confidence_score'] != null
          ? map['confidence_score'] as double
          : null,
      photoPath: map['photo_path'] != null ? map['photo_path'] as String : null,
      timestamp: DateTime.parse(map['timestamp'] as String),
      reason: map['reason'] != null ? map['reason'] as String : null,
    );
  }

  String toJson() => json.encode(toMap());

  factory AccessLogModel.fromJson(String source) =>
      AccessLogModel.fromMap(json.decode(source) as Map<String, dynamic>);

  AccessLogModel copyWith({
    String? id,
    String? userId,
    String? userName,
    String? action,
    double? confidenceScore,
    String? photoPath,
    DateTime? timestamp,
    String? reason,
  }) {
    return AccessLogModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      action: action ?? this.action,
      confidenceScore: confidenceScore ?? this.confidenceScore,
      photoPath: photoPath ?? this.photoPath,
      timestamp: timestamp ?? this.timestamp,
      reason: reason ?? this.reason,
    );
  }
}
