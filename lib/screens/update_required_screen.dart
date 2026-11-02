import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/app_version_service.dart';
import '../theme/app_theme.dart';

/// Blocking "update required" screen, shown when a fresh daily Supabase
/// login is needed but the installed app version is below
/// app_version_control.minimum_version_code. The Play Store URL comes
/// entirely from Supabase (result.playStoreUrl), never hardcoded here.
class UpdateRequiredScreen extends StatelessWidget {
  final VersionCheckResult result;

  const UpdateRequiredScreen({super.key, required this.result});

  Future<void> _openPlayStore(BuildContext context) async {
    final url = result.playStoreUrl;
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Update link is not available right now.')),
      );
      return;
    }

    final uri = Uri.tryParse(url);
    final launched = uri != null && await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (!launched) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the Play Store. Please update manually.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.primary, AppColors.accent],
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.system_update, size: 56, color: AppColors.primary),
                  const SizedBox(height: 16),
                  const Text(
                    'Update Required',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    result.updateMessage.isNotEmpty
                        ? result.updateMessage
                        : 'A newer version of Pharma Game Changer is available. '
                            'Please update the app from Google Play Store to continue.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _openPlayStore(context),
                      child: const Text('UPDATE NOW'),
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
