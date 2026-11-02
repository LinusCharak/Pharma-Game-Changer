import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../models/clinical_trial_document.dart';
import '../../services/clinical_trial_service.dart';

/// Screen 3 — shows one PDF inside the app, with Download, Share and
/// "Open in Google Drive".
///
/// The PDF is fetched once into the app cache; the viewer, Download and
/// Share all use that same local file.
class ClinicalTrialPdfScreen extends StatefulWidget {
  const ClinicalTrialPdfScreen({super.key, required this.document});

  final ClinicalTrialDocument document;

  @override
  State<ClinicalTrialPdfScreen> createState() => _ClinicalTrialPdfScreenState();
}

class _ClinicalTrialPdfScreenState extends State<ClinicalTrialPdfScreen> {
  final ClinicalTrialService _service = ClinicalTrialService();
  CancelToken? _cancelToken;

  File? _file;
  ClinicalTrialException? _error;
  double _progress = 0;
  bool _busy = false; // a save or share is in progress

  int _page = 1;
  int _pageCount = 0;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void dispose() {
    _cancelToken?.cancel();
    super.dispose();
  }

  Future<void> _fetch() async {
    _cancelToken?.cancel();
    final token = CancelToken();
    _cancelToken = token;

    setState(() {
      _file = null;
      _error = null;
      _progress = 0;
      _page = 1;
      _pageCount = 0;
    });

    try {
      final file = await _service.fetchPdf(
        widget.document,
        cancelToken: token,
        onProgress: (p) {
          if (mounted && !token.isCancelled) setState(() => _progress = p);
        },
      );
      if (!mounted || token.isCancelled) return;
      setState(() => _file = file);
    } on ClinicalTrialException catch (e) {
      if (!mounted || token.isCancelled) return;
      setState(() => _error = e);
    } catch (_) {
      if (!mounted || token.isCancelled) return;
      setState(() {
        _error = const ClinicalTrialException(
          ClinicalTrialErrorKind.unknown,
          'This PDF could not be opened.',
        );
      });
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _download() async {
    final file = _file;
    if (file == null || _busy) return;
    setState(() => _busy = true);
    try {
      final saved = await _service.saveToDownloads(
        file,
        widget.document.displayTitle,
      );
      if (!mounted) return;
      _snack(
        saved.inPublicDownloads
            ? 'Saved to Download/PGC Clinical Trials'
            : 'Saved in app storage. Use Share to send or export it.',
      );
    } catch (_) {
      if (!mounted) return;
      _snack('Could not save the PDF.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _share() async {
    final file = _file;
    if (file == null || _busy) return;
    setState(() => _busy = true);
    try {
      await _service.sharePdf(file, widget.document.displayTitle);
    } catch (_) {
      if (!mounted) return;
      _snack('Could not share the PDF.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openInDrive() async {
    final ok = await _service.openExternally(widget.document.driveUrl);
    if (!mounted || ok) return;
    _snack('Could not open Google Drive.');
  }

  @override
  Widget build(BuildContext context) {
    final ready = _file != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.document.displayTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: <Widget>[
          IconButton(
            tooltip: 'Download',
            icon: const Icon(Icons.download_outlined),
            onPressed: ready && !_busy ? _download : null,
          ),
          IconButton(
            tooltip: 'Share',
            icon: const Icon(Icons.share_outlined),
            onPressed: ready && !_busy ? _share : null,
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'drive') _openInDrive();
            },
            itemBuilder: (_) => const <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                value: 'drive',
                child: Text('Open in Google Drive'),
              ),
            ],
          ),
        ],
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    final theme = Theme.of(context);

    final error = _error;
    if (error != null) {
      final offline = error.kind == ClinicalTrialErrorKind.offline;
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                offline ? Icons.wifi_off_outlined : Icons.error_outline,
                size: 56,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                offline ? 'No internet connection' : 'Cannot open this PDF',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(error.message, textAlign: TextAlign.center),
              const SizedBox(height: 20),
              if (error.kind != ClinicalTrialErrorKind.notConfigured)
                FilledButton.icon(
                  onPressed: _fetch,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try again'),
                ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _openInDrive,
                icon: const Icon(Icons.open_in_new),
                label: const Text('Open in Google Drive'),
              ),
            ],
          ),
        ),
      );
    }

    final file = _file;
    if (file == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              CircularProgressIndicator(value: _progress > 0 ? _progress : null),
              const SizedBox(height: 16),
              Text(
                _progress > 0
                    ? 'Loading PDF… ${(_progress * 100).round()}%'
                    : 'Loading PDF…',
              ),
            ],
          ),
        ),
      );
    }

    return Stack(
      children: <Widget>[
        PdfViewer.file(
          file.path,
          params: PdfViewerParams(
            onViewerReady: (document, controller) {
              if (mounted) setState(() => _pageCount = document.pages.length);
            },
            onPageChanged: (pageNumber) {
              if (mounted && pageNumber != null) {
                setState(() => _page = pageNumber);
              }
            },
          ),
        ),
        if (_pageCount > 0)
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(170),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Page $_page / $_pageCount',
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
