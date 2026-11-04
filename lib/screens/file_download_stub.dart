/// Android / iOS: not used (ReminderDownloadService saves the file there).
Future<void> downloadFileFromUrl(String url, String fileName) async {
  throw UnsupportedError('Browser download is only available on the web.');
}
