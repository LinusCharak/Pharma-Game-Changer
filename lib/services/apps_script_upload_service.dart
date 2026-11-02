import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import '../config/apps_script_config.dart';

/// What the Apps Script web app reported back.
class ReportUploadResult {
  /// True only when the PDF is in Drive AND the manager email was sent
  /// (or had already been sent for this attempt earlier).
  final bool success;
  final bool emailSent;

  /// Whether retrying could change the outcome. Network problems, a busy
  /// server and transient Gmail errors are retryable; "no manager email on
  /// record" and Gmail's daily quota are not.
  final bool retryable;

  final String? fileId;
  final String? fileUrl;
  final String? error;
  final String? errorCode;

  const ReportUploadResult({
    required this.success,
    required this.emailSent,
    required this.retryable,
    this.fileId,
    this.fileUrl,
    this.error,
    this.errorCode,
  });

  factory ReportUploadResult.failure(String message, {String? code, bool retryable = true}) {
    return ReportUploadResult(
      success: false,
      emailSent: false,
      retryable: retryable,
      error: message,
      errorCode: code,
    );
  }

  bool get fileSaved => fileId != null && fileId!.isNotEmpty;

  /// The MR may continue to the result screen when the report was fully
  /// delivered, OR when the PDF is safely stored in Drive and the email
  /// cannot be sent for a reason that retrying will never fix (the
  /// summary row and Drive copy remain, and Apps Script records the email
  /// error against the attempt for follow-up).
  bool get canProceed => success || (fileSaved && !retryable);
}

/// Sends the already-generated PDF bytes to the Apps Script web app.
/// The same bytes + same attempt_uuid are re-sent on retry; Apps Script is
/// responsible for not creating a second Drive file or a second email.
class AppsScriptUploadService {
  AppsScriptUploadService._();

  static final AppsScriptUploadService instance = AppsScriptUploadService._();

  static const _tag = '[PGC PDF]';
  static const _requestTimeout = Duration(seconds: 90);

  Future<ReportUploadResult> uploadReport({
    required String attemptUuid,
    required String fileName,
    required Uint8List pdfBytes,
  }) async {
    if (!AppsScriptConfig.isConfigured) {
      debugPrint('$_tag Apps Script URL is not configured (lib/config/apps_script_config.dart)');
      return ReportUploadResult.failure('Report server is not configured.', code: 'NOT_CONFIGURED');
    }

    debugPrint('$_tag Uploading to Apps Script (${pdfBytes.length} bytes)');

    final body = jsonEncode({
      'attempt_uuid': attemptUuid,
      'file_name': fileName,
      'pdf_base64': base64Encode(pdfBytes),
      if (AppsScriptConfig.uploadToken.isNotEmpty) 'token': AppsScriptConfig.uploadToken,
    });

    final client = HttpClient()..connectionTimeout = const Duration(seconds: 30);
    try {
      final response = await _postThenFollowRedirects(
        client,
        Uri.parse(AppsScriptConfig.reportWebAppUrl),
        body,
      );

      final text = await response.transform(utf8.decoder).join().timeout(_requestTimeout);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        debugPrint('$_tag Upload failed: HTTP ${response.statusCode}');
        return ReportUploadResult.failure(
          'Report server returned HTTP ${response.statusCode}.',
          code: 'HTTP_${response.statusCode}',
        );
      }

      return _parse(text);
    } on TimeoutException {
      debugPrint('$_tag Upload timed out');
      return ReportUploadResult.failure('The report server took too long to respond.', code: 'TIMEOUT');
    } on SocketException catch (e) {
      debugPrint('$_tag Upload failed (network): ${e.message}');
      return ReportUploadResult.failure('No connection to the report server.', code: 'NETWORK');
    } catch (e) {
      debugPrint('$_tag Upload failed: $e');
      return ReportUploadResult.failure('Unexpected error while sending the report.', code: 'UNKNOWN');
    } finally {
      client.close(force: true);
    }
  }

  /// Apps Script web apps answer a POST with a 302 redirect to a
  /// script.googleusercontent.com URL that must then be fetched with GET
  /// (the script has already run by that point). dart:io does not follow
  /// that redirect for POST on its own, so it is followed here by hand.
  Future<HttpClientResponse> _postThenFollowRedirects(
    HttpClient client,
    Uri uri,
    String body,
  ) async {
    final request = await client.postUrl(uri);
    request.followRedirects = false;
    request.headers.contentType = ContentType('application', 'json', charset: 'utf-8');
    final bytes = utf8.encode(body);
    request.contentLength = bytes.length;
    request.add(bytes);

    var response = await request.close().timeout(_requestTimeout);

    var current = uri;
    var hops = 0;
    while (_isRedirect(response.statusCode) && hops < 5) {
      final location = response.headers.value(HttpHeaders.locationHeader);
      await response.drain<void>();
      if (location == null) break;

      current = current.resolve(location);
      final next = await client.getUrl(current);
      next.followRedirects = false;
      response = await next.close().timeout(_requestTimeout);
      hops++;
    }
    return response;
  }

  bool _isRedirect(int status) => status == 301 || status == 302 || status == 303;

  ReportUploadResult _parse(String text) {
    Object? decoded;
    try {
      decoded = jsonDecode(text);
    } catch (_) {
      decoded = null;
    }
    if (decoded is! Map<String, dynamic>) {
      debugPrint('$_tag Upload failed: response was not a valid JSON object');
      return ReportUploadResult.failure(
        'The report server returned an unreadable response.',
        code: 'BAD_RESPONSE',
      );
    }

    final success = decoded['success'] == true;
    final emailSent = decoded['email_sent'] == true;
    final fileId = decoded['file_id']?.toString();
    final fileUrl = decoded['file_url']?.toString();
    final error = decoded['error']?.toString();
    final errorCode = decoded['error_code']?.toString();
    // If the server doesn't say, assume a failure is worth retrying.
    final retryable = decoded['retryable'] is bool ? decoded['retryable'] as bool : !success;

    if (success) {
      debugPrint('$_tag Upload successful');
      debugPrint('$_tag Drive file ID: $fileId');
      if (emailSent) debugPrint('$_tag Email sent successfully');
    } else {
      debugPrint('$_tag Report not fully delivered: ${errorCode ?? 'unknown'} '
          '(fileSaved=${fileId != null}, retryable=$retryable)');
    }

    return ReportUploadResult(
      success: success,
      emailSent: emailSent,
      retryable: success ? false : retryable,
      fileId: fileId,
      fileUrl: fileUrl,
      error: error,
      errorCode: errorCode,
    );
  }
}
