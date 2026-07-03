import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserModel {
  final String uid;
  final String name;
  final String phone;
  final String role;
  final String city;
  final bool isVerified;
  final String? licenseNumber;
  final String? ngoType;

  UserModel({
    required this.uid,
    required this.name,
    required this.phone,
    required this.role,
    this.city = '',
    this.isVerified = true,
    this.licenseNumber,
    this.ngoType,
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid']?.toString() ?? '',
      name: map['name']?.toString() ?? 'Anonymous User',
      phone: map['phone']?.toString() ?? '',
      role: (map['role']?.toString() ?? 'donor').toLowerCase(),
      city: map['city']?.toString() ?? '',
      isVerified: map['isVerified'] == true,
      licenseNumber: map['licenseNumber']?.toString(),
      ngoType: map['ngoType']?.toString(),
    );
  }
}

/// Global session state, persisted locally so users aren't forced to
/// re-verify OTP on every app launch.
///
/// Named AppAuthProvider (not AuthProvider) because firebase_auth already
/// exports its own abstract class called AuthProvider, and importing both
/// in the same file causes an "ambiguous_import" error.
class AppAuthProvider extends ChangeNotifier {
  UserModel? _currentUser;
  bool _isRestoring = true;

  UserModel? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  bool get isRestoring => _isRestoring;

  static const _kUid = 'session_uid';
  static const _kName = 'session_name';
  static const _kPhone = 'session_phone';
  static const _kRole = 'session_role';
  static const _kCity = 'session_city';
  static const _kIsVerified = 'session_isVerified';

  Future<void> loadSession() async {
    _isRestoring = true;
    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getString(_kUid);
    final phone = prefs.getString(_kPhone);

    if (uid != null && phone != null) {
      _currentUser = UserModel(
        uid: uid,
        name: prefs.getString(_kName) ?? 'Anonymous User',
        phone: phone,
        role: prefs.getString(_kRole) ?? 'donor',
        city: prefs.getString(_kCity) ?? '',
        isVerified: prefs.getBool(_kIsVerified) ?? true,
      );
    }
    _isRestoring = false;
    notifyListeners();
  }

  Future<void> setUser(UserModel user) async {
    _currentUser = user;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kUid, user.uid);
    await prefs.setString(_kName, user.name);
    await prefs.setString(_kPhone, user.phone);
    await prefs.setString(_kRole, user.role);
    await prefs.setString(_kCity, user.city);
    await prefs.setBool(_kIsVerified, user.isVerified);
    notifyListeners();
  }

  Future<void> logout() async {
    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    notifyListeners();
  }
}