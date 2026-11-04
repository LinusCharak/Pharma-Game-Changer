import 'dart:html' as html;

/// Chrome / web: downloads [url] through the browser's normal download
/// (it lands in the browser's Downloads folder).
///
/// The file is fetched first and saved from memory, which works for images
/// on another website (such as Cloudinary) as long as that site allows
/// cross-origin reads. If it does not, the image is opened in a new tab
/// instead, from where it can be saved with right-click -> Save image as.
Future<void> downloadFileFromUrl(String url, String fileName) async {
  final safeName = fileName
      .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
      .trim();
  final name = safeName.isEmpty ? 'download' : safeName;

  try {
    final request = await html.HttpRequest.request(
      url,
      method: 'GET',
      responseType: 'blob',
    );

    final blob = request.response as html.Blob;
    final objectUrl = html.Url.createObjectUrlFromBlob(blob);

    final extension = _extensionFor(url, blob.type);

    final anchor = html.AnchorElement(href: objectUrl)
      ..download = name.contains('.') ? name : '$name$extension'
      ..style.display = 'none';

    html.document.body?.append(anchor);
    anchor.click();
    anchor.remove();

    html.Url.revokeObjectUrl(objectUrl);
  } catch (_) {
    html.window.open(url, '_blank');
  }
}

String _extensionFor(String url, String mimeType) {
  if (mimeType == 'image/png') return '.png';
  if (mimeType == 'image/jpeg') return '.jpg';
  if (mimeType == 'image/webp') return '.webp';
  if (mimeType == 'image/gif') return '.gif';

  final path = Uri.tryParse(url)?.path.toLowerCase() ?? '';
  for (final ext in ['.png', '.jpg', '.jpeg', '.webp', '.gif']) {
    if (path.endsWith(ext)) return ext;
  }
  return '.jpg';
}
