/// An item inside a Drive folder: a PDF, a sub-folder, or any other file.
class ClinicalTrialDocument {
  const ClinicalTrialDocument({
    required this.id,
    required this.name,
    required this.mimeType,
    this.sizeBytes,
    this.modifiedTime,
    this.webViewLink,
  });

  static const String folderMimeType = 'application/vnd.google-apps.folder';
  static const String pdfMimeType = 'application/pdf';

  final String id;
  final String name;
  final String mimeType;
  final int? sizeBytes;
  final DateTime? modifiedTime;
  final String? webViewLink;

  bool get isFolder => mimeType == folderMimeType;
  bool get isPdf => mimeType == pdfMimeType;

  /// File name without a trailing ".pdf", for display.
  String get displayTitle {
    final lower = name.toLowerCase();
    if (lower.endsWith('.pdf')) return name.substring(0, name.length - 4);
    return name;
  }

  /// Link that opens this item in Google Drive.
  String get driveUrl =>
      webViewLink ??
      (isFolder
          ? 'https://drive.google.com/drive/folders/$id'
          : 'https://drive.google.com/file/d/$id/view');

  factory ClinicalTrialDocument.fromDriveJson(Map<String, dynamic> json) {
    return ClinicalTrialDocument(
      id: json['id'] as String,
      name: (json['name'] as String?) ?? 'Untitled',
      mimeType: (json['mimeType'] as String?) ?? '',
      sizeBytes: int.tryParse('${json['size'] ?? ''}'),
      modifiedTime: DateTime.tryParse('${json['modifiedTime'] ?? ''}'),
      webViewLink: json['webViewLink'] as String?,
    );
  }

  /// Builds a document from a `clinical_trial_documents` Supabase row:
  /// { id, product_name, document_title, google_drive_url, sort_order,
  ///   is_active, created_at }.
  ///
  /// The Google Drive file id is *parsed* out of [google_drive_url] (never
  /// invented) so the existing Drive-API-based fetch/download/share/viewer
  /// pipeline in [ClinicalTrialService] keeps working unchanged. If the URL
  /// isn't in a recognised Drive file-link form, the document is marked as
  /// a generic (non-PDF) item so the UI falls back to opening
  /// [google_drive_url] directly instead of trying to fetch it in-app.
  factory ClinicalTrialDocument.fromSupabaseRow(Map<String, dynamic> row) {
    final url = (row['google_drive_url'] as String?) ?? '';
    final fileId = _driveFileIdFrom(url);
    return ClinicalTrialDocument(
      id: fileId ?? 'row_${row['id']}',
      name: (row['document_title'] as String?) ?? 'Untitled',
      mimeType: fileId != null ? pdfMimeType : '',
      webViewLink: url.isEmpty ? null : url,
    );
  }

  static final RegExp _fileIdInPath = RegExp(r'/file/d/([A-Za-z0-9_-]+)');
  static final RegExp _fileIdInQuery = RegExp(r'[?&]id=([A-Za-z0-9_-]+)');

  /// Parses a Google Drive file id out of common share-link shapes:
  ///   https://drive.google.com/file/d/<id>/view?usp=sharing
  ///   https://drive.google.com/open?id=<id>
  ///   https://drive.google.com/uc?id=<id>&export=download
  /// Returns null if none match (URL is not a recognised Drive file link).
  static String? _driveFileIdFrom(String url) {
    final pathMatch = _fileIdInPath.firstMatch(url);
    if (pathMatch != null) return pathMatch.group(1);
    final queryMatch = _fileIdInQuery.firstMatch(url);
    if (queryMatch != null) return queryMatch.group(1);
    return null;
  }
}
