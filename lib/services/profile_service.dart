import 'dart:async';

import 'api_client.dart';

class UserProfile {
  final String id;
  final String email;
  final String? username;
  final String fullName;
  final String? description;
  // Null or 'default' both mean the initials-gradient avatar - see the
  // backend's UserProfile.avatarId doc for why 'default' exists as an
  // explicit sentinel distinct from null.
  final String? avatarId;
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
    this.username,
    required this.fullName,
    this.description,
    this.avatarId,
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
      username: json['username'] as String?,
      fullName: json['fullName'] as String? ?? '',
      description: json['description'] as String?,
      avatarId: json['avatarId'] as String?,
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
      'username': username,
      'fullName': fullName,
      'description': description,
      'avatarId': avatarId,
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
    String? username,
    String? fullName,
    String? description,
    String? avatarId,
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
      username: username ?? this.username,
      fullName: fullName ?? this.fullName,
      description: description ?? this.description,
      avatarId: avatarId ?? this.avatarId,
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

  /// Save or update the user's profile. Rethrows [ApiException] (unlike most
  /// services here) rather than collapsing to a bool - a username collision
  /// carries a real, user-relevant message (see [ProfileController]'s
  /// `message` body on 400) worth showing as-is, not a generic failure.
  Future<void> saveProfile(UserProfile profile) async {
    await _api.put('/profile', data: profile.toJson());
    if (!_updatesController.isClosed) {
      _updatesController.add(profile);
    }
  }

  /// Check if the current user has completed their profile.
  Future<bool> isProfileCompleted() async {
    final profile = await fetchProfile();
    return profile?.profileCompleted ?? false;
  }

  /// Whether a just-signed-in user should be routed straight to the
  /// dashboard rather than profile-setup. Fails open (returns true, i.e.
  /// skip profile-setup) if the profile can't be fetched at all - a
  /// network blip right after sign-in is far less disruptive than wrongly
  /// bouncing an already-complete returning user back into profile-setup.
  Future<bool> shouldSkipProfileSetup() async {
    try {
      final data = await _api.get('/profile');
      return UserProfile.fromJson(data).profileCompleted;
    } on ApiException {
      return true;
    }
  }
}
