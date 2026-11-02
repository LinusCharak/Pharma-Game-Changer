import '../data/product_catalog.dart';

/// One quiz topic (a row in `quiz_catergories`). [code] is the exact string
/// stored in Supabase and doubles as the name of that topic's own question
/// table (e.g. "HYPONIDD-DM" -> table "HYPONIDD-DM" with 50 MCQs).
class QuizCategory {
  final String code;
  final String label;
  final String? imageAsset;

  const QuizCategory._({
    required this.code,
    required this.label,
    this.imageAsset,
  });

  factory QuizCategory.fromCode(String code) {
    return QuizCategory._(
      code: code,
      label: _prettify(code),
      imageAsset: _matchProductImage(code),
    );
  }

  /// "HYPONIDD-DM" -> "Hyponidd DM", "PLAT-C" -> "Plat C"
  /// (short segments of 3 letters or fewer are kept upper-case, since
  /// they're usually abbreviations like DM/FL/C rather than whole words).
  static String _prettify(String code) {
    return code
        .split(RegExp(r'[-_]'))
        .where((w) => w.isNotEmpty)
        .map((w) => w.length <= 3
            ? w.toUpperCase()
            : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
        .join(' ');
  }

  /// Best-effort match against the existing product catalog so quiz tiles
  /// can reuse a product image instead of a generic icon when possible.
  static String? _matchProductImage(String code) {
    final prefix = code.split(RegExp(r'[-_]')).first.toUpperCase();
    if (prefix.isEmpty) return null;
    for (final category in productCatalog) {
      for (final product in category.products) {
        final name = product.name.toUpperCase();
        if (name.contains(prefix) || prefix.contains(name)) {
          return product.imageAsset;
        }
      }
    }
    return null;
  }
}
