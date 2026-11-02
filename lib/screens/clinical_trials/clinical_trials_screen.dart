import 'package:flutter/material.dart';

import '../../data/clinical_trial_products.dart';
import '../../models/clinical_trial_product.dart';
import 'clinical_trial_documents_screen.dart';

/// Screen 1 — lists every product that has clinical trial documents.
///
/// Replaces the Kodular `Clinical_Trial` screen: same 15 products, same
/// Google Drive folders, but the user now stays inside the app. Document
/// listing for the selected product is now driven by the
/// `clinical_trial_documents` Supabase table (see
/// ClinicalTrialDocumentsScreen), matched on this exact product name.
class ClinicalTrialsScreen extends StatelessWidget {
  const ClinicalTrialsScreen({super.key});

  void _open(BuildContext context, ClinicalTrialProduct product) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ClinicalTrialDocumentsScreen(
          title: product.name,
          productName: product.name,
          folderId: product.folderId,
          folderUrl: product.folderUrl,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const products = kClinicalTrialProducts;

    return Scaffold(
      appBar: AppBar(title: const Text('Clinical Trials')),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: products.length + 1,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 4, top: 4),
              child: Text(
                'Select a product to view available clinical trials',
                style: theme.textTheme.bodyMedium,
              ),
            );
          }
          final product = products[index - 1];
          return _ProductCard(
            product: product,
            onTap: () => _open(context, product),
          );
        },
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.product, required this.onTap});

  final ClinicalTrialProduct product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: scheme.primary.withAlpha(28),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.biotech_outlined, color: scheme.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      product.name,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'View trial documents',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: scheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}
