import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/quiz_question_attempt.dart';
import '../models/quiz_result_data.dart';

/// Builds the detailed "Quiz Performance Report" PDF, entirely on the
/// device, from the answer history QuizScreen captured DURING the quiz.
///
/// The question list is never reloaded from Supabase and never re-sorted:
/// the report shows [attempts] in the exact order given, and loops over
/// however many there are (1, 10, 50 ...) -- no question count is
/// hard-coded anywhere in this file.
class QuizPdfService {
  QuizPdfService._();

  static final QuizPdfService instance = QuizPdfService._();

  static const _tag = '[PGC PDF]';

  pw.Font? _regular;
  pw.Font? _bold;

  // ---- palette (status is ALSO always spelled out in text, so the
  // report stays readable when printed in grayscale) ----
  static final PdfColor _navy = PdfColor.fromHex('#1A237E');
  static final PdfColor _green = PdfColor.fromHex('#2E7D32');
  static final PdfColor _greenFill = PdfColor.fromHex('#E8F5E9');
  static final PdfColor _red = PdfColor.fromHex('#C62828');
  static final PdfColor _redFill = PdfColor.fromHex('#FDECEA');
  static final PdfColor _orange = PdfColor.fromHex('#EF6C00');
  static final PdfColor _slate = PdfColor.fromHex('#546E7A');

  /// Same naming idea as the Apps Script side:
  /// PGC_Quiz_Report_<MR>_<Product>_<first 8 of attempt UUID>.pdf
  static String buildFileName(QuizResultData r) {
    String clean(String value, int maxLength) {
      var v = value
          .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
          .replaceAll(RegExp(r'\s+'), '_')
          .trim();
      if (v.isEmpty) v = 'Unknown';
      return v.length > maxLength ? v.substring(0, maxLength) : v;
    }

    final shortId =
        r.attemptUuid.length >= 8 ? r.attemptUuid.substring(0, 8) : r.attemptUuid;
    return 'PGC_Quiz_Report_${clean(r.userName, 40)}_${clean(r.category.label, 40)}_$shortId.pdf';
  }

  Future<Uint8List> generate({
    required QuizResultData resultData,
    required List<QuizQuestionAttempt> attempts,
  }) async {
    debugPrint('$_tag Starting PDF generation');
    debugPrint('$_tag Questions: ${attempts.length}');

    await _ensureFonts();
    _warnOnInconsistency(resultData, attempts);

    Uint8List bytes;
    try {
      bytes = await _build(resultData, attempts, boxed: true);
    } catch (e) {
      // A boxed (unsplittable) question block taller than a whole page
      // can't be placed. Rebuild with the flat, splittable layout rather
      // than failing the report.
      debugPrint('$_tag Boxed layout failed ($e) -- retrying with flat layout');
      bytes = await _build(resultData, attempts, boxed: false);
    }

    debugPrint('$_tag PDF generated: ${bytes.length} bytes');
    return bytes;
  }

  // ============================================================
  // Fonts
  // ============================================================

  Future<void> _ensureFonts() async {
    if (_regular != null && _bold != null) return;
    try {
      final regularData = await rootBundle.load('assets/fonts/NotoSans-Regular.ttf');
      final boldData = await rootBundle.load('assets/fonts/NotoSans-Bold.ttf');
      _regular = pw.Font.ttf(regularData);
      _bold = pw.Font.ttf(boldData);
    } catch (e) {
      // Never let a missing font asset block the report entirely: fall
      // back to the built-in Latin font (unusual symbols may not render).
      debugPrint('$_tag Noto Sans asset unavailable ($e) -- using built-in Helvetica');
      _regular = pw.Font.helvetica();
      _bold = pw.Font.helveticaBold();
    }
  }

  void _warnOnInconsistency(QuizResultData r, List<QuizQuestionAttempt> attempts) {
    final correct = attempts.where((a) => a.status == QuizAttemptStatus.correct).length;
    if (attempts.length != r.totalQuestions) {
      debugPrint('$_tag WARNING: attempts (${attempts.length}) != totalQuestions (${r.totalQuestions})');
    }
    if (correct != r.correctAnswers) {
      debugPrint('$_tag WARNING: correct in history ($correct) != correctAnswers (${r.correctAnswers})');
    }
  }

  // ============================================================
  // Document
  // ============================================================

  Future<Uint8List> _build(
    QuizResultData r,
    List<QuizQuestionAttempt> attempts, {
    required bool boxed,
  }) async {
    final doc = pw.Document(
      title: 'PGC Quiz Performance Report',
      author: 'Pharma Game Changer - Charak Pharma Pvt Ltd',
      creator: 'Pharma Game Changer',
    );

    final theme = pw.ThemeData.withFont(base: _regular, bold: _bold);

    doc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.fromLTRB(36, 40, 36, 40),
          theme: theme,
        ),
        // MultiPage's default (20) is a debug-mode guard that a long
        // 50-question report could trip -- raised well above any real use.
        maxPages: 500,
        header: (ctx) => ctx.pageNumber == 1 ? pw.SizedBox() : _runningHeader(),
        footer: (ctx) => _footer(ctx, r),
        build: (ctx) => [
          ..._summarySection(r, attempts),
          pw.NewPage(),
          ..._analysisHeading(attempts),
          for (final a in attempts) _questionBlock(a, boxed: boxed),
        ],
      ),
    );

    return doc.save();
  }

  // ---- text styles ----

  pw.TextStyle _style({double size = 10, bool bold = false, PdfColor? color}) {
    return pw.TextStyle(
      fontSize: size,
      fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
      color: color,
    );
  }

  // ---- header / footer ----

  pw.Widget _runningHeader() {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 10),
      padding: const pw.EdgeInsets.only(bottom: 4),
      decoration: pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: _navy, width: 0.8)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('CHARAK PHARMA PVT LTD', style: _style(size: 8, bold: true, color: _navy)),
          pw.Text('QUIZ PERFORMANCE REPORT', style: _style(size: 8, color: PdfColors.grey700)),
        ],
      ),
    );
  }

  pw.Widget _footer(pw.Context ctx, QuizResultData r) {
    return pw.Column(
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.Divider(color: PdfColors.grey400, thickness: 0.5),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Pharma Game Changer | Charak Pharma Pvt Ltd',
              style: _style(size: 8, color: PdfColors.grey700),
            ),
            pw.Text(
              'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
              style: _style(size: 8, color: PdfColors.grey700),
            ),
          ],
        ),
        pw.SizedBox(height: 2),
        pw.Align(
          alignment: pw.Alignment.centerLeft,
          child: pw.Text(
            'Attempt ID: ${r.attemptUuid}   |   Generated automatically',
            style: _style(size: 7, color: PdfColors.grey600),
          ),
        ),
      ],
    );
  }

  // ---- page 1: summary ----

  List<pw.Widget> _summarySection(QuizResultData r, List<QuizQuestionAttempt> attempts) {
    final scoreColor = _scoreColor(r.percentage);
    int count(QuizAttemptStatus s) => attempts.where((a) => a.status == s).length;

    return [
      pw.Center(
        child: pw.Text('CHARAK PHARMA PVT LTD', style: _style(size: 18, bold: true, color: _navy)),
      ),
      pw.SizedBox(height: 2),
      pw.Center(child: pw.Text('PHARMA GAME CHANGER', style: _style(size: 13, bold: true))),
      pw.SizedBox(height: 2),
      pw.Center(
        child: pw.Text('QUIZ PERFORMANCE REPORT', style: _style(size: 11, color: PdfColors.grey700)),
      ),
      pw.SizedBox(height: 8),
      pw.Divider(color: _navy, thickness: 1.2),
      pw.SizedBox(height: 8),

      // Prominent score block
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: scoreColor, width: 1.5),
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
          children: [
            pw.Column(
              children: [
                pw.Text('SCORE', style: _style(size: 9, bold: true, color: PdfColors.grey700)),
                pw.Text('${r.percentage}%', style: _style(size: 32, bold: true, color: scoreColor)),
              ],
            ),
            pw.Column(
              children: [
                pw.Text('CORRECT ANSWERS', style: _style(size: 9, bold: true, color: PdfColors.grey700)),
                pw.SizedBox(height: 6),
                pw.Text('${r.correctAnswers} / ${r.totalQuestions}', style: _style(size: 22, bold: true)),
              ],
            ),
          ],
        ),
      ),

      _sectionHeading('PARTICIPANT DETAILS'),
      _kvTable([
        ['Name', _orDash(r.userName)],
        ['Username', _orDash(r.username)],
        ['Designation', _orDash(r.designation)],
        ['HQ', _orDash(r.hq)],
        ['Zone', _orDash(r.zone)],
      ]),

      _sectionHeading('REPORTING MANAGERS'),
      _kvTable([
        ['ASM Name', _orDash(r.asmName)],
        ['ASM HQ', _orDash(r.asmHq)],
        ['RSM Name', _orDash(r.rsmName)],
        ['RSM HQ', _orDash(r.rsmHq)],
      ]),

      _sectionHeading('QUIZ DETAILS'),
      _kvTable([
        ['Product', _orDash(r.category.label)],
        ['Total Questions', '${r.totalQuestions}'],
        ['Correct Answers', '${r.correctAnswers}'],
        ['Score', '${r.percentage}%'],
        [
          'Answer Breakdown',
          'Correct ${count(QuizAttemptStatus.correct)}, '
              'Wrong ${count(QuizAttemptStatus.wrong)}, '
              'Time Out ${count(QuizAttemptStatus.timeout)}, '
              'Skipped ${count(QuizAttemptStatus.skipped)}',
        ],
        ['Total Time', _formatDuration(r.totalTimeSeconds)],
        ['Completed Date', _formatDate(r.completedAt)],
        ['Completed Time', _formatTime(r.completedAt)],
        ['App Version', _orDash(r.appVersion)],
      ]),
    ];
  }

  pw.Widget _sectionHeading(String text) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 14, bottom: 6),
      padding: const pw.EdgeInsets.only(bottom: 3),
      decoration: pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: _navy, width: 0.8)),
      ),
      child: pw.Align(
        alignment: pw.Alignment.centerLeft,
        child: pw.Text(text, style: _style(size: 11, bold: true, color: _navy)),
      ),
    );
  }

  pw.Widget _kvTable(List<List<String>> rows) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
      columnWidths: {
        0: const pw.FixedColumnWidth(130),
        1: const pw.FlexColumnWidth(),
      },
      children: [
        for (final row in rows)
          pw.TableRow(
            children: [
              pw.Container(
                color: PdfColors.grey200,
                padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: pw.Text(row[0], style: _style(size: 9.5, bold: true)),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: pw.Text(row[1], style: _style(size: 9.5)),
              ),
            ],
          ),
      ],
    );
  }

  // ---- detailed analysis ----

  List<pw.Widget> _analysisHeading(List<QuizQuestionAttempt> attempts) {
    return [
      pw.Text('DETAILED QUESTION ANALYSIS', style: _style(size: 14, bold: true, color: _navy)),
      pw.SizedBox(height: 3),
      pw.Text(
        'Questions are listed in the exact order they were presented. '
        'Total questions presented: ${attempts.length}.',
        style: _style(size: 9, color: PdfColors.grey700),
      ),
      pw.SizedBox(height: 2),
      pw.Text(
        'TIME OUT = no answer within the allowed time.   '
        'SKIPPED (APP LEFT) = the user left the app while the question was displayed.',
        style: _style(size: 8, color: PdfColors.grey700),
      ),
      pw.SizedBox(height: 10),
    ];
  }

  pw.Widget _questionBlock(QuizQuestionAttempt a, {required bool boxed}) {
    final color = _statusColor(a.status);

    final content = <pw.Widget>[
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Expanded(
            child: pw.Text(
              'QUESTION ${a.questionNumber}',
              style: _style(size: 11, bold: true, color: _navy),
            ),
          ),
          _statusBadge(a.status),
        ],
      ),
      pw.SizedBox(height: 6),
      pw.Text(_orBlank(a.questionText), style: _style(size: 10.5, bold: true)),
      pw.SizedBox(height: 6),
      for (var i = 0; i < a.options.length; i++) _optionRow(a, i),
    ];

    if (boxed) {
      return pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 10),
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: color, width: 1.2),
          borderRadius: pw.BorderRadius.circular(5),
        ),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: content),
      );
    }

    // Flat layout: a single Column is splittable across pages.
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Divider(color: color, thickness: 1.2),
        ...content,
        pw.SizedBox(height: 10),
      ],
    );
  }

  pw.Widget _statusBadge(QuizAttemptStatus status) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: pw.BoxDecoration(
        color: _statusColor(status),
        borderRadius: pw.BorderRadius.circular(3),
      ),
      child: pw.Text(status.label, style: _style(size: 8.5, bold: true, color: PdfColors.white)),
    );
  }

  pw.Widget _optionRow(QuizQuestionAttempt a, int i) {
    final isCorrect = i == a.correctIndex;
    final isSelected = a.selectedIndex == i;

    PdfColor? fill;
    PdfColor? border;
    if (isCorrect) {
      fill = _greenFill;
      border = _green;
    } else if (isSelected) {
      fill = _redFill;
      border = _red;
    }

    // Spelled-out tags so the meaning survives grayscale printing.
    String? tag;
    if (isSelected && isCorrect) {
      tag = "USER'S ANSWER - CORRECT";
    } else if (isSelected) {
      tag = "USER'S ANSWER - WRONG";
    } else if (isCorrect) {
      tag = 'CORRECT ANSWER';
    }

    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 3),
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: pw.BoxDecoration(
        color: fill,
        border: border == null ? null : pw.Border.all(color: border, width: 0.8),
        borderRadius: pw.BorderRadius.circular(3),
      ),
      child: pw.RichText(
        text: pw.TextSpan(
          style: _style(size: 10),
          children: [
            pw.TextSpan(text: 'Option ${i + 1}: ', style: _style(size: 10, bold: true)),
            pw.TextSpan(
              text: _orBlank(a.options[i]),
              style: _style(size: 10, bold: isCorrect),
            ),
            if (tag != null)
              pw.TextSpan(text: '    [$tag]', style: _style(size: 9, bold: true)),
          ],
        ),
      ),
    );
  }

  PdfColor _statusColor(QuizAttemptStatus s) {
    switch (s) {
      case QuizAttemptStatus.correct:
        return _green;
      case QuizAttemptStatus.wrong:
        return _red;
      case QuizAttemptStatus.timeout:
        return _orange;
      case QuizAttemptStatus.skipped:
        return _slate;
    }
  }

  /// Same boundaries as the result screen: <60 red, 60-79 orange, >=80 green.
  PdfColor _scoreColor(int percent) {
    if (percent < 60) return _red;
    if (percent < 80) return _orange;
    return _green;
  }

  // ---- formatting (device local time, matching QuizResultScreen) ----

  String _orDash(String? v) => (v == null || v.trim().isEmpty) ? '-' : v;
  String _orBlank(String? v) => (v == null || v.trim().isEmpty) ? '(blank)' : v;

  String _formatDate(DateTime d) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return '${d.day.toString().padLeft(2, '0')} ${months[d.month - 1]} ${d.year}';
  }

  String _formatTime(DateTime d) {
    final hour12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final minute = d.minute.toString().padLeft(2, '0');
    final period = d.hour >= 12 ? 'PM' : 'AM';
    return '${hour12.toString().padLeft(2, '0')}:$minute $period';
  }

  String _formatDuration(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    if (minutes == 0) return '$seconds seconds';
    final word = minutes == 1 ? 'minute' : 'minutes';
    return '${minutes.toString().padLeft(2, '0')} $word $seconds seconds';
  }
}
