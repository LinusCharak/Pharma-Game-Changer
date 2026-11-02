import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user_profile.dart';

/// Caches the result of a successful `check_login` so the app can be
/// used offline in clinics with poor/no Internet.
///
/// This is deliberately separate from CredentialStorageService: that
/// service stores the username/password for the optional "Remember Me"
/// pre-fill convenience; this service stores the OUTCOME of a real
/// server login (the profile) plus the date it happened. The two are
/// independent -- clearing one does not clear the other.
///
/// This is a local-access cache, not a replacement for server
/// authentication: a real Supabase login is still required once per new
/// day whenever connectivity is available. `check_login` itself is
/// untouched; this class only decides when to call it.
class SessionService {
  SessionService._();

  static final SessionService instance = SessionService._();

  static const String _profileKey = 'cached_user_profile';
  static const String _lastLoginDateKey = 'last_successful_supabase_login_date';

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  /// Call this ONLY after a real, successful `check_login` response
  /// (already-validated, active profile). Records today's date as the
  /// last successful Supabase login and caches the profile for offline
  /// use.
  Future<void> recordSuccessfulLogin(UserProfile profile) async {
    await _storage.write(key: _profileKey, value: jsonEncode(profile.toMap()));
    await _storage.write(key: _lastLoginDateKey, value: _todayKey());
    debugPrint('Session: recorded successful login for ${_todayKey()}');
  }

  /// True only if a real Supabase login has already succeeded on this
  /// device today -- NOT merely that the app was opened today.
  Future<bool> isTodayLoginRecorded() async {
    final stored = await _storage.read(key: _lastLoginDateKey);
    return stored != null && stored == _todayKey();
  }

  /// The most recently cached profile, regardless of which day it was
  /// recorded on. Used both for the same-day fast path and for the
  /// offline fallback on a new day with no connectivity. Returns null if
  /// there is no cache, or if the cached value is corrupted (treated the
  /// same as "no cache" rather than crashing).
  Future<UserProfile?> getCachedProfile() async {
    final raw = await _storage.read(key: _profileKey);
    if (raw == null) return null;

    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return UserProfile.fromMap(map);
    } catch (e) {
      debugPrint('Session: cached profile is corrupted, ignoring it: $e');
      return null;
    }
  }

  /// Clears the cached profile and last-login-date. Intended to be
  /// called on explicit logout, independent of the Remember Me
  /// credential clearing.
  Future<void> clearSession() async {
    await _storage.delete(key: _profileKey);
    await _storage.delete(key: _lastLoginDateKey);
    debugPrint('Session: cleared');
  }
}
