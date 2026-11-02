import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

/// Reads the Price List page URL from the same Firebase project/bucket
/// the original app used (pharma-login, key: login/Pricelist). Kept
/// exactly as-is, per instruction -- lets the hosted price list page be
/// swapped from the Firebase console at any time with no app update.
class PriceListService {
  Future<String> fetchUrl() async {
    final db = FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL: 'https://pharma-login.firebaseio.com/',
    );

    final snapshot = await db.ref('login/Pricelist').get();

    if (!snapshot.exists || snapshot.value == null) {
      throw Exception('Price List URL is not configured in Firebase yet.');
    }

    final raw = snapshot.value.toString();

    // Same real-world quirk as Promotogram: the stored value comes
    // wrapped in stray characters (literal quotes, slashes, spaces) in
    // an inconsistent pattern, so we pull out just the http(s) URL
    // itself wherever it appears rather than trying to strip one
    // specific wrapping pattern.
    final match = RegExp(r'https?://\S+').firstMatch(raw);
    if (match == null) {
      throw Exception('Price List value does not contain a valid URL:\n$raw');
    }

    final url = match.group(0)!.replaceAll(RegExp(r'["\s]+$'), '');

    if (url.isEmpty) {
      throw Exception('Price List URL is empty.');
    }
    return url;
  }
}
