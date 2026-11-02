import 'quiz_question.dart';

/// How a question ended. Kept as four distinct outcomes because a manager
/// reading the report needs to tell them apart:
///  - [timeout]: the question was shown and the countdown ran out.
///  - [skipped]: the MR left the app while the question was unanswered
///    (the existing background-skip behavior in QuizScreen).
enum QuizAttemptStatus {
  correct('CORRECT'),
  wrong('WRONG'),
  timeout('TIME OUT'),
  skipped('SKIPPED (APP LEFT)');

  final String label;
  const QuizAttemptStatus(this.label);
}

/// A snapshot of ONE question exactly as it was presented and resolved
/// during the quiz. QuizScreen appends exactly one of these per question,
/// in presentation order, so the detailed PDF can be built from what the
/// MR actually saw -- never from a later Supabase reload.
class QuizQuestionAttempt {
  /// 1-based position in the order the questions were presented.
  final int questionNumber;

  final String questionText;

  /// The options exactly as displayed (index 0 == "Option 1").
  final List<String> options;

  /// 0-based index of the correct option, as used by the quiz itself.
  final int correctIndex;

  /// 0-based index the MR selected, or null if no answer was given
  /// (timeout / skipped).
  final int? selectedIndex;

  final QuizAttemptStatus status;

  const QuizQuestionAttempt({
    required this.questionNumber,
    required this.questionText,
    required this.options,
    required this.correctIndex,
    required this.selectedIndex,
    required this.status,
  });

  factory QuizQuestionAttempt.fromQuestion({
    required int questionNumber,
    required QuizQuestion question,
    required QuizAttemptStatus status,
    int? selectedIndex,
  }) {
    return QuizQuestionAttempt(
      questionNumber: questionNumber,
      questionText: question.question,
      options: List<String>.unmodifiable(question.options),
      correctIndex: question.correctIndex,
      selectedIndex: selectedIndex,
      status: status,
    );
  }

  bool get wasAnswered => selectedIndex != null;
}
