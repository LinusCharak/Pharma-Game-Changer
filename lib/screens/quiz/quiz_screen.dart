import 'dart:async';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../models/quiz_category.dart';
import '../../models/quiz_question.dart';
import '../../models/quiz_question_attempt.dart';
import '../../models/quiz_result_data.dart';
import '../../models/user_profile.dart';
import '../../services/quiz_exceptions.dart';
import '../../services/quiz_result_service.dart';
import '../../services/quiz_service.dart';
import '../../services/session_service.dart';
import '../../theme/app_theme.dart';
import 'quiz_saving_screen.dart';

/// Bundles what a quiz needs to run: the trimmed/shuffled question list plus
/// the per-question countdown, both driven entirely by Supabase
/// (Question_Numbers.Number / .Time) — nothing here is hard-coded.
class _QuizSession {
  final List<QuizQuestion> questions;
  final int secondsPerQuestion;
  const _QuizSession({required this.questions, required this.secondsPerQuestion});
}

class QuizScreen extends StatefulWidget {
  final QuizCategory category;
  const QuizScreen({super.key, required this.category});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> with WidgetsBindingObserver {
  late final Future<_QuizSession> _future;
  List<QuizQuestion> _questions = const [];
  int _secondsPerQuestion = 0;
  int _index = 0;
  int _correct = 0;
  int? _selected; // -1 means "timed out with no selection"
  int _secondsLeft = 0;
  Timer? _timer;

  // Guards against a question being skipped more than once from repeated
  // lifecycle callbacks (Android/Flutter can fire several in a row for a
  // single real transition). Reset to false every time a new question
  // becomes current, so that question can be skipped later if the user
  // leaves again.
  bool _leftWhileUnanswered = false;

  // The exact answer history, one record per question, appended in the
  // order the questions were presented (see _recordAttempt). The detailed
  // PDF is built from THIS list -- never from a Supabase reload.
  final List<QuizQuestionAttempt> _attempts = [];

  // Captured when the quiz actually becomes usable (questions loaded),
  // not when this screen was built -- used for "Total Time Taken" on
  // the result screen. Read once here and reused, so QuizResultScreen
  // never has to touch Supabase/session storage itself.
  DateTime? _quizStartTime;
  UserProfile? _profile;
  String? _appVersion;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _future = _load();
    _future.then((session) {
      _questions = session.questions;
      _secondsPerQuestion = session.secondsPerQuestion;
      if (mounted && session.questions.isNotEmpty) {
        _quizStartTime = DateTime.now();
        _startTimer();
      }
    });

    // Local-storage read only (no Supabase call) -- plenty of time to
    // complete well before the result screen is ever reached.
    SessionService.instance.getCachedProfile().then((profile) {
      if (mounted) _profile = profile;
    });

    // Also local/cheap -- no network call, just reads the installed
    // package info -- for the quiz_results.app_version column.
    PackageInfo.fromPlatform().then((info) {
      if (mounted) _appVersion = info.version;
    });
  }

  /// Step 4 of the required flow: read Question_Numbers (Number + Time)
  /// *before* loading questions, then use Number as the fetch limit.
  Future<_QuizSession> _load() async {
    final config = await QuizService.instance.fetchQuizConfig();
    final questions = await QuizService.instance.fetchQuestions(
      widget.category.code,
      limit: config.questionCount,
    );
    return _QuizSession(questions: questions, secondsPerQuestion: config.secondsPerQuestion);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  // ============================================================
  // Skip-on-leave handling (pure Flutter lifecycle, no phone-call
  // exception -- an incoming call is treated exactly like any other
  // interruption, per this task's explicit requirement).
  // ============================================================

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // `paused` is the only state that means "genuinely backgrounded" --
    // `inactive` fires for transient things (notification shade,
    // permission dialogs, the app-switcher preview) and must not trigger
    // a skip by itself. `resumed` does nothing here on purpose: the skip
    // already happened when the app entered `paused`, so returning to
    // the app must never skip a second question.
    if (state != AppLifecycleState.paused) return;
    _skipIfUnanswered();
  }

  void _skipIfUnanswered() {
    if (_questions.isEmpty) return; // quiz still loading -- nothing to skip yet
    if (_selected != null) return; // already answered / mid-transition -- ignore
    if (_leftWhileUnanswered) return; // already skipped this exact question once

    debugPrint('Quiz: app backgrounded on an unanswered question -- skipping it');
    _leftWhileUnanswered = true;
    _timer?.cancel();
    // Path C of the answer history: this skip bypasses _selectAnswer(),
    // so it must be recorded here -- before _goToNext() advances _index.
    _recordAttempt(selectedIndex: null, status: QuizAttemptStatus.skipped);
    // Deliberately NOT calling _selectAnswer(null) here -- that method
    // performs the normal answer/timeout flow (sets _selected = -1,
    // shows correct/wrong colors, waits 700ms). Leaving the app is
    // neither an answer nor a timeout, so _goToNext() is called
    // directly instead, with no feedback shown and no delay.
    _goToNext();
  }

  // ============================================================
  // Existing quiz flow (unchanged except for resetting the skip guard
  // in _goToNext() when a new question becomes current)
  // ============================================================

  /// Appends the history record for the CURRENT question -- at most once
  /// per question number, so no code path can double-record or reorder.
  /// Snapshots the question exactly as displayed (text, all options,
  /// correct index) so the report matches what the MR actually saw.
  void _recordAttempt({
    required int? selectedIndex,
    required QuizAttemptStatus status,
  }) {
    final questionNumber = _index + 1;
    if (_attempts.any((a) => a.questionNumber == questionNumber)) return;
    _attempts.add(
      QuizQuestionAttempt.fromQuestion(
        questionNumber: questionNumber,
        question: _questions[_index],
        selectedIndex: selectedIndex,
        status: status,
      ),
    );
  }

  void _startTimer() {
    _timer?.cancel();
    _secondsLeft = _secondsPerQuestion; // never carries over between questions
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) {
        t.cancel();
        _selectAnswer(null);
      }
    });
  }

  void _selectAnswer(int? optionIndex) {
    if (_selected != null) return; // already answered
    _timer?.cancel();
    final question = _questions[_index];
    final isCorrect = optionIndex != null && optionIndex == question.correctIndex;
    if (isCorrect) {
      _correct++;
    }
    // Paths A and B of the answer history: a normal answer, or a timeout
    // (optionIndex == null) -- recorded once, before the feedback delay.
    _recordAttempt(
      selectedIndex: optionIndex,
      status: optionIndex == null
          ? QuizAttemptStatus.timeout
          : (isCorrect ? QuizAttemptStatus.correct : QuizAttemptStatus.wrong),
    );
    setState(() => _selected = optionIndex ?? -1);
    // Correct answers move on after 1s; wrong (and timed-out) answers
    // stay visible longer -- 3s -- so there's time to see the correct
    // option highlighted before advancing.
    final delay = isCorrect ? const Duration(seconds: 1) : const Duration(seconds: 3);
    Future.delayed(delay, _goToNext);
  }

  void _goToNext() {
    if (!mounted) return;
    if (_index + 1 >= _questions.length) {
      // Captured here, at the moment the quiz actually finishes -- not
      // inside QuizResultScreen/QuizSavingScreen, which would add an
      // artificial delay.
      final completedAt = DateTime.now();
      final totalTime = _quizStartTime != null
          ? completedAt.difference(_quizStartTime!)
          : Duration.zero;
      _finishQuiz(completedAt, totalTime);
      return;
    }
    setState(() {
      _index++;
      _selected = null;
      _leftWhileUnanswered = false; // new question -- guard applies fresh
    });
    _startTimer();
  }

  /// Resolves the profile needed to build QuizResultData, then builds it
  /// exactly once and hands off to QuizSavingScreen -- QuizResultScreen
  /// is NEVER shown without a successful Supabase upload first.
  ///
  /// _profile is normally already populated by the fire-and-forget fetch
  /// in initState() (it's had the whole quiz duration to complete). If
  /// it somehow still isn't, this makes one direct attempt here. Only if
  /// that also fails -- a genuinely exceptional case -- does this show a
  /// blocking error with Retry, which re-attempts this same precondition
  /// rather than bypassing straight to the result screen. No
  /// QuizResultData exists yet at that point, so there is nothing being
  /// "recreated" -- each retry is a fresh attempt at the one thing that
  /// hasn't succeeded yet: finding a profile to attribute the result to.
  Future<void> _finishQuiz(DateTime completedAt, Duration totalTime) async {
    var profile = _profile;
    profile ??= await SessionService.instance.getCachedProfile();

    if (!mounted) return;

    if (profile == null) {
      debugPrint('Quiz: no cached profile available -- cannot prepare a result to upload');
      final retry = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Unable to Save Quiz Result'),
          content: const Text(
            'Your signed-in profile could not be found, so this result cannot '
            'be saved yet. Please try again.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
      if (retry == true && mounted) {
        await _finishQuiz(completedAt, totalTime);
      }
      return;
    }

    final resultData = QuizResultData.fromQuiz(
      attemptUuid: QuizResultService.instance.generateAttemptUuid(),
      profile: profile,
      category: widget.category,
      correctAnswers: _correct,
      totalQuestions: _questions.length,
      totalTimeSeconds: totalTime.inSeconds,
      completedAt: completedAt,
      appVersion: _appVersion,
    );

    if (!mounted) return;
    debugPrint('[PGC PDF] Quiz finished: ${_attempts.length} attempt(s) recorded '
        'for ${_questions.length} question(s)');
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => QuizSavingScreen(
          resultData: resultData,
          // Unmodifiable copy: the report is built from exactly this.
          attempts: List<QuizQuestionAttempt>.unmodifiable(_attempts),
        ),
      ),
    );
  }

  Future<bool> _confirmExit() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Exit?'),
        content: const Text('Your quiz progress will be lost.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Yes')),
        ],
      ),
    );
    return leave ?? false;
  }

  String _errorMessage(Object error) {
    if (error is QuizConfigException) return error.message;
    if (error is QuizQuestionsException) return error.message;
    return "Couldn't load the quiz for \"${widget.category.label}\": $error";
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        _timer?.cancel();
        final shouldLeave = await _confirmExit();
        if (shouldLeave && mounted) {
          Navigator.of(context).pop();
        } else if (mounted && _questions.isNotEmpty && _selected == null) {
          _startTimer();
        }
      },
      child: Scaffold(
        appBar: AppBar(title: Text(widget.category.label)),
        body: FutureBuilder<_QuizSession>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, size: 40, color: AppColors.accent),
                      const SizedBox(height: 12),
                      Text(_errorMessage(snapshot.error!), textAlign: TextAlign.center),
                    ],
                  ),
                ),
              );
            }
            final questions = snapshot.data?.questions ?? const [];
            if (questions.isEmpty) {
              // A successful query that legitimately returned zero rows —
              // distinct from the error branch above.
              return Center(
                child: Text('No questions found for "${widget.category.label}" yet.'),
              );
            }
            final question = questions[_index];
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _ProgressHeader(
                    index: _index,
                    total: questions.length,
                    secondsLeft: _secondsLeft,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    question.question,
                    style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: ListView.separated(
                      itemCount: question.options.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, i) => _OptionButton(
                        text: question.options[i],
                        state: _optionState(i, question.correctIndex),
                        onTap: () => _selectAnswer(i),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  _OptionState _optionState(int optionIndex, int correctIndex) {
    if (_selected == null) return _OptionState.idle;
    if (optionIndex == correctIndex) return _OptionState.correct;
    if (optionIndex == _selected) return _OptionState.wrong;
    return _OptionState.disabled;
  }
}

enum _OptionState { idle, correct, wrong, disabled }

class _ProgressHeader extends StatelessWidget {
  final int index;
  final int total;
  final int secondsLeft;
  const _ProgressHeader({required this.index, required this.total, required this.secondsLeft});

  @override
  Widget build(BuildContext context) {
    final urgent = secondsLeft <= 5;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Question ${index + 1} / $total',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: total == 0 ? 0 : index / total,
                  minHeight: 6,
                  backgroundColor: const Color(0xFFE3E6F5),
                  valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: urgent ? Colors.red.withValues(alpha: 0.1) : AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '$secondsLeft s',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: urgent ? Colors.red.shade700 : AppColors.primary,
            ),
          ),
        ),
      ],
    );
  }
}

class _OptionButton extends StatelessWidget {
  final String text;
  final _OptionState state;
  final VoidCallback onTap;
  const _OptionButton({required this.text, required this.state, required this.onTap});

  @override
  Widget build(BuildContext context) {
    late final Color bg, fg, border;
    switch (state) {
      case _OptionState.idle:
        bg = Colors.white;
        fg = Colors.black87;
        border = const Color(0xFFCBD1EE);
        break;
      case _OptionState.correct:
        bg = const Color(0xFFDFF5E1);
        fg = const Color(0xFF1B5E20);
        border = const Color(0xFF43A047);
        break;
      case _OptionState.wrong:
        bg = const Color(0xFFFBE1E1);
        fg = const Color(0xFFB71C1C);
        border = const Color(0xFFE53935);
        break;
      case _OptionState.disabled:
        bg = Colors.white;
        fg = Colors.black38;
        border = const Color(0xFFE0E0E0);
        break;
    }
    return InkWell(
      onTap: state == _OptionState.idle ? onTap : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border, width: 1.4),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(text, style: TextStyle(color: fg, fontWeight: FontWeight.w600, fontSize: 15)),
            ),
            if (state == _OptionState.correct) const Icon(Icons.check_circle, color: Color(0xFF43A047)),
            if (state == _OptionState.wrong) const Icon(Icons.cancel, color: Color(0xFFE53935)),
          ],
        ),
      ),
    );
  }
}
