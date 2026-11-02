import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_profile.dart';

enum AuthFailureReason { invalidCredentials, inactiveAccount, network, unknown }

/// Thrown by AuthService.login() on any failure. `message` is always the
/// safe, user-facing string -- never raw SQL/Postgrest detail.
class AuthFailure implements Exception {
  final AuthFailureReason reason;
  final String message;
  AuthFailure(this.reason, this.message);

  @override
  String toString() => message;
}

/// The ONLY authentication mechanism for this app: the `check_login`
/// Postgres RPC. This service never queries `login` directly --
/// `.from('login')` must not appear anywhere in this file.
class AuthService {
  SupabaseClient get _db => Supabase.instance.client;

  Future<UserProfile> login(String username, String password) async {
    final cleanUsername = username.trim();
    // Password is intentionally NOT trimmed or otherwise modified --
    // passed through to the RPC exactly as entered.

    dynamic result;
    try {
      result = await _db.rpc('check_login', params: {
        'p_username': cleanUsername,
        'p_password': password,
      });
    } on PostgrestException catch (e) {
      // A real Supabase/Postgres-level error (e.g. RPC misconfigured).
      // Never surface e.message (could contain schema detail) to the UI.
      debugPrint('check_login RPC error: ${e.code} ${e.message}');
      throw AuthFailure(
        AuthFailureReason.unknown,
        'Unable to sign in right now. Please try again.',
      );
    } catch (e) {
      // Anything else (no connectivity, timeout, DNS failure, etc.)
      debugPrint('check_login network/unknown error: $e');
      throw AuthFailure(
        AuthFailureReason.network,
        'Unable to connect. Please check your internet connection and try again.',
      );
    }

    final rows = (result as List?) ?? const [];
    if (rows.isEmpty) {
      // Covers both "no such username" and "wrong password" identically --
      // never reveal which one it was.
      throw AuthFailure(
        AuthFailureReason.invalidCredentials,
        'Incorrect username or password.',
      );
    }

    final profile = UserProfile.fromMap(Map<String, dynamic>.from(rows.first as Map));

    if (!profile.isActive) {
      throw AuthFailure(
        AuthFailureReason.inactiveAccount,
        'Your account is inactive. Please contact your administrator.',
      );
    }

    return profile;
  }
}
