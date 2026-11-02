import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

/// Reads the Promotogram page URL from the SAME Firebase project the
/// original app used (pharma-login, key: login/Promotogram). Kept
/// exactly as-is, per instruction -- this is what lets the GitHub Pages
/// URL be swapped from the Firebase console at any time with no app
/// update needed.
class PromotogramService {
  Future<String> fetchUrl() async {
    final db = FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL: 'https://pharma-login.firebaseio.com/',
    );

    final snapshot = await db.ref('login/Promotogram').get();

    if (!snapshot.exists || snapshot.value == null) {
      throw Exception('Promotogram URL is not configured in Firebase yet.');
    }

    final raw = snapshot.value.toString();

    // The stored value has come with stray wrapping characters around
    // the real link (literal quotes, leading/trailing slashes, spaces --
    // the exact pattern isn't consistent). Rather than replicate one
    // specific wrapping pattern, pull out just the http(s) URL itself
    // wherever it appears in the raw string.
    final match = RegExp(r'https?://\S+').firstMatch(raw);
    if (match == null) {
      throw Exception('Promotogram value does not contain a valid URL:\n$raw');
    }

    // Trim any trailing junk that sometimes rides along (stray quotes,
    // extra slashes, whitespace) without touching a legitimate URL.
    final url = match.group(0)!.replaceAll(RegExp(r'["\s]+$'), '');

    if (url.isEmpty) {
      throw Exception('Promotogram URL is empty.');
    }
    return url;
  }
}
