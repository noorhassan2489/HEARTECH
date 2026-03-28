import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final String role; // 'hcw', 'parent', 'teacher'
  final String name;
  final String gender;
  final String profilePhotoUrl;
  final DateTime createdAt;
  final DateTime lastLoginAt;
  final List<String> linkedChildIds;
  final Map<String, dynamic> location; // {city: string, country: string}
  final Map<String, dynamic> notificationPrefs; // key: string, value: bool

  // HCW specific
  final bool? isVerified;
  final String? licenseNumber;
  final String? licenseDocUrl;
  final String? title;
  final String? specialization;
  final String? hospitalName;

  // Teacher specific
  final String? schoolName;
  final List<String>? gradeLevelsTaught;
  final int? yearsExperience;

  UserModel({
    required this.uid,
    required this.email,
    required this.role,
    required this.name,
    required this.gender,
    required this.profilePhotoUrl,
    required this.createdAt,
    required this.lastLoginAt,
    required this.linkedChildIds,
    required this.location,
    required this.notificationPrefs,
    this.isVerified,
    this.licenseNumber,
    this.licenseDocUrl,
    this.title,
    this.specialization,
    this.hospitalName,
    this.schoolName,
    this.gradeLevelsTaught,
    this.yearsExperience,
  });

  factory UserModel.fromMap(Map<String, dynamic> map, String documentId) {
    return UserModel(
      uid: documentId,
      email: map['email'] ?? '',
      role: map['role'] ?? 'parent',
      name: map['name'] ?? '',
      gender: map['gender'] ?? '',
      profilePhotoUrl: map['profilePhotoUrl'] ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastLoginAt: (map['lastLoginAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      linkedChildIds: List<String>.from(map['linkedChildIds'] ?? []),
      location: Map<String, dynamic>.from(map['location'] ?? {}),
      notificationPrefs: Map<String, dynamic>.from(map['notificationPrefs'] ?? {}),
      isVerified: map['isVerified'],
      licenseNumber: map['licenseNumber'],
      licenseDocUrl: map['licenseDocUrl'],
      title: map['title'],
      specialization: map['specialization'],
      hospitalName: map['hospitalName'],
      schoolName: map['schoolName'],
      gradeLevelsTaught: map['gradeLevelsTaught'] != null ? List<String>.from(map['gradeLevelsTaught']) : null,
      yearsExperience: map['yearsExperience'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'role': role,
      'name': name,
      'gender': gender,
      'profilePhotoUrl': profilePhotoUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastLoginAt': Timestamp.fromDate(lastLoginAt),
      'linkedChildIds': linkedChildIds,
      'location': location,
      'notificationPrefs': notificationPrefs,
      if (isVerified != null) 'isVerified': isVerified,
      if (licenseNumber != null) 'licenseNumber': licenseNumber,
      if (licenseDocUrl != null) 'licenseDocUrl': licenseDocUrl,
      if (title != null) 'title': title,
      if (specialization != null) 'specialization': specialization,
      if (hospitalName != null) 'hospitalName': hospitalName,
      if (schoolName != null) 'schoolName': schoolName,
      if (gradeLevelsTaught != null) 'gradeLevelsTaught': gradeLevelsTaught,
      if (yearsExperience != null) 'yearsExperience': yearsExperience,
    };
  }
}
