import 'dart:async';

import 'api_client.dart';

class UserProfile {
  final String id;
  final String email;
  final String fullName;
  final int? age;
  final double? weightKg;
  final double? heightCm;
  final String? gender;
  final bool profileCompleted;
  final int? stepGoal;
  final int? activeMinutesGoal;
  final int? calorieGoal;

  UserProfile({
    required this.id,
    required this.email,
    required this.fullName,
    this.age,
    this.weightKg,
    this.heightCm,
    this.gender,
    required this.profileCompleted,
    this.stepGoal,
    this.activeMinutesGoal,
    this.calorieGoal,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String? ?? '',
      email: json['email'] as String? ?? '',
      fullName: json['fullName'] as String? ?? '',
      age: json['age'] as int?,
      weightKg: (json['weightKg'] as num?)?.toDouble(),
      heightCm: (json['heightCm'] as num?)?.toDouble(),
      gender: json['gender'] as String?,
      profileCompleted: json['profileCompleted'] as bool? ?? false,
      stepGoal: json['stepGoal'] as int?,
      activeMinutesGoal: json['activeMinutesGoal'] as int?,
      calorieGoal: json['calorieGoal'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'fullName': fullName,
      'age': age,
      'weightKg': weightKg,
      'heightCm': heightCm,
      'gender': gender,
      'profileCompleted': profileCompleted,
      'stepGoal': stepGoal,
      'activeMinutesGoal': activeMinutesGoal,
      'calorieGoal': calorieGoal,
    };
  }

  UserProfile copyWith({
    String? fullName,
    int? age,
    double? weightKg,
    double? heightCm,
    String? gender,
    bool? profileCompleted,
    int? stepGoal,
    int? activeMinutesGoal,
    int? calorieGoal,
  }) {
    return UserProfile(
      id: id,
      email: email,
      fullName: fullName ?? this.fullName,
      age: age ?? this.age,
      weightKg: weightKg ?? this.weightKg,
      heightCm: heightCm ?? this.heightCm,
      gender: gender ?? this.gender,
      profileCompleted: profileCompleted ?? this.profileCompleted,
      stepGoal: stepGoal ?? this.stepGoal,
      activeMinutesGoal: activeMinutesGoal ?? this.activeMinutesGoal,
      calorieGoal: calorieGoal ?? this.calorieGoal,
    );
  }
}

class ProfileService {
  static ProfileService? _instance;
  static ProfileService get instance => _instance ??= ProfileService._();
  ProfileService._();

  final _api = ApiClient.instance;
  final _updatesController = StreamController<UserProfile>.broadcast();

  /// Emits whenever [saveProfile] succeeds, so screens that cache a profile
  /// (e.g. the dashboard, for goals) can stay in sync with ones that edit it
  /// (e.g. Settings) without needing to re-fetch on every visit. Necessary
  /// because `StatefulShellRoute.indexedStack` keeps every tab's State alive
  /// across tab switches - a one-time fetch in `initState` never runs again
  /// just from navigating back to that tab, so it would otherwise show a
  /// stale profile until the app is fully restarted.
  Stream<UserProfile> get profileUpdates => _updatesController.stream;

  /// Fetch the current user's profile.
  Future<UserProfile?> fetchProfile() async {
    try {
      final data = await _api.get('/profile');
      return UserProfile.fromJson(data);
    } on ApiException {
      return null;
    }
  }

  /// Save or update the user's profile.
  Future<bool> saveProfile(UserProfile profile) async {
    try {
      await _api.put('/profile', data: profile.toJson());
      if (!_updatesController.isClosed) {
        _updatesController.add(profile);
      }
      return true;
    } on ApiException {
      return false;
    }
  }

  /// Check if the current user has completed their profile.
  Future<bool> isProfileCompleted() async {
    final profile = await fetchProfile();
    return profile?.profileCompleted ?? false;
  }
}
