/// Configuration for the Google Apps Script web app that receives the
/// generated quiz-report PDF, saves it to Drive and emails the managers.
///
/// Neither value here is a real secret: anything compiled into an APK can
/// be extracted. The Supabase service-role key must NEVER be placed here
/// -- it lives only in the Apps Script project's Script Properties.
class AppsScriptConfig {
  /// The existing web app's "/exec" URL (Deploy -> Manage deployments).
  /// Editing the existing deployment to a New version keeps this URL.
  static const String reportWebAppUrl = 'https://script.google.com/macros/s/AKfycbwZDuYD3gJgL4tbkSKB-mp1LPbavwEB8Kd5yk63JgAKZ2BUpbOPI-66k98TGmQPoPjP/exec';

  /// Optional shared token. Leave empty to disable. If set here, set the
  /// same value in the Script Property REPORT_UPLOAD_TOKEN. This only
  /// deters casual scanners -- it is obscurity, not authentication.
  static const String uploadToken = '';

  static bool get isConfigured =>
      reportWebAppUrl.startsWith('https://script.google.com/');
}
