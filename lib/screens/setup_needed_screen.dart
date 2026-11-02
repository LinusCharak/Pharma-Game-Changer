import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Shown as the app's home screen if lib/config/supabase_config.dart still
/// has placeholder values, so a fresh checkout fails gracefully instead of
/// crashing on Supabase.initialize().
class SetupNeededScreen extends StatelessWidget {
  const SetupNeededScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.settings_suggest, size: 56, color: AppColors.accent),
              const SizedBox(height: 16),
              const Text(
                "Supabase isn't configured yet",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'Open lib/config/supabase_config.dart and fill in your '
                'project URL and anon/public key from Supabase → Project '
                'Settings → API, then restart the app.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
