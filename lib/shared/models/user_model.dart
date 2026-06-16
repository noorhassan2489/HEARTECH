import 'package:cloud_firestore/cloud_firestore.dart';

/// User model — covers HCW, Parent, and Teacher roles.
class UserModel {
  final String uid;
  final String email;
  final String role; // 'hcw', 'parent', 'teacher'
  final String name;
  final String? gender;
  final String? profilePhotoUrl;
  final DateTime createdAt;
  final DateTime? lastLoginAt;
  final List<String> linkedChildIds;
  final String? city;
  final String? country;
  final Map<String, bool> notificationPrefs;

  // HCW-only fields
  final bool? isVerified;
  final String? licenseNumber;
  final String? licenseDocUrl;
  final String? title; // Dr., Nurse, Audiologist, etc.
  final String? specialization;
  final String? hospitalName;

  // Teacher-only fields
  final String? schoolName;
  final List<String>? gradeLevelsTaught;
  final int? yearsExperience;

  // Parent-only fields
  final String? phone;
  final DateTime? dob;

  const UserModel({
    required this.uid,
    required this.email,
    required this.role,
    required this.name,
    this.gender,
    this.profilePhotoUrl,
    required this.createdAt,
    this.lastLoginAt,
    this.linkedChildIds = const [],
    this.city,
    this.country,
    this.notificationPrefs = const {},
    // HCW
    this.isVerified,
    this.licenseNumber,
    this.licenseDocUrl,
    this.title,
    this.specialization,
    this.hospitalName,
    // Teacher
    this.schoolName,
    this.gradeLevelsTaught,
    this.yearsExperience,
    // Parent
    this.phone,
    this.dob,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      uid: json['uid'] as String? ?? '',
      email: json['email'] as String? ?? '',
      role: json['role'] as String? ?? '',
      name: json['name'] as String? ?? '',
      gender: json['gender'] as String?,
      profilePhotoUrl: json['profilePhotoUrl'] as String?,
      createdAt: _parseTimestamp(json['createdAt']),
      lastLoginAt: json['lastLoginAt'] != null
          ? _parseTimestamp(json['lastLoginAt'])
          : null,
      linkedChildIds: List<String>.from(json['linkedChildIds'] ?? []),
      city: json['city'] as String?,
      country: json['country'] as String?,
      notificationPrefs:
          Map<String, bool>.from(json['notificationPrefs'] ?? {}),
      // HCW
      isVerified: json['isVerified'] as bool?,
      licenseNumber: json['licenseNumber'] as String?,
      licenseDocUrl: json['licenseDocUrl'] as String?,
      title: json['title'] as String?,
      specialization: json['specialization'] as String?,
      hospitalName: json['hospitalName'] as String?,
      // Teacher
      schoolName: json['schoolName'] as String?,
      gradeLevelsTaught: json['gradeLevelsTaught'] != null
          ? List<String>.from(json['gradeLevelsTaught'])
          : null,
      yearsExperience: json['yearsExperience'] as int?,
      // Parent
      phone: json['phone'] as String?,
      dob: json['dob'] != null ? _parseTimestamp(json['dob']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{
      'uid': uid,
      'email': email,
      'role': role,
      'name': name,
      'gender': gender,
      if (profilePhotoUrl != null && profilePhotoUrl!.isNotEmpty)
        'profilePhotoUrl': profilePhotoUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastLoginAt':
          lastLoginAt != null ? Timestamp.fromDate(lastLoginAt!) : null,
      'linkedChildIds': linkedChildIds,
      'city': city,
      'country': country,
      'notificationPrefs': notificationPrefs,
    };

    // HCW fields
    if (role == 'hcw') {
      data['isVerified'] = isVerified ?? false;
      data['licenseNumber'] = licenseNumber;
      if (licenseDocUrl != null && licenseDocUrl!.isNotEmpty) {
        data['licenseDocUrl'] = licenseDocUrl;
      }
      data['title'] = title;
      data['specialization'] = specialization;
      data['hospitalName'] = hospitalName;
    }

    // Teacher fields
    if (role == 'teacher') {
      data['schoolName'] = schoolName;
      data['gradeLevelsTaught'] = gradeLevelsTaught;
      data['yearsExperience'] = yearsExperience;
    }

    // Parent fields
    if (role == 'parent') {
      data['phone'] = phone;
      data['dob'] = dob != null ? Timestamp.fromDate(dob!) : null;
    }

    return data;
  }

  UserModel copyWith({
    String? uid,
    String? email,
    String? role,
    String? name,
    String? gender,
    String? profilePhotoUrl,
    DateTime? createdAt,
    DateTime? lastLoginAt,
    List<String>? linkedChildIds,
    String? city,
    String? country,
    Map<String, bool>? notificationPrefs,
    bool? isVerified,
    String? licenseNumber,
    String? licenseDocUrl,
    String? title,
    String? specialization,
    String? hospitalName,
    String? schoolName,
    List<String>? gradeLevelsTaught,
    int? yearsExperience,
    String? phone,
    DateTime? dob,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      role: role ?? this.role,
      name: name ?? this.name,
      gender: gender ?? this.gender,
      profilePhotoUrl: profilePhotoUrl ?? this.profilePhotoUrl,
      createdAt: createdAt ?? this.createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      linkedChildIds: linkedChildIds ?? this.linkedChildIds,
      city: city ?? this.city,
      country: country ?? this.country,
      notificationPrefs: notificationPrefs ?? this.notificationPrefs,
      isVerified: isVerified ?? this.isVerified,
      licenseNumber: licenseNumber ?? this.licenseNumber,
      licenseDocUrl: licenseDocUrl ?? this.licenseDocUrl,
      title: title ?? this.title,
      specialization: specialization ?? this.specialization,
      hospitalName: hospitalName ?? this.hospitalName,
      schoolName: schoolName ?? this.schoolName,
      gradeLevelsTaught: gradeLevelsTaught ?? this.gradeLevelsTaught,
      yearsExperience: yearsExperience ?? this.yearsExperience,
      phone: phone ?? this.phone,
      dob: dob ?? this.dob,
    );
  }

  /// Display name for the greeting
  String get firstName => name.split(' ').first;

  /// Returns true if user is an HCW
  bool get isHcw => role == 'hcw';
  bool get isParent => role == 'parent';
  bool get isTeacher => role == 'teacher';

  static DateTime _parseTimestamp(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.parse(value);
    return DateTime.now();
  }
}
