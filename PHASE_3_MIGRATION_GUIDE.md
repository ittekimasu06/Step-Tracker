# Phase 3: Flutter Frontend Migration Guide

> **Superseded (2026-09-01).** This guide was written before Phase 3 was implemented and
> was never verified against the real backend - its `register`/`login` examples check for
> HTTP 200, but the backend returns 201 for registration, and it uses the `http` package
> rather than `dio` (already a project dependency). The code that actually shipped lives
> in `lib/services/api_client.dart`, `auth_service.dart`, `profile_service.dart`, and
> `providers/auth_provider.dart`; see the "Phase 3" section of `PROJECT_STATUS_REPORT.md`
> for what was built, why, and how it was verified. Kept here for history only - don't
> copy code from below.

## Migrate from Supabase to Spring Boot Backend

This guide walks through updating Flutter services to use the new Spring Boot + PostgreSQL backend instead of Supabase.

---

## Step 1: Create API Service

Create `lib/services/api_service.dart`:

```dart
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiService {
  static const String baseUrl = 'http://localhost:8080/api'; // Change for production
  static const String _tokenKey = 'auth_token';
  
  final _storage = const FlutterSecureStorage();
  
  // Set token after login/register
  Future<void> saveToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
  }
  
  // Get stored token
  Future<String?> getToken() async {
    return await _storage.read(key: _tokenKey);
  }
  
  // Clear token on logout
  Future<void> clearToken() async {
    await _storage.delete(key: _tokenKey);
  }
  
  // Helper method for authenticated requests
  Future<http.Response> _authenticatedRequest(
    String method,
    String endpoint, {
    String? body,
  }) async {
    final token = await getToken();
    final headers = {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
    
    final url = Uri.parse('$baseUrl$endpoint');
    
    try {
      http.Response response;
      switch (method) {
        case 'GET':
          response = await http.get(url, headers: headers);
          break;
        case 'POST':
          response = await http.post(url, headers: headers, body: body);
          break;
        case 'PUT':
          response = await http.put(url, headers: headers, body: body);
          break;
        default:
          throw Exception('Unsupported HTTP method: $method');
      }
      
      return response;
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }
  
  // ==================== AUTH ENDPOINTS ====================
  
  /// Register new user
  Future<String> register({
    required String email,
    required String password,
    required String passwordConfirm,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
        'passwordConfirm': passwordConfirm,
      }),
    );
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final token = data['token'];
      await saveToken(token);
      return token;
    } else {
      final error = jsonDecode(response.body)['message'] ?? 'Registration failed';
      throw Exception(error);
    }
  }
  
  /// Login with email and password
  Future<String> login({
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
      }),
    );
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final token = data['token'];
      await saveToken(token);
      return token;
    } else {
      final error = jsonDecode(response.body)['message'] ?? 'Login failed';
      throw Exception(error);
    }
  }
  
  /// Login with Google ID token
  Future<String> loginWithGoogle(String idToken) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/google'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'idToken': idToken,
      }),
    );
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final token = data['token'];
      await saveToken(token);
      return token;
    } else {
      final error = jsonDecode(response.body)['message'] ?? 'Google login failed';
      throw Exception(error);
    }
  }
  
  /// Logout (client-side - just clear token)
  Future<void> logout() async {
    await clearToken();
  }
  
  // ==================== PROFILE ENDPOINTS ====================
  
  /// Get current user's profile
  Future<Map<String, dynamic>> getProfile() async {
    final response = await _authenticatedRequest('GET', '/profile');
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else if (response.statusCode == 401) {
      throw Exception('Unauthorized - please login again');
    } else if (response.statusCode == 404) {
      throw Exception('Profile not found');
    } else {
      throw Exception('Failed to fetch profile');
    }
  }
  
  /// Update user profile
  Future<Map<String, dynamic>> updateProfile({
    required String? fullName,
    required int? age,
    required double? weightKg,
    required double? heightCm,
    required String? gender,
    required bool? profileCompleted,
  }) async {
    final body = jsonEncode({
      if (fullName != null) 'fullName': fullName,
      if (age != null) 'age': age,
      if (weightKg != null) 'weightKg': weightKg,
      if (heightCm != null) 'heightCm': heightCm,
      if (gender != null) 'gender': gender,
      if (profileCompleted != null) 'profileCompleted': profileCompleted,
    });
    
    final response = await _authenticatedRequest('PUT', '/profile', body: body);
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else if (response.statusCode == 401) {
      throw Exception('Unauthorized - please login again');
    } else if (response.statusCode == 400) {
      throw Exception('Invalid profile data');
    } else {
      throw Exception('Failed to update profile');
    }
  }
}
```

---

## Step 2: Update AuthService

Replace `lib/services/auth_service.dart`:

```dart
import 'api_service.dart';
import '../models/user.dart'; // Create if needed

class AuthService {
  final ApiService _apiService = ApiService();
  
  /// Register new user
  Future<User> signUpWithEmail({
    required String email,
    required String password,
    required String passwordConfirm,
  }) async {
    try {
      final token = await _apiService.register(
        email: email,
        password: password,
        passwordConfirm: passwordConfirm,
      );
      
      return User(
        id: email, // Use email as temp ID, fetch actual profile later
        email: email,
        token: token,
      );
    } catch (e) {
      throw Exception('Registration failed: $e');
    }
  }
  
  /// Login with email and password
  Future<User> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final token = await _apiService.login(
        email: email,
        password: password,
      );
      
      return User(
        id: email,
        email: email,
        token: token,
      );
    } catch (e) {
      throw Exception('Login failed: $e');
    }
  }
  
  /// Login with Google
  Future<User> signInWithGoogle(String idToken) async {
    try {
      final token = await _apiService.loginWithGoogle(idToken);
      
      // Token contains email in payload, can be decoded if needed
      return User(
        id: 'google_user', // Update with actual email from token if available
        email: 'user@example.com', // Fetch from profile endpoint
        token: token,
      );
    } catch (e) {
      throw Exception('Google sign in failed: $e');
    }
  }
  
  /// Logout
  Future<void> signOut() async {
    try {
      await _apiService.logout();
    } catch (e) {
      throw Exception('Logout failed: $e');
    }
  }
  
  /// Get current token
  Future<String?> getToken() async {
    return await _apiService.getToken();
  }
}
```

---

## Step 3: Update ProfileService

Replace `lib/services/profile_service.dart`:

```dart
import 'api_service.dart';
import '../models/user_profile.dart';

class ProfileService {
  final ApiService _apiService = ApiService();
  
  /// Fetch user profile
  Future<UserProfile> fetchProfile() async {
    try {
      final data = await _apiService.getProfile();
      return UserProfile.fromJson(data);
    } catch (e) {
      throw Exception('Failed to fetch profile: $e');
    }
  }
  
  /// Update user profile
  Future<UserProfile> saveProfile(UserProfile profile) async {
    try {
      final data = await _apiService.updateProfile(
        fullName: profile.fullName,
        age: profile.age,
        weightKg: profile.weightKg,
        heightCm: profile.heightCm,
        gender: profile.gender,
        profileCompleted: profile.profileCompleted,
      );
      return UserProfile.fromJson(data);
    } catch (e) {
      throw Exception('Failed to save profile: $e');
    }
  }
}
```

---

## Step 4: Update AuthProvider (State Management)

Replace `lib/providers/auth_provider.dart`:

```dart
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../models/user.dart';
import 'dart:convert';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final ApiService _apiService = ApiService();
  
  User? _currentUser;
  bool _isLoading = false;
  String? _error;
  
  User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _currentUser != null;
  
  AuthProvider() {
    _initializeUser();
  }
  
  /// Initialize user from stored token
  Future<void> _initializeUser() async {
    try {
      final token = await _apiService.getToken();
      if (token != null) {
        // Decode JWT to get email (basic JWT decode)
        _currentUser = User(
          id: 'user',
          email: _extractEmailFromToken(token),
          token: token,
        );
        notifyListeners();
      }
    } catch (e) {
      _error = 'Failed to initialize user: $e';
    }
  }
  
  /// Extract email from JWT token (basic decode)
  String _extractEmailFromToken(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return 'unknown';
      
      final payload = parts[1];
      // Add padding if needed
      final normalized = payload.replaceAll('-', '+').replaceAll('_', '/');
      final decoded = utf8.decode(base64Url.decode(normalized));
      final json = jsonDecode(decoded);
      return json['sub'] ?? 'unknown'; // 'sub' is email in our JWT
    } catch (e) {
      return 'unknown';
    }
  }
  
  /// Register new user
  Future<void> register({
    required String email,
    required String password,
    required String passwordConfirm,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      _currentUser = await _authService.signUpWithEmail(
        email: email,
        password: password,
        passwordConfirm: passwordConfirm,
      );
      _error = null;
    } catch (e) {
      _error = e.toString();
      _currentUser = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  /// Login user
  Future<void> login({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      _currentUser = await _authService.signInWithEmail(
        email: email,
        password: password,
      );
      _error = null;
    } catch (e) {
      _error = e.toString();
      _currentUser = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  /// Login with Google
  Future<void> loginWithGoogle(String idToken) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      _currentUser = await _authService.signInWithGoogle(idToken);
      _error = null;
    } catch (e) {
      _error = e.toString();
      _currentUser = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  /// Logout user
  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();
    
    try {
      await _authService.signOut();
      _currentUser = null;
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
```

---

## Step 5: Update pubspec.yaml

Add required dependencies:

```yaml
dependencies:
  flutter:
    sdk: flutter
  http: ^1.1.0
  flutter_secure_storage: ^9.0.0
  # ... other dependencies
```

Then run:
```bash
flutter pub get
```

---

## Step 6: Update Models (if needed)

Ensure your `User` and `UserProfile` models have `fromJson` methods:

### `lib/models/user.dart`
```dart
class User {
  final String id;
  final String email;
  final String? token;
  
  User({
    required this.id,
    required this.email,
    this.token,
  });
}
```

### `lib/models/user_profile.dart`
```dart
class UserProfile {
  final String? id;
  final String? email;
  final String? fullName;
  final int? age;
  final double? weightKg;
  final double? heightCm;
  final String? gender;
  final bool? profileCompleted;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  
  UserProfile({
    this.id,
    this.email,
    this.fullName,
    this.age,
    this.weightKg,
    this.heightCm,
    this.gender,
    this.profileCompleted,
    this.createdAt,
    this.updatedAt,
  });
  
  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'],
      email: json['email'],
      fullName: json['fullName'],
      age: json['age'],
      weightKg: (json['weightKg'] as num?)?.toDouble(),
      heightCm: (json['heightCm'] as num?)?.toDouble(),
      gender: json['gender'],
      profileCompleted: json['profileCompleted'],
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
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
    };
  }
}
```

---

## Step 7: Update Screens (Reference)

### LoginScreen Changes
```dart
// Replace Supabase calls with:
context.read<AuthProvider>().login(
  email: emailController.text,
  password: passwordController.text,
);
```

### RegisterScreen Changes
```dart
// Replace Supabase calls with:
context.read<AuthProvider>().register(
  email: emailController.text,
  password: passwordController.text,
  passwordConfirm: confirmController.text,
);
```

### ProfileScreen Changes
```dart
// Replace Supabase calls with:
final profileService = ProfileService();
final profile = await profileService.fetchProfile();

// Update:
await profileService.saveProfile(updatedProfile);
```

---

## Configuration

### Update API Base URL

For **development**:
```dart
static const String baseUrl = 'http://localhost:8080/api';
```

For **production**, update `api_service.dart`:
```dart
static const String baseUrl = 'https://your-production-domain.com/api';
```

---

## Testing Checklist

- [ ] Backend running on `http://localhost:8080/api`
- [ ] POST `/auth/register` returns JWT token
- [ ] POST `/auth/login` returns JWT token
- [ ] GET `/profile` with Bearer token returns profile
- [ ] PUT `/profile` updates user data
- [ ] POST `/auth/google` accepts valid Google tokens
- [ ] Flutter app stores/retrieves JWT tokens
- [ ] Authenticated requests include Authorization header
- [ ] Token refresh works (if implementing)
- [ ] Logout clears stored token

---

## Troubleshooting

### CORS Errors
Backend must allow Flutter's origin. Update `SecurityConfig.java`:
```java
configuration.setAllowedOrigins(Arrays.asList(
    "http://localhost:3000",
    "http://localhost:8081",
    "http://localhost:8080",
    "http://192.168.x.x:8080" // For device testing
));
```

### Token Not Sent
Ensure `AuthService` calls include Bearer token header in `_authenticatedRequest`.

### Profile Not Found
Call `/profile` endpoint first after login to create default profile if needed.

### Google Login Issues
- Verify Google Client ID in backend `application.properties`
- Ensure Flutter sends valid Google ID token
- Check token hasn't expired

---

## Backend Endpoints Summary

| Method | Endpoint | Auth | Purpose |
|--------|----------|------|---------|
| POST | `/auth/register` | No | Create new user |
| POST | `/auth/login` | No | Login with credentials |
| POST | `/auth/google` | No | Google OAuth login |
| GET | `/profile` | Yes | Get user profile |
| PUT | `/profile` | Yes | Update user profile |
| GET | `/health` | No | Health check |

---

## Next Steps After Migration

1. **Test all endpoints** with both web and mobile clients
2. **Implement token refresh** if needed (add refresh token support)
3. **Add analytics endpoints** (Phase 4)
4. **Deploy backend** to production server
5. **Update Flutter** app backend URL for production
