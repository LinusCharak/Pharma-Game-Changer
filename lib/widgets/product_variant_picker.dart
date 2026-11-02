import 'package:flutter/material.dart';
import '../models/product.dart';
import '../screens/product_html_screen.dart';

/// Popup shown when a product button actually represents a group of
/// related items (e.g. the combined "KOFOL SF / CT / SIP" button).
/// Lists each variant's icon + name; tapping one closes the popup and
/// opens that variant's HTML page.
Future<void> showProductVariantPicker({
  required BuildContext context,
  required Product product,
}) {
  final variants = product.variants!;

  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(product.name),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: variants
              .map(
                (v) => ListTile(
                  leading: Image.asset(
                    v.imageAsset,
                    width: 44,
                    height: 44,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(Icons.image_not_supported_outlined),
                  ),
                  title: Text(v.name),
                  onTap: () {
                    Navigator.of(dialogContext).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ProductHtmlScreen(startValue: v.startValue),
                      ),
                    );
                  },
                ),
              )
              .toList(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Cancel'),
        ),
      ],
    ),
  );
}
