import 'package:flutter/material.dart';
import '../models/product.dart';
import '../screens/product_html_screen.dart';
import '../theme/app_theme.dart';
import 'product_variant_picker.dart';

class ProductGrid extends StatelessWidget {
  final List<Product> products;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  final double spacing;
  final int? fixedColumns;

  const ProductGrid({
    super.key,
    required this.products,
    this.shrinkWrap = false,
    this.physics,
    this.spacing = 12,
    this.fixedColumns,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = fixedColumns ?? Breakpoints.gridColumns(constraints.maxWidth);
        return GridView.builder(
          shrinkWrap: shrinkWrap,
          physics: physics,
          padding: const EdgeInsets.all(16),
          itemCount: products.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
            childAspectRatio: 0.85,
          ),
          itemBuilder: (context, i) {
            final product = products[i];
            return InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () {
                if (product.variants != null && product.variants!.isNotEmpty) {
                  showProductVariantPicker(context: context, product: product);
                } else {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ProductHtmlScreen(startValue: product.startValue),
                    ),
                  );
                }
              },
              child: Image.asset(
                product.imageAsset,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.image_not_supported_outlined,
                  color: Colors.grey,
                ),
              ),
            );
          },
        );
      },
    );
  }
}
