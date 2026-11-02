import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/quiz_category.dart';
import '../../theme/app_theme.dart';
import 'quiz_screen.dart';

/// Shows a full summary of a completed quiz, and lets the user share it
/// as a PNG image (not plain text) of the result content -- the quiz
/// data itself (category/score/duration/profile) is received as-is from
/// QuizScreen, never recalculated or re-fetched here.
class QuizResultScreen extends StatefulWidget {
  final QuizCategory category;
  final int correct;
  final int total;

  /// From the signed-in rep's cached profile (SessionService), read by
  /// QuizScreen -- null only in the unusual case where no profile is
  /// cached, in which case that row is simply omitted below.
  final String? userName;
  final String? hq;

  /// Captured by QuizScreen the instant the quiz actually finished.
  final DateTime completedAt;

  /// Real elapsed wall-clock time from quiz start to finish, including
  /// every answer-feedback delay -- NOT questionCount * secondsPerQuestion.
  final Duration totalTime;

  const QuizResultScreen({
    super.key,
    required this.category,
    required this.correct,
    required this.total,
    required this.completedAt,
    required this.totalTime,
    this.userName,
    this.hq,
  });

  int get percentage => total == 0 ? 0 : ((correct / total) * 100).round();

  /// Single source of truth for the score color -- used for both the
  /// on-screen percentage and the shared image, per the required
  /// boundaries: <60 red, 60-79 orange, >=80 green.
  Color get scoreColor {
    if (percentage < 60) return Colors.red;
    if (percentage < 80) return Colors.orange;
    return Colors.green;
  }

  String get formattedDateTime {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    final hour24 = completedAt.hour;
    final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
    final minute = completedAt.minute.toString().padLeft(2, '0');
    final period = hour24 >= 12 ? 'PM' : 'AM';
    return '${completedAt.day} ${months[completedAt.month - 1]} ${completedAt.year}, $hour12:$minute $period';
  }

  String get formattedDuration {
    final totalSeconds = totalTime.inSeconds;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    final secondsStr = seconds.toString().padLeft(2, '0');
    if (minutes == 0) return '$secondsStr seconds';
    final minuteWord = minutes == 1 ? 'minute' : 'minutes';
    final minutesStr = minutes.toString().padLeft(2, '0');
    return '$minutesStr $minuteWord $secondsStr seconds';
  }

  @override
  State<QuizResultScreen> createState() => _QuizResultScreenState();
}

class _QuizResultScreenState extends State<QuizResultScreen> {
  final _resultBoundaryKey = GlobalKey();
  bool _isSharing = false;

  Future<void> _shareResult() async {
    if (_isSharing) return; // guard against overlapping share operations
    setState(() => _isSharing = true);

    try {
      final boundary =
          _resultBoundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        throw Exception('Result content is not ready yet.');
      }

      // pixelRatio 2.0: sharp enough to stay readable after WhatsApp's
      // own compression, without producing an unnecessarily huge file.
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw Exception('Could not encode the result image.');
      }
      final pngBytes = byteData.buffer.asUint8List();

      final tempDir = await getTemporaryDirectory();
      final shareDir = Directory('${tempDir.path}/quiz_result_share');
      if (!await shareDir.exists()) {
        await shareDir.create(recursive: true);
      }
      final file = File('${shareDir.path}/quiz_result.png');
      await file.writeAsBytes(pngBytes, flush: true);

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png')],
        subject: 'Pharma Game Changer - Quiz Result',
      );
    } catch (e) {
      debugPrint('QuizResultScreen: failed to share result image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to create the result image. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quiz Result'), automaticallyImplyLeading: false),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Everything the shared image should contain -- and ONLY
              // that -- lives inside this boundary. No AppBar, no
              // buttons, no Android system UI.
              RepaintBoundary(
                key: _resultBoundaryKey,
                child: Container(
                  width: double.infinity,
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Text(
                        'Quiz Result',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                      const SizedBox(height: 12),
                      _InfoRow(label: 'PRODUCT NAME', value: widget.category.label),
                      if (widget.userName != null && widget.userName!.isNotEmpty)
                        _InfoRow(label: 'Name', value: widget.userName!),
                      if (widget.hq != null && widget.hq!.isNotEmpty)
                        _InfoRow(label: 'HQ', value: widget.hq!),
                      _InfoRow(label: 'Completed On', value: widget.formattedDateTime),
                      _InfoRow(label: 'Total Time Taken', value: widget.formattedDuration),
                      const SizedBox(height: 20),
                      Text(
                        '${widget.correct} / ${widget.total} correct',
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${widget.percentage}%',
                        style: TextStyle(
                          fontSize: 44,
                          fontWeight: FontWeight.w900,
                          color: widget.scoreColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => QuizScreen(category: widget.category)),
                ),
                child: const Text('Retry This Topic'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Back to Topics'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _isSharing ? null : _shareResult,
                icon: _isSharing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.share),
                label: Text(_isSharing ? 'Preparing...' : 'Share Result'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
