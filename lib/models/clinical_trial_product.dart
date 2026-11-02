/// One product entry on the Clinical Trials screen.
///
/// [name] and [folderUrl] come verbatim from the original Kodular project
/// (button text and ActivityStarter.DataUri). The Google Drive folder URL is
/// the source of truth and is never rewritten; [folderId] is only *parsed*
/// from it (for the Drive API) and the URL itself is still used for
/// "Open in Google Drive".
class ClinicalTrialProduct {
  const ClinicalTrialProduct({
    required this.name,
    required this.folderUrl,
  });

  final String name;
  final String folderUrl;

  static final RegExp _folderIdPattern = RegExp(r'/folders/([A-Za-z0-9_-]+)');

  /// The Drive folder ID parsed from [folderUrl], or null if the URL is not
  /// in the `/drive/folders/<id>` form.
  String? get folderId => _folderIdPattern.firstMatch(folderUrl)?.group(1);
}
