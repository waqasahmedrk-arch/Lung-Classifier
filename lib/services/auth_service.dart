import 'package:flutter/foundation.dart';

/// Simple in-memory auth service.
/// Replace the body of each method with your real backend calls (Firebase, REST, etc.)
class AuthService extends ChangeNotifier {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  bool _isLoggedIn = false;
  String? _userEmail;
  String? _userName;

  bool get isLoggedIn => _isLoggedIn;
  String? get userEmail => _userEmail;
  String? get userName => _userName;
  String get userInitials {
    if (_userName == null || _userName!.isEmpty) return '?';
    final parts = _userName!.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return _userName![0].toUpperCase();
  }

  /// Simulate login — replace with real auth
  Future<AuthResult> login(String email, String password) async {
    await Future.delayed(const Duration(milliseconds: 1500)); // simulate network

    if (email.isEmpty || password.isEmpty) {
      return AuthResult.error('Please fill in all fields.');
    }
    if (!email.contains('@')) {
      return AuthResult.error('Please enter a valid email address.');
    }
    if (password.length < 6) {
      return AuthResult.error('Password must be at least 6 characters.');
    }

    // ── Simulate success ───────────────────────────────────────────────────────
    _isLoggedIn = true;
    _userEmail = email;
    _userName = email.split('@')[0]; // derive name from email
    notifyListeners();
    return AuthResult.success();
  }

  /// Simulate signup — replace with real auth
  Future<AuthResult> signup(String name, String email, String password) async {
    await Future.delayed(const Duration(milliseconds: 1800));

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      return AuthResult.error('Please fill in all fields.');
    }
    if (!email.contains('@')) {
      return AuthResult.error('Please enter a valid email address.');
    }
    if (password.length < 6) {
      return AuthResult.error('Password must be at least 6 characters.');
    }

    _isLoggedIn = true;
    _userEmail = email;
    _userName = name;
    notifyListeners();
    return AuthResult.success();
  }

  /// Simulate forgot password — replace with real auth
  Future<AuthResult> forgotPassword(String email) async {
    await Future.delayed(const Duration(milliseconds: 1200));

    if (email.isEmpty || !email.contains('@')) {
      return AuthResult.error('Please enter a valid email address.');
    }

    return AuthResult.success(
      message: 'Reset link sent to $email',
    );
  }

  /// Logout
  void logout() {
    _isLoggedIn = false;
    _userEmail = null;
    _userName = null;
    notifyListeners();
  }
}

class AuthResult {
  final bool success;
  final String? error;
  final String? message;

  const AuthResult._({required this.success, this.error, this.message});

  factory AuthResult.success({String? message}) =>
      AuthResult._(success: true, message: message);

  factory AuthResult.error(String error) =>
      AuthResult._(success: false, error: error);
}
