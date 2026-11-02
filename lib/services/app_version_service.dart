import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum VersionCheckStatus { allowed, updateRequired, unableToVerify }

/// Result of comparing the installed app against app_version_control.
class VersionCheckResult {
  final VersionCheckStatus status;
  final String updateMessage;
  final String playStoreUrl;
  final String latestVersionName;

  /// True when the installed app is allowed to run but a newer version
  /// (app_version_control.latest_version_name) exists. Used only for the
  /// optional, dismissible "new version available" hint.
  final bool updateAvailable;

  const VersionCheckResult({
    required this.status,
    this.updateMessage = '',
    this.playStoreUrl = '',
    this.latestVersionName = '',
    this.updateAvailable = false,
  });
}

/// True when [latest] is a higher dotted version than [installed]
/// (e.g. "1.52.0" > "1.51.0"). Any unparseable value returns false, so a
/// badly typed table value can never trigger a hint by mistake.
bool _isNewerVersion(String latest, String installed) {
  List<int>? parse(String v) {
    final parts = v.trim().split('.');
    if (parts.isEmpty) return null;
    final out = <int>[];
    for (final p in parts) {
      final n = int.tryParse(p);
      if (n == null) return null;
      out.add(n);
    }
    return out;
  }

  final l = parse(latest);
  final i = parse(installed);
  if (l == null || i == null) return false;
  final len = l.length > i.length ? l.length : i.length;
  for (var k = 0; k < len; k++) {
    final a = k < l.length ? l[k] : 0;
    final b = k < i.length ? i[k] : 0;
    if (a != b) return a > b;
  }
  return false;
}

/// Checks the installed app's version code against the Supabase
/// app_version_control table. Only ever called when a fresh daily
/// Supabase login is actually about to happen -- never on a same-day
/// cached-session entry.
class AppVersionService {
  AppVersionService._();

  static final AppVersionService instance = AppVersionService._();

  SupabaseClient get _db => Supabase.instance.client;

  Future<VersionCheckResult> checkVersion() async {
    final int installedVersionCode;
    final String installedVersionName;
    try {
      final info = await PackageInfo.fromPlatform();
      installedVersionCode = int.parse(info.buildNumber);
      installedVersionName = info.version;
    } catch (e) {
      debugPrint('AppVersionService: could not read installed version: $e');
      return const VersionCheckResult(status: VersionCheckStatus.unableToVerify);
    }

    Map<String, dynamic>? row;
    try {
      row = await _db.from('app_version_control').select().eq('id', 1).maybeSingle();
    } catch (e) {
      debugPrint('AppVersionService: version-control query failed: $e');
      return const VersionCheckResult(status: VersionCheckStatus.unableToVerify);
    }

    if (row == null) {
      debugPrint('AppVersionService: app_version_control row is missing');
      return const VersionCheckResult(status: VersionCheckStatus.unableToVerify);
    }

    final minimumVersionCode = row['minimum_version_code'] as int;
    final latestVersionName = row['latest_version_name'] as String? ?? '';
    final latestVersionCode = row['latest_version_code'] as int?;
    final updateMessage = (row['update_message'] as String?)?.trim().isNotEmpty == true
        ? row['update_message'] as String
        : 'A new version of Pharma Game Changer is available. Please update to continue.';
    final playStoreUrl = row['play_store_url'] as String? ?? '';

    debugPrint('AppVersionService: installed=$installedVersionCode minimum=$minimumVersionCode');

    if (installedVersionCode >= minimumVersionCode) {
      return VersionCheckResult(
        status: VersionCheckStatus.allowed,
        playStoreUrl: playStoreUrl,
        latestVersionName: latestVersionName,
        updateAvailable: latestVersionCode != null
            ? latestVersionCode > installedVersionCode
            : _isNewerVersion(latestVersionName, installedVersionName),
      );
    }

    return VersionCheckResult(
      status: VersionCheckStatus.updateRequired,
      updateMessage: updateMessage,
      playStoreUrl: playStoreUrl,
      latestVersionName: latestVersionName,
    );
  }
}
