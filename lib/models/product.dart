class Product {
  final String id;
  final String name;
  final String imageAsset;
  final String startValue;

  /// When a product button actually represents a group of related items
  /// (e.g. "KOFOL SF / CT / SIP" covers three separate HTML pages), set
  /// this instead of relying on [startValue] for navigation. Null/empty
  /// for every ordinary single-item product -- the default, unchanged
  /// behavior.
  final List<ProductVariant>? variants;

  const Product({
    required this.id,
    required this.name,
    required this.imageAsset,
    required this.startValue,
    this.variants,
  });
}

/// One choice inside a product's variant-selection popup (e.g. "Kofol SF"
/// within the combined "KOFOL SF / CT / SIP" button).
class ProductVariant {
  final String name;
  final String imageAsset;
  final String startValue;

  const ProductVariant({
    required this.name,
    required this.imageAsset,
    required this.startValue,
  });
}

class ProductCategory {
  final String title;
  final String tabLabel;
  final String bannerAsset;
  final List<Product> products;

  const ProductCategory({
    required this.title,
    required this.tabLabel,
    required this.bannerAsset,
    required this.products,
  });
}
