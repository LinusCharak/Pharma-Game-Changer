import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/app_version_service.dart';

/// Mandatory "new version available" dialog. It cannot be dismissed: no
/// Later button, tapping outside does nothing, and the Android back button
/// is blocked. The only way forward is to update. The Play Store URL comes
/// from Supabase (result.playStoreUrl), never hardcoded.
Future<void> showUpdateAvailableDialog(
  BuildContext context,
  VersionCheckResult result,
) {
  final version = result.latestVersionName.trim();
  final message = version.isEmpty
      ? 'A new version of Pharma Game Changer is available. '
          'Please update the app to continue.'
      : 'A new version ($version) of Pharma Game Changer is available. '
          'Please update the app to continue.';

  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => PopScope(
      canPop: false,
      child: AlertDialog(
        title: const Text('New Update'),
        content: Text(message),
        actions: [
          ElevatedButton(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(dialogContext);
              final uri = Uri.tryParse(result.playStoreUrl);
              final launched = uri != null &&
                  result.playStoreUrl.isNotEmpty &&
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
              if (!launched) {
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Could not open the Play Store. Please update manually.'),
                  ),
                );
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    ),
  );
}
