import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/clinical_trial_document.dart';

enum ClinicalTrialErrorKind {
  offline,
  notConfigured,
  accessDenied,
  notFound,
  invalidPdf,
  unknown,
}

class ClinicalTrialException implements Exception {
  const ClinicalTrialException(this.kind, this.message);

  final ClinicalTrialErrorKind kind;
  final String message;

  bool get canFallBackToDrive =>
      kind == ClinicalTrialErrorKind.notConfigured ||
      kind == ClinicalTrialErrorKind.accessDenied ||
      kind == ClinicalTrialErrorKind.notFound;

  @override
  String toString() => message;
}

/// Information about where a PDF was saved.
class SavedPdf {
  const SavedPdf({
    required this.path,
    required this.inPublicDownloads,
  });

  final String path;
  final bool inPublicDownloads;
}

/// Clinical Trial service.
///
/// Document listing comes from Supabase.
///
/// PDF downloading does NOT use the Google Drive API and therefore does
/// NOT require a Google Drive API key.
///
/// The google_drive_url stored in Supabase is used to extract the Drive
/// file ID, and the file is downloaded using Google's public download URL.
class ClinicalTrialService {
  ClinicalTrialService({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 60),
                sendTimeout: const Duration(seconds: 15),
                followRedirects: true,
                maxRedirects: 10,
              ),
            );

  final Dio _dio;

  static const String offlineMessage =
      'Internet connection is required to access clinical trial documents.';

  // ---------------------------------------------------------------------------
  // SUPABASE — DOCUMENT LIST
  // ---------------------------------------------------------------------------

  /// Returns active clinical trial documents for the selected product.
  ///
  /// The app accepts both the current Flutter product name and the older
  /// product names that may already exist in Supabase.
  Future<List<ClinicalTrialDocument>> listDocumentsForProduct(
    String productName,
  ) async {
    final productNames = _supabaseProductNames(productName);

    try {
      final rows = await Supabase.instance.client
          .from('clinical_trial_documents')
          .select()
          .inFilter('product_name', productNames)
          .eq('is_active', true)
          .order('sort_order');

      return (rows as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(ClinicalTrialDocument.fromSupabaseRow)
          .toList();
    } on PostgrestException catch (e) {
      debugPrint(
        'Supabase clinical_trial_documents error: '
        '${e.code} ${e.message}',
      );

      if (e.code == 'PGRST301' || e.code == '42501') {
        throw const ClinicalTrialException(
          ClinicalTrialErrorKind.accessDenied,
          'Could not load documents for this product.',
        );
      }

      throw ClinicalTrialException(
        ClinicalTrialErrorKind.unknown,
        'Could not load documents. ${e.message}',
      );
    } on SocketException {
      throw const ClinicalTrialException(
        ClinicalTrialErrorKind.offline,
        offlineMessage,
      );
    } catch (e) {
      debugPrint('Supabase clinical trial error: $e');

      if (e.toString().contains('SocketException')) {
        throw const ClinicalTrialException(
          ClinicalTrialErrorKind.offline,
          offlineMessage,
        );
      }

      throw const ClinicalTrialException(
        ClinicalTrialErrorKind.unknown,
        'Something went wrong while loading the documents.',
      );
    }
  }

  /// Handles known naming differences between the Flutter product list and
  /// product_name values already stored in Supabase.
  List<String> _supabaseProductNames(String productName) {
    switch (productName) {
      case 'M2TONE Infertility Trials':
        return <String>[
          'M2TONE Infertility Trials',
          'M2TONE Infertility',
        ];

      case 'M2TONE AUB Trials':
        return <String>[
          'M2TONE AUB Trials',
          'M2TONE AUB',
        ];

      case 'ALKA CALCURY PROSTEEZ':
        return <String>[
          'ALKA CALCURY PROSTEEZ',
          'ALKA5 CALCURY PROSTEEZ',
        ];

      case 'CHROPAXE & ZZOWIN NUTRA Trials':
        return <String>[
          'CHROPAXE & ZZOWIN NUTRA Trials',
          'ZZOWIN NUTRA Trials',
        ];

      case 'MENTACALM':
        return <String>[
          'MENTACALM',
          'MENTACALM Trials',
        ];

      default:
        return <String>[productName];
    }
  }

  // ---------------------------------------------------------------------------
  // PDF FETCH — NO GOOGLE DRIVE API KEY
  // ---------------------------------------------------------------------------

  /// Downloads a PDF into the application cache.
  ///
  /// This does NOT use the Google Drive API.
  ///
  /// It uses the Google Drive file ID extracted from the Supabase
  /// google_drive_url.
  Future<File> fetchPdf(
    ClinicalTrialDocument doc, {
    void Function(double progress)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final driveId = _extractDriveFileId(doc.driveUrl);

    if (driveId == null || driveId.isEmpty) {
      throw const ClinicalTrialException(
        ClinicalTrialErrorKind.invalidPdf,
        'The Google Drive link for this PDF is not valid.',
      );
    }

    final cacheDir = await _cacheDir();

    final stamp = doc.modifiedTime?.millisecondsSinceEpoch ?? 0;

    final cached = File(
      '${cacheDir.path}/${_safeFilePart(doc.id)}_$stamp.pdf',
    );

    if (await cached.exists() && await cached.length() > 0) {
      onProgress?.call(1);
      return cached;
    }

    final partial = File('${cached.path}.part');

    if (await partial.exists()) {
      try {
        await partial.delete();
      } catch (_) {}
    }

    /*
     * Google Drive provides two useful public download URL formats.
     *
     * First:
     * drive.usercontent.google.com
     *
     * Second:
     * drive.google.com/uc
     *
     * We try the first and then the second if necessary.
     */
    final downloadUrls = <String>[
      'https://drive.usercontent.google.com/download'
          '?id=$driveId&export=download&confirm=t',
      'https://drive.google.com/uc'
          '?export=download&id=$driveId',
    ];

    DioException? lastDioError;
    bool downloadedSomething = false;

    for (final url in downloadUrls) {
      try {
        if (await partial.exists()) {
          await partial.delete();
        }

        await _dio.download(
          url,
          partial.path,
          cancelToken: cancelToken,
          onReceiveProgress: (received, total) {
            if (total > 0) {
              onProgress?.call(received / total);
            }
          },
        );

        downloadedSomething = true;

        // A successful HTTP response isn't necessarily a PDF.
        // Google Drive can return an HTML confirmation/error page.
        if (await _looksLikePdf(partial)) {
          return partial.rename(cached.path);
        }

        // Not a PDF. Try the next Google Drive download URL.
        try {
          await partial.delete();
        } catch (_) {}
      } on DioException catch (e) {
        lastDioError = e;

        try {
          if (await partial.exists()) {
            await partial.delete();
          }
        } catch (_) {}
      } on SocketException {
        throw const ClinicalTrialException(
          ClinicalTrialErrorKind.offline,
          offlineMessage,
        );
      }
    }

    // -----------------------------------------------------------------------
    // If Google returned an HTML confirmation page, try to extract the
    // confirmation token and perform the second-stage download.
    // -----------------------------------------------------------------------

    if (downloadedSomething && await partial.exists()) {
      final confirmationUrl = await _confirmationDownloadUrl(
        partial,
        driveId,
      );

      if (confirmationUrl != null) {
        try {
          await _dio.download(
            confirmationUrl,
            partial.path,
            cancelToken: cancelToken,
            onReceiveProgress: (received, total) {
              if (total > 0) {
                onProgress?.call(received / total);
              }
            },
          );

          if (await _looksLikePdf(partial)) {
            return partial.rename(cached.path);
          }
        } on DioException catch (e) {
          lastDioError = e;
        }
      }
    }

    try {
      if (await partial.exists()) {
        await partial.delete();
      }
    } catch (_) {}

    if (lastDioError != null) {
      throw _mapDioError(lastDioError);
    }

    throw const ClinicalTrialException(
      ClinicalTrialErrorKind.invalidPdf,
      'Cannot open this PDF. The Google Drive file could not be downloaded.',
    );
  }

  /// Attempts to extract Google's confirmation token from an HTML response.
  ///
  /// This is useful for larger publicly shared Drive files where Google first
  /// displays a download-confirmation page.
  Future<String?> _confirmationDownloadUrl(
    File file,
    String driveId,
  ) async {
    try {
      final length = await file.length();

      // We only expect an HTML confirmation page here.
      // Don't attempt to read a huge file into memory.
      if (length > 2 * 1024 * 1024) {
        return null;
      }

      final bytes = await file.readAsBytes();

      final text = utf8.decode(
        bytes,
        allowMalformed: true,
      );

      if (!text.contains('<html') &&
          !text.contains('<HTML') &&
          !text.contains('Google Drive')) {
        return null;
      }

      // Common Drive confirmation patterns.
      final patterns = <RegExp>[
        RegExp(
          r'confirm=([0-9A-Za-z_-]+)',
          caseSensitive: false,
        ),
        RegExp(
          r'name="confirm"\s+value="([^"]+)"',
          caseSensitive: false,
        ),
      ];

      String? token;

      for (final pattern in patterns) {
        final match = pattern.firstMatch(text);
        if (match != null && match.groupCount >= 1) {
          token = match.group(1);
          if (token != null && token.isNotEmpty) {
            break;
          }
        }
      }

      if (token == null || token.isEmpty) {
        return null;
      }

      return 'https://drive.usercontent.google.com/download'
          '?id=$driveId&export=download&confirm=$token';
    } catch (e) {
      debugPrint('Could not parse Drive confirmation page: $e');
      return null;
    }
  }

  /// Extracts a Drive file ID from common Google Drive file URLs.
  String? _extractDriveFileId(String url) {
    final pathMatch = RegExp(
      r'/file/d/([A-Za-z0-9_-]+)',
    ).firstMatch(url);

    if (pathMatch != null) {
      return pathMatch.group(1);
    }

    final queryMatch = RegExp(
      r'[?&]id=([A-Za-z0-9_-]+)',
    ).firstMatch(url);

    if (queryMatch != null) {
      return queryMatch.group(1);
    }

    return null;
  }

  // ---------------------------------------------------------------------------
  // SAVE PDF
  // ---------------------------------------------------------------------------

  Future<SavedPdf> saveToDownloads(
    File source,
    String title,
  ) async {
    final fileName = '${_safeName(title)}.pdf';

    if (Platform.isAndroid) {
      try {
        await Permission.storage.request();
      } catch (_) {}

      try {
        final dir = Directory(
          '/storage/emulated/0/Download/PGC Clinical Trials',
        );

        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }

        final target = await _uniqueFile(
          dir,
          fileName,
        );

        await source.copy(target.path);

        return SavedPdf(
          path: target.path,
          inPublicDownloads: true,
        );
      } on FileSystemException catch (e) {
        debugPrint(
          'Public Downloads not writable, using app storage: $e',
        );
      }
    }

    final docs = await getApplicationDocumentsDirectory();

    final dir = Directory(
      '${docs.path}/clinical_trials',
    );

    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final target = await _uniqueFile(
      dir,
      fileName,
    );

    await source.copy(target.path);

    return SavedPdf(
      path: target.path,
      inPublicDownloads: false,
    );
  }

  // ---------------------------------------------------------------------------
  // SHARE
  // ---------------------------------------------------------------------------

  Future<void> sharePdf(
    File source,
    String title,
  ) async {
    final tmp = await getTemporaryDirectory();

    final dir = Directory(
      '${tmp.path}/clinical_trials_share',
    );

    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final named = File(
      '${dir.path}/${_safeName(title)}.pdf',
    );

    await source.copy(named.path);

    await Share.shareXFiles(
      <XFile>[
        XFile(
          named.path,
          mimeType: 'application/pdf',
        ),
      ],
      subject: title,
    );
  }

  // ---------------------------------------------------------------------------
  // OPEN IN GOOGLE DRIVE / BROWSER
  // ---------------------------------------------------------------------------

  Future<bool> openExternally(String url) async {
    try {
      return await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // ERROR HANDLING
  // ---------------------------------------------------------------------------

  ClinicalTrialException _mapDioError(
    DioException e,
  ) {
    switch (e.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return const ClinicalTrialException(
          ClinicalTrialErrorKind.offline,
          offlineMessage,
        );

      case DioExceptionType.cancel:
        return const ClinicalTrialException(
          ClinicalTrialErrorKind.unknown,
          'Download cancelled.',
        );

      case DioExceptionType.badResponse:
        final status = e.response?.statusCode ?? 0;

        debugPrint(
          'Google Drive download error $status: ${e.response?.data}',
        );

        if (status == 404) {
          return const ClinicalTrialException(
            ClinicalTrialErrorKind.notFound,
            'This PDF is unavailable or is not shared.',
          );
        }

        if (status == 400 ||
            status == 401 ||
            status == 403) {
          return const ClinicalTrialException(
            ClinicalTrialErrorKind.accessDenied,
            'Google Drive did not allow access to this PDF.',
          );
        }

        return ClinicalTrialException(
          ClinicalTrialErrorKind.unknown,
          'Google Drive returned an error ($status).',
        );

      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
        if (e.error is SocketException) {
          return const ClinicalTrialException(
            ClinicalTrialErrorKind.offline,
            offlineMessage,
          );
        }

        return const ClinicalTrialException(
          ClinicalTrialErrorKind.unknown,
          'Something went wrong while downloading the PDF.',
        );
    }
  }

  // ---------------------------------------------------------------------------
  // HELPERS
  // ---------------------------------------------------------------------------

  Future<Directory> _cacheDir() async {
    final tmp = await getTemporaryDirectory();

    final dir = Directory(
      '${tmp.path}/clinical_trials',
    );

    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    return dir;
  }

  Future<bool> _looksLikePdf(File file) async {
    if (!await file.exists()) {
      return false;
    }

    final raf = await file.open();

    try {
      final head = await raf.read(5);

      // PDF files begin with "%PDF-"
      return head.length == 5 &&
          head[0] == 0x25 &&
          head[1] == 0x50 &&
          head[2] == 0x44 &&
          head[3] == 0x46 &&
          head[4] == 0x2D;
    } finally {
      await raf.close();
    }
  }

  String _safeFilePart(String value) {
    return value.replaceAll(
      RegExp(r'[\\/:*?"<>|]'),
      '_',
    );
  }

  String _safeName(String title) {
    final cleaned = title
        .replaceAll(
          RegExp(r'[\\/:*?"<>|]'),
          '_',
        )
        .replaceAll(
          RegExp(r'\s+'),
          ' ',
        )
        .trim();

    return cleaned.isEmpty ? 'clinical_trial' : cleaned;
  }

  Future<File> _uniqueFile(
    Directory dir,
    String fileName,
  ) async {
    var target = File(
      '${dir.path}/$fileName',
    );

    if (!await target.exists()) {
      return target;
    }

    final dot = fileName.lastIndexOf('.');

    final base = dot > 0
        ? fileName.substring(0, dot)
        : fileName;

    final ext = dot > 0
        ? fileName.substring(dot)
        : '';

    var i = 1;

    while (await target.exists()) {
      target = File(
        '${dir.path}/$base ($i)$ext',
      );

      i++;
    }

    return target;
  }
}