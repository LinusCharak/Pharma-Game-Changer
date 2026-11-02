import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

/// Replaces the custom dialog the original screen built from
/// `Notifier3` + `Vertical_Arrangement3` (a Lottie animation, a
/// bold "downloaded to GameChanger folder" message, and an OK
/// button that dismissed the dialog and paused the animation).
///
/// Pass your own Lottie asset path via [lottieAsset]; if omitted a
/// simple built-in check animation is used instead so this widget
/// works out of the box.
class DownloadSuccessDialog extends StatefulWidget {
  const DownloadSuccessDialog({
    super.key,
    this.folderName = 'GameChanger',
    this.lottieAsset,
  });

  final String folderName;
  final String? lottieAsset;

  @override
  State<DownloadSuccessDialog> createState() => _DownloadSuccessDialogState();
}

class _DownloadSuccessDialogState extends State<DownloadSuccessDialog> {
  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 20),
            SizedBox(
              height: 150,
              width: 150,
              child: widget.lottieAsset != null
                  ? Lottie.asset(widget.lottieAsset!, repeat: false)
                  : const Icon(Icons.check_circle,
                      size: 96, color: Colors.green),
            ),
            const SizedBox(height: 20),
            Text.rich(
              TextSpan(
                style: const TextStyle(fontSize: 18),
                children: [
                  const TextSpan(text: 'The image has been downloaded to '),
                  TextSpan(
                    text: widget.folderName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const TextSpan(text: ' folder in Download folder'),
                ],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2196F2),
                foregroundColor: Colors.white,
                minimumSize: const Size(150, 40),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
