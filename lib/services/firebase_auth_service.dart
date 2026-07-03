import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

import '../../../core/config/auth_config.dart';

class OtpSendResult {
  final bool success;
  final String? errorMessage;
  final String? demoOtp;
  final int? cooldownSecondsRemaining;

  OtpSendResult.ok({this.demoOtp})
      : success = true,
        errorMessage = null,
        cooldownSecondsRemaining = null;

  OtpSendResult.cooldown(this.cooldownSecondsRemaining)
      : success = false,
        errorMessage = 'Please wait before requesting another code.',
        demoOtp = null;

  OtpSendResult.error(this.errorMessage)
      : success = false,
        demoOtp = null,
        cooldownSecondsRemaining = null;
}

class OtpVerifyResult {
  final bool success;
  final String? errorMessage;
  final String? uid;

  OtpVerifyResult.ok(this.uid)
      : success = true,
        errorMessage = null;

  OtpVerifyResult.error(this.errorMessage)
      : success = false,
        uid = null;
}

class FirebaseAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  static const String _otpNode = 'otp_requests';
  static const String _usersNode = 'users';

  Future<OtpSendResult> sendOtp({required String phoneNumberE164}) async {
    final key = phoneNumberE164.replaceAll('+', '');
    final ref = _dbRef.child(_otpNode).child(key);

    try {
      final snapshot = await ref.get();
      if (snapshot.exists) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        final lastSentAt = data['lastSentAt'] as int?;
        if (lastSentAt != null) {
          final elapsed = DateTime.now().millisecondsSinceEpoch - lastSentAt;
          final remaining = kOtpResendCooldown.inMilliseconds - elapsed;
          if (remaining > 0) {
            return OtpSendResult.cooldown((remaining / 1000).ceil());
          }
        }
      }

      if (kOtpDemoMode) {
        final otp = _generateOtp();
        final now = DateTime.now();
        await ref.set({
          'otp': otp,
          'phone': phoneNumberE164,
          'createdAt': now.millisecondsSinceEpoch,
          'lastSentAt': now.millisecondsSinceEpoch,
          'expiresAt': now.add(kOtpValidity).millisecondsSinceEpoch,
          'attempts': 0,
        });
        return OtpSendResult.ok(demoOtp: otp);
      } else {
        return OtpSendResult.error('Real SMS delivery is not configured yet.');
      }
    } catch (e) {
      debugPrint('sendOtp error: $e');
      return OtpSendResult.error('Could not send code. Please try again.');
    }
  }

  /// Verifies the OTP and ensures a real (anonymous) Firebase Auth session
  /// exists. Does NOT touch the users table — that's handled separately by
  /// [fetchUserProfile] (login) or [createUserProfile] (register).
  Future<OtpVerifyResult> verifyOtp({
    required String phoneNumberE164,
    required String enteredOtp,
  }) async {
    final key = phoneNumberE164.replaceAll('+', '');
    final ref = _dbRef.child(_otpNode).child(key);

    try {
      final snapshot = await ref.get();
      if (!snapshot.exists) {
        return OtpVerifyResult.error('Code expired or not found. Please resend.');
      }

      final data = Map<String, dynamic>.from(snapshot.value as Map);
      final storedOtp = data['otp'] as String;
      final expiresAt = data['expiresAt'] as int;
      final attempts = (data['attempts'] as int?) ?? 0;

      if (DateTime.now().millisecondsSinceEpoch > expiresAt) {
        await ref.remove();
        return OtpVerifyResult.error('Code expired. Please request a new one.');
      }

      if (attempts >= kOtpMaxAttempts) {
        await ref.remove();
        return OtpVerifyResult.error(
          'Too many incorrect attempts. Please request a new code.',
        );
      }

      if (enteredOtp.trim() != storedOtp) {
        await ref.update({'attempts': attempts + 1});
        final remaining = kOtpMaxAttempts - (attempts + 1);
        return OtpVerifyResult.error(
          'Incorrect code. $remaining attempt${remaining == 1 ? '' : 's'} left.',
        );
      }

      await ref.remove();

      // Reuse an existing anonymous session if one is already active on
      // this device; otherwise create one. This keeps auth != null true
      // for database rule checks without generating a new uid every time.
      if (_auth.currentUser == null) {
        await _auth.signInAnonymously();
      }

      return OtpVerifyResult.ok(_auth.currentUser?.uid);
    } catch (e) {
      debugPrint('verifyOtp error: $e');
      return OtpVerifyResult.error('Something went wrong. Please try again.');
    }
  }

  /// Looks up an existing profile by phone number. Returns null if no
  /// account exists for that number — used by the Login screen.
  Future<Map<String, dynamic>?> fetchUserProfile(String phoneNumberE164) async {
    try {
      final key = phoneNumberE164.replaceAll('+', '');
      final snapshot = await _dbRef.child(_usersNode).child(key).get();
      if (!snapshot.exists) return null;
      return Map<String, dynamic>.from(snapshot.value as Map);
    } catch (e) {
      debugPrint('fetchUserProfile error: $e');
      return null;
    }
  }

  /// Creates a new profile keyed by phone number — used by the Register
  /// screen. Throws if the phone number is already registered.
  Future<Map<String, dynamic>> createUserProfile({
    required String phoneNumberE164,
    required String role,
    required String name,
    String city = '',
    String? licenseNumber,
    String? ngoType,
  }) async {
    final key = phoneNumberE164.replaceAll('+', '');
    final ref = _dbRef.child(_usersNode).child(key);

    final existing = await ref.get();
    if (existing.exists) {
      throw Exception('An account with this phone number already exists.');
    }

    final normalizedRole = role.toLowerCase();
    final data = <String, dynamic>{
      'uid': _auth.currentUser?.uid,
      'name': name.trim(),
      'phone': phoneNumberE164,
      'role': normalizedRole,
      'city': city.trim(),
      'createdAt': ServerValue.timestamp,
      'isPhoneVerified': true,
      'isVerified': normalizedRole == 'ngo' ? false : true,
    };

    if (normalizedRole == 'ngo') {
      data['licenseNumber'] = licenseNumber?.trim() ?? '';
      data['ngoType'] = ngoType?.trim() ?? '';
    }

    await ref.set(data);
    return data;
  }

  Future<void> signOut() => _auth.signOut();

  User? get currentUser => _auth.currentUser;

  String _generateOtp() {
    final rand = Random.secure();
    final code = rand.nextInt(pow(10, kOtpLength).toInt() - 1);
    return code.toString().padLeft(kOtpLength, '0');
  }
}