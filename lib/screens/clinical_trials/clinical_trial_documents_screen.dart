import 'package:flutter/material.dart';

import '../../models/clinical_trial_document.dart';
import '../../services/clinical_trial_service.dart';
import 'clinical_trial_pdf_screen.dart';

/// Screen 2 — displays the clinical trial documents for one product.
///
/// Documents are loaded from the Supabase `clinical_trial_documents` table.
/// The actual PDF files remain hosted on Google Drive.
class ClinicalTrialDocumentsScreen extends StatefulWidget {
  const ClinicalTrialDocumentsScreen({
    super.key,
    required this.title,
    this.productName,
    required this.folderId,
    required this.folderUrl,
  });

  final String title;

  /// Exact product_name value used in the Supabase table.
  final String? productName;

  /// Original Google Drive folder ID.
  ///
  /// Kept here because the product model already provides it and the
  /// original Drive folder can still be opened externally.
  final String? folderId;

  /// Original Google Drive folder URL.
  final String folderUrl;

  @override
  State<ClinicalTrialDocumentsScreen> createState() =>
      _ClinicalTrialDocumentsScreenState();
}

class _ClinicalTrialDocumentsScreenState
    extends State<ClinicalTrialDocumentsScreen> {
  final ClinicalTrialService _service = ClinicalTrialService();

  bool _loading = true;

  ClinicalTrialException? _error;

  List<ClinicalTrialDocument> _items =
      const <ClinicalTrialDocument>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final productName = widget.productName;

    // The new Clinical Trial flow always uses Supabase.
    if (productName == null) {
      setState(() {
        _loading = false;
        _error = const ClinicalTrialException(
          ClinicalTrialErrorKind.notFound,
          'This product link cannot be listed inside the app.',
        );
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final items =
          await _service.listDocumentsForProduct(productName);

      if (!mounted) return;

      setState(() {
        _items = items;
        _loading = false;
      });
    } on ClinicalTrialException catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _error = const ClinicalTrialException(
          ClinicalTrialErrorKind.unknown,
          'Something went wrong. Please try again.',
        );
        _loading = false;
      });
    }
  }

  Future<void> _openInDrive(String url) async {
    final ok = await _service.openExternally(url);

    if (!mounted || ok) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Could not open Google Drive.'),
      ),
    );
  }

  void _onTap(ClinicalTrialDocument item) {
    if (item.isFolder) {
      // This should normally not happen with the Supabase document
      // list, but keeping this makes the screen safe for folder items.
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ClinicalTrialDocumentsScreen(
            title: item.name,
            folderId: item.id,
            folderUrl: item.driveUrl,
          ),
        ),
      );
    } else if (item.isPdf) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ClinicalTrialPdfScreen(
            document: item,
          ),
        ),
      );
    } else {
      // Non-PDF files are opened externally in Google Drive.
      _openInDrive(item.driveUrl);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: <Widget>[
          IconButton(
            tooltip: 'Open in Google Drive',
            icon: const Icon(Icons.open_in_new),
            onPressed: () => _openInDrive(widget.folderUrl),
          ),
        ],
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    final error = _error;

    if (error != null) {
      return _buildError(context, error);
    }

    if (_items.isEmpty) {
      return _Message(
        icon: Icons.folder_open_outlined,
        title: 'No documents found',
        body:
            'There are no clinical trial documents in this folder yet.',
        actions: <Widget>[
          OutlinedButton.icon(
            onPressed: () => _openInDrive(widget.folderUrl),
            icon: const Icon(Icons.open_in_new),
            label: const Text('Open in Google Drive'),
          ),
        ],
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: _items.length,
        separatorBuilder: (_, __) =>
            const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final item = _items[index];

          return _DocumentCard(
            item: item,
            onTap: () => _onTap(item),
          );
        },
      ),
    );
  }

  Widget _buildError(
    BuildContext context,
    ClinicalTrialException error,
  ) {
    final offline =
        error.kind == ClinicalTrialErrorKind.offline;

    return _Message(
      icon: offline
          ? Icons.wifi_off_outlined
          : Icons.error_outline,
      title: offline
          ? 'No internet connection'
          : 'Documents unavailable',
      body: error.message,
      actions: <Widget>[
        if (error.kind !=
            ClinicalTrialErrorKind.notConfigured)
          FilledButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            label: const Text('Try again'),
          ),
        if (error.canFallBackToDrive)
          OutlinedButton.icon(
            onPressed: () =>
                _openInDrive(widget.folderUrl),
            icon: const Icon(Icons.open_in_new),
            label: const Text('Open in Google Drive'),
          ),
      ],
    );
  }
}

/// Card used for each clinical trial document.
class _DocumentCard extends StatelessWidget {
  const _DocumentCard({
    required this.item,
    required this.onTap,
  });

  final ClinicalTrialDocument item;
  final VoidCallback onTap;

  static const List<String> _months = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  String _subtitle() {
    final parts = <String>[];

    if (item.isFolder) {
      parts.add('Folder');
    } else if (item.isPdf) {
      parts.add('PDF');

      final size = item.sizeBytes;

      if (size != null) {
        parts.add(_formatSize(size));
      }
    } else {
      parts.add('Opens in Google Drive');
    }

    final modified = item.modifiedTime?.toLocal();

    if (modified != null) {
      parts.add(
        '${modified.day} '
        '${_months[modified.month - 1]} '
        '${modified.year}',
      );
    }

    return parts.join('  •  ');
  }

  static String _formatSize(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }

    return '${(bytes / 1024).ceil()} KB';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final IconData icon = item.isFolder
        ? Icons.folder_outlined
        : item.isPdf
            ? Icons.picture_as_pdf_outlined
            : Icons.insert_drive_file_outlined;

    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: scheme.primary.withAlpha(28),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      item.displayTitle,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _subtitle(),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: scheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Centered message with optional action buttons.
class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.title,
    required this.body,
    this.actions = const <Widget>[],
  });

  final IconData icon;
  final String title;
  final String body;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              icon,
              size: 56,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium
                  ?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              body,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            for (final action in actions) ...<Widget>[
              action,
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }
}