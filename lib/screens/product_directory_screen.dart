import 'package:flutter/material.dart';
import '../data/product_catalog.dart';
import '../models/product.dart';
import '../theme/app_theme.dart';
import '../widgets/product_grid.dart';

class ProductDirectoryScreen extends StatelessWidget {
  final bool embedded;
  const ProductDirectoryScreen({super.key, this.embedded = false});

  @override
  Widget build(BuildContext context) {
    final body = ListView.builder(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: productCatalog.length,
      itemBuilder: (context, index) {
        final category = productCatalog[index];
        return _CategorySection(category: category);
      },
    );

    if (embedded) return body;

    return Scaffold(
      appBar: AppBar(title: const Text('Product Directory')),
      body: body,
    );
  }
}

class _CategorySection extends StatelessWidget {
  final ProductCategory category;
  const _CategorySection({required this.category});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(
            category.title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary),
          ),
        ),
        ProductGrid(
          products: category.products,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
        ),
        const Divider(height: 8),
      ],
    );
  }
}
