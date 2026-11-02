import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/app_version_service.dart';
import '../services/auth_service.dart';
import '../services/credential_storage_service.dart';
import '../services/session_service.dart';
import '../models/user_profile.dart';
import '../theme/app_theme.dart';
import 'menu_screen.dart';
import 'update_required_screen.dart';
import '../widgets/update_available_dialog.dart';

/// Login screen backed by the `check_login` Supabase RPC, with a daily
/// offline-access layer on top (see SessionService).
///
/// Login behavior:
///
/// 1. The Login screen is ALWAYS shown when the app starts.
///    The app never automatically enters MenuScreen.
///
/// 2. Remember Me only controls whether username/password are
///    pre-filled. It does NOT automatically submit the login.
///
/// 3. When the user presses Sign In:
///
///    SAME DAY:
///      - If a successful Supabase login has already been recorded today,
///        the cached profile is used.
///      - No Supabase call is made.
///      - No version check is made.
///      - User goes directly to MenuScreen.
///
///    NEW DAY:
///      - Username/password are required.
///      - App version is checked.
///      - A real Supabase login is required.
///      - On successful login, today's session is recorded and the
///        profile is cached.
///
/// 4. A network failure on a new day never falls back to an old cached
///    profile. Internet is required for the first login of a new day.
///
/// 5. Wrong credentials or an inactive account always show their actual
///    authentication error.
///
/// 6. Logout does NOT clear the daily cached session. Therefore,
///    after logout, pressing Sign In on the same day can enter Menu
///    without another Supabase login.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  final _authService = AuthService();
  final _credentialStorage = CredentialStorageService.instance;
  final _sessionService = SessionService.instance;
  final _versionService = AppVersionService.instance;

  bool _obscurePassword = true;
  bool _loading = false;
  bool _rememberMe = true;

  // Used only while remembered credentials are being loaded.
  bool _initializing = true;

  String? _error;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  /// Initializes the Login screen.
  ///
  /// IMPORTANT:
  /// This method NEVER checks the daily session and NEVER automatically
  /// enters MenuScreen.
  ///
  /// The user must explicitly press the Sign In button.
  Future<void> _initialize() async {
    // Load remembered credentials.
    try {
      final credentials = await _credentialStorage.getCredentials();

      if (credentials != null) {
        _usernameController.text = credentials['username'] ?? '';
        _passwordController.text = credentials['password'] ?? '';
        _rememberMe = true;
      }
    } catch (_) {
      // If secure storage cannot be read, simply start with
      // empty fields.
      //
      // Do not display or log the stored password.
    }

    if (!mounted) return;

    // IMPORTANT:
    // Do not automatically check the cached session here.
    //
    // The Login screen must remain visible until the user presses
    // Sign In.
    debugPrint('Login screen ready -- waiting for user to press Sign In');

    setState(() {
      _initializing = false;
    });
  }

  /// Navigates to the Menu screen.
  void _goToMenu(UserProfile profile) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => MenuScreen(profile: profile),
      ),
      (route) => false,
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Handles explicit Sign In button press.
  ///
  /// The order is important:
  ///
  /// 1. Check whether today's login already exists.
  /// 2. If yes -> use cached profile, no Supabase.
  /// 3. If no -> validate credentials.
  /// 4. Check app version.
  /// 5. Perform real Supabase login.
  /// 6. Cache successful login.
  Future<void> _signIn() async {
    if (_loading) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    // ============================================================
    // 1. SAME-DAY SESSION CHECK
    // ============================================================
    //
    // This happens only after the user explicitly presses Sign In.
    //
    // It happens BEFORE:
    // - username validation
    // - password validation
    // - version check
    // - Supabase login
    //
    // Therefore, same-day login does not require credentials again.
    final alreadyLoggedInToday =
        await _sessionService.isTodayLoginRecorded();

    final cachedProfile =
        await _sessionService.getCachedProfile();

    if (alreadyLoggedInToday && cachedProfile != null) {
      debugPrint(
        "Today's login already completed -- "
        "using cached profile, no Supabase/version check",
      );

      if (!mounted) return;

      _goToMenu(cachedProfile);
      return;
    }

    // ============================================================
    // 2. NEW DAY -- REAL LOGIN IS REQUIRED
    // ============================================================

    final username = _usernameController.text.trim();

    // Password is intentionally NOT trimmed.
    final password = _passwordController.text;

    // Validate username.
    if (username.isEmpty) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = 'Please enter your username.';
      });

      return;
    }

    // Validate password.
    if (password.isEmpty) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = 'Please enter your password.';
      });

      return;
    }

    // ============================================================
    // 3. APP VERSION CHECK
    // ============================================================
    //
    // Only performed when a real daily Supabase login is required.
    debugPrint('Checking app version before Supabase login');

    final versionResult =
        await _versionService.checkVersion();

    // Mandatory update.
    if (versionResult.status ==
        VersionCheckStatus.updateRequired) {
      debugPrint(
        'App version is below the required minimum -- '
        'blocking login',
      );

      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => UpdateRequiredScreen(
            result: versionResult,
          ),
        ),
      );

      return;
    }

    // Unable to verify version.
    if (versionResult.status ==
        VersionCheckStatus.unableToVerify) {
      debugPrint(
        'Could not verify app version -- blocking login',
      );

      if (!mounted) return;

      setState(() {
        _loading = false;
        _error =
            'Internet connection is required for login. '
            'Please connect to the internet and try again.';
      });

      return;
    }

    // ============================================================
    // 4. REAL SUPABASE LOGIN
    // ============================================================
    try {
      debugPrint('Attempting Supabase login');

      final profile = await _authService.login(
        username,
        password,
      );

      debugPrint('Supabase login successful');

      // ==========================================================
      // 5. REMEMBER ME
      // ==========================================================
      if (_rememberMe) {
        await _credentialStorage.saveCredentials(
          username: username,
          password: password,
        );
      } else {
        await _credentialStorage.clearCredentials();
      }

      // ==========================================================
      // 6. RECORD TODAY'S SUCCESSFUL LOGIN
      // ==========================================================
      //
      // This stores:
      // - cached_user_profile
      // - last_successful_supabase_login_date
      //
      // This is what allows the user to sign in again later today
      // without another Supabase call.
      await _sessionService.recordSuccessfulLogin(
        profile,
      );

      if (!mounted) return;

      // Optional, dismissible hint: a newer version exists but the
      // installed one is still allowed. Shown at most once per day,
      // because the version check only runs on a real daily login.
      if (versionResult.updateAvailable) {
        await showUpdateAvailableDialog(context, versionResult);
        if (!mounted) return;
      }

      _goToMenu(profile);
    } on AuthFailure catch (e) {
      // ==========================================================
      // NETWORK FAILURE
      // ==========================================================
      //
      // IMPORTANT:
      // We are here only because today's cached session was NOT
      // available. Therefore we must NOT use an older cached
      // profile as a substitute for today's authentication.
      if (e.reason == AuthFailureReason.network) {
        debugPrint(
          "Supabase unreachable -- today's login "
          "is required and cannot be skipped",
        );

        if (!mounted) return;

        setState(() {
          _loading = false;
          _error =
              'Internet connection is required for login. '
              'Please connect to the internet and try again.';
        });

        return;
      }

      // ==========================================================
      // INVALID CREDENTIALS / INACTIVE ACCOUNT
      // ==========================================================
      //
      // Never fall back to cached data for these cases.
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = e.message;
      });
    } catch (e) {
      debugPrint('Unexpected login error: $e');

      if (!mounted) return;

      setState(() {
        _loading = false;
        _error =
            'Unable to sign in right now. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    final formWidth =
        width > 480 ? 420.0 : width * 0.9;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.primary,
              AppColors.accent,
            ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              vertical: 40,
            ),
            child: Container(
              width: formWidth,
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: 0.2,
                    ),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ==================================================
                  // LOGO
                  // ==================================================
                  Image.asset(
                    'assets/images/ICONTrainingMask.png',
                    height: 64,
                    errorBuilder: (_, __, ___) =>
                        const Icon(
                      Icons.medical_services,
                      size: 64,
                      color: AppColors.primary,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ==================================================
                  // TITLE
                  // ==================================================
                  const Text(
                    'Pharma Game Changer',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ==================================================
                  // USERNAME
                  // ==================================================
                  TextField(
                    controller: _usernameController,
                    textInputAction:
                        TextInputAction.next,
                    enabled:
                        !_loading && !_initializing,
                    decoration:
                        const InputDecoration(
                      hintText: 'Username',
                      prefixIcon: Icon(
                        Icons.person_outline,
                        color: AppColors.primary,
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ==================================================
                  // PASSWORD
                  // ==================================================
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    enabled:
                        !_loading && !_initializing,
                    textInputAction:
                        TextInputAction.done,
                    decoration: InputDecoration(
                      hintText: 'Password',
                      prefixIcon: const Icon(
                        Icons.lock_outline,
                        color: AppColors.primary,
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: AppColors.primary,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword =
                                !_obscurePassword;
                          });
                        },
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // ==================================================
                  // REMEMBER ME
                  // ==================================================
                  Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Checkbox(
                          value: _rememberMe,
                          onChanged:
                              (_loading ||
                                      _initializing)
                                  ? null
                                  : (value) {
                                      setState(() {
                                        _rememberMe =
                                            value ?? false;
                                      });
                                    },
                        ),
                        const Text(
                          'Remember Me',
                        ),
                      ],
                    ),
                  ),

                  // ==================================================
                  // ERROR MESSAGE
                  // ==================================================
                  if (_error != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      _error!,
                      style: const TextStyle(
                        color: Colors.red,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],

                  const SizedBox(height: 20),

                  // ==================================================
                  // SIGN IN BUTTON
                  // ==================================================
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed:
                          (_loading || _initializing)
                              ? null
                              : _signIn,
                      icon: _loading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child:
                                  CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(
                              Icons.login,
                            ),
                      label: Text(
                        _loading
                            ? 'Signing in...'
                            : 'Sign In',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}