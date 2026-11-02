import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Securely stores and retrieves credentials for the optional
/// "Remember Me" feature.
///
/// Credentials are stored only when the user explicitly enables
/// Remember Me on the login screen.
class CredentialStorageService {
  CredentialStorageService._();

  static final CredentialStorageService instance =
      CredentialStorageService._();

  static const String _usernameKey = 'remembered_username';
  static const String _passwordKey = 'remembered_password';

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<void> saveCredentials({
    required String username,
    required String password,
  }) async {
    await _storage.write(
      key: _usernameKey,
      value: username,
    );

    await _storage.write(
      key: _passwordKey,
      value: password,
    );
  }

  Future<String?> getUsername() async {
    return _storage.read(key: _usernameKey);
  }

  Future<String?> getPassword() async {
    return _storage.read(key: _passwordKey);
  }

  Future<Map<String, String>?> getCredentials() async {
    final username = await getUsername();
    final password = await getPassword();

    if (username == null ||
        username.isEmpty ||
        password == null ||
        password.isEmpty) {
      return null;
    }

    return {
      'username': username,
      'password': password,
    };
  }

  Future<void> clearCredentials() async {
    await _storage.delete(key: _usernameKey);
    await _storage.delete(key: _passwordKey);
  }
}