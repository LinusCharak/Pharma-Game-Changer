import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../models/quiz_question_attempt.dart';
import '../../models/quiz_result_data.dart';
import '../../services/apps_script_upload_service.dart';
import '../../services/quiz_pdf_service.dart';
import '../../services/quiz_result_service.dart';
import '../../theme/app_theme.dart';
import 'quiz_result_screen.dart';

enum _Phase { savingResult, resultSaveFailed, sendingReport, reportFailed }

/// Shown immediately after the final question, BEFORE QuizResultScreen.
///
/// Two stages, in order:
///  1. Upload the summary [resultData] to Supabase (unchanged behavior:
///     retry-safe via attempt_uuid upsert).
///  2. Generate the detailed PDF ONCE from [attempts], then send those
///     same bytes to Apps Script (Drive + manager email). A failed
///     attempt retries the SAME bytes with the SAME attempt_uuid.
///
/// QuizResultScreen is only reached once both stages have succeeded. If
/// stage 2 fails, the Supabase result stays saved (stage 1 is never
/// repeated) and the MR sees "Result Saved, Report Not Sent" with Retry
/// Report -- there is deliberately no way to skip ahead to the result.
class QuizSavingScreen extends StatefulWidget {
  final QuizResultData resultData;

  /// The exact answer history captured during the quiz, in presentation
  /// order. Used only to build the report; nothing is re-fetched.
  final List<QuizQuestionAttempt> attempts;

  const QuizSavingScreen({
    super.key,
    required this.resultData,
    required this.attempts,
  });

  @override
  State<QuizSavingScreen> createState() => _QuizSavingScreenState();
}

class _QuizSavingScreenState extends State<QuizSavingScreen> {
  _Phase _phase = _Phase.savingResult;

  // Once the summary row is confirmed saved it is never re-uploaded.
  bool _resultSaved = false;

  // Generated once, kept for every retry of the report upload.
  Uint8List? _pdfBytes;

  @override
  void initState() {
    super.initState();
    _run();
  }

  /// Entry point for first run and for every retry button: stage 1 is
  /// skipped if it already succeeded, so only the failed stage repeats.
  Future<void> _run() async {
    if (!_resultSaved) {
      setState(() => _phase = _Phase.savingResult);
      try {
        await QuizResultService.instance.uploadQuizResult(widget.resultData);
        _resultSaved = true;
      } catch (_) {
        // QuizResultService already debugPrint-ed the real technical
        // error -- the UI only ever shows the friendly message.
        if (!mounted) return;
        setState(() => _phase = _Phase.resultSaveFailed);
        return;
      }
      if (!mounted) return;
    }
    await _sendReport();
  }

  Future<void> _sendReport() async {
    if (!mounted) return;
    setState(() => _phase = _Phase.sendingReport);

    try {
      // Generate once; a retry re-uses these exact bytes.
      _pdfBytes ??= await QuizPdfService.instance.generate(
        resultData: widget.resultData,
        attempts: widget.attempts,
      );

      final result = await AppsScriptUploadService.instance.uploadReport(
        attemptUuid: widget.resultData.attemptUuid,
        fileName: QuizPdfService.buildFileName(widget.resultData),
        pdfBytes: _pdfBytes!,
      );

      if (!mounted) return;
      if (result.canProceed) {
        _goToResult();
        return;
      }
      debugPrint('[PGC PDF] Report not delivered: ${result.errorCode} ${result.error}');
      setState(() => _phase = _Phase.reportFailed);
    } catch (e) {
      debugPrint('[PGC PDF] Report step failed: $e');
      if (!mounted) return;
      setState(() => _phase = _Phase.reportFailed);
    }
  }

  void _goToResult() {
    final r = widget.resultData;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => QuizResultScreen(
          category: r.category,
          correct: r.correctAnswers,
          total: r.totalQuestions,
          completedAt: r.completedAt,
          totalTime: Duration(seconds: r.totalTimeSeconds),
          userName: r.userName,
          hq: r.hq,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Widget content;
    switch (_phase) {
      case _Phase.savingResult:
        content = const _BusyContent(
          title: 'Saving Your Result',
          message: 'Please wait while your quiz result is being saved.',
        );
        break;
      case _Phase.resultSaveFailed:
        content = _FailedContent(
          title: 'Unable to Save Quiz Result',
          message: 'Your quiz was completed, but the result could not be uploaded to '
              'the server. Please check your internet connection and try again.',
          buttonLabel: 'Retry Upload',
          onRetry: _run,
        );
        break;
      case _Phase.sendingReport:
        content = const _BusyContent(
          title: 'Preparing Your Report',
          message: 'Your result has been saved. Please wait while your detailed '
              'quiz report is prepared and sent.',
        );
        break;
      case _Phase.reportFailed:
        content = _FailedContent(
          title: 'Result Saved, Report Not Sent',
          message: 'Your quiz result has been saved, but the detailed report could not '
              'be sent. Please check your internet connection and try again.',
          buttonLabel: 'Retry Report',
          onRetry: _run,
        );
        break;
    }

    return PopScope(
      // Back is blocked while work is in flight AND while the report is
      // unsent (leaving would abandon the report). It is allowed only on
      // the original "Unable to Save Quiz Result" screen, exactly as
      // before this feature existed.
      canPop: _phase == _Phase.resultSaveFailed,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}

class _BusyContent extends StatelessWidget {
  final String title;
  final String message;
  const _BusyContent({required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CircularProgressIndicator(color: AppColors.primary),
        const SizedBox(height: 24),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary),
        ),
        const SizedBox(height: 12),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.black54),
        ),
      ],
    );
  }
}

class _FailedContent extends StatelessWidget {
  final String title;
  final String message;
  final String buttonLabel;
  final VoidCallback onRetry;
  const _FailedContent({
    required this.title,
    required this.message,
    required this.buttonLabel,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.cloud_off, size: 56, color: AppColors.accent),
        const SizedBox(height: 16),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.black54),
        ),
        const SizedBox(height: 24),
        ElevatedButton(onPressed: onRetry, child: Text(buttonLabel)),
      ],
    );
  }
}
