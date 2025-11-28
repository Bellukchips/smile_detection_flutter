import 'dart:convert';

// ignore_for_file: public_member_api_docs, sort_constructors_first

class UserModel {
  final String id;
  final String name;
  final String employeeId;
  final String department;
  final List<double> faceEmbedding;
  final String photoPath;
  final DateTime createdAt;
  final bool isActive;

  UserModel({
    required this.id,
    required this.name,
    required this.employeeId,
    required this.department,
    required this.faceEmbedding,
    required this.photoPath,
    required this.createdAt,
    required this.isActive,
  });

  UserModel copyWith({
    String? id,
    String? name,
    String? employeeId,
    String? department,
    List<double>? faceEmbedding,
    String? photoPath,
    DateTime? createdAt,
    bool? isActive,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      employeeId: employeeId ?? this.employeeId,
      department: department ?? this.department,
      faceEmbedding: faceEmbedding ?? this.faceEmbedding,
      photoPath: photoPath ?? this.photoPath,
      createdAt: createdAt ?? this.createdAt,
      isActive: isActive ?? this.isActive,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'employee_id': employeeId,
      'department': department,
      'face_embedding': faceEmbedding,
      'photo_path': photoPath,
      'created_at': createdAt.toIso8601String(),
      'is_active': isActive ? 1 : 0,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] as String,
      name: map['name'] as String,
      employeeId: map['employee_id'] as String,
      department: map['department'] as String,
      faceEmbedding: (map['face_embedding'] as String)
          .split(',')
          .map((e) => double.parse(e.trim()))
          .toList(),
      photoPath: map['photo_path'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      isActive: map['is_active'] as bool,
    );
  }

  String toJson() => json.encode(toMap());

  factory UserModel.fromJson(String source) =>
      UserModel.fromMap(json.decode(source) as Map<String, dynamic>);
}
