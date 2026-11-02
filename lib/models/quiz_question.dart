/// One multiple-choice question, read from a per-topic Supabase table
/// (columns: Question, Option1, Option2, Option3, Option4, Answer).
/// `Answer` is stored 1-based (1..4) to match the original spreadsheet;
/// we convert it to a 0-based [correctIndex] for use in the UI.
class QuizQuestion {
  final String question;
  final List<String> options;
  final int correctIndex;

  const QuizQuestion({
    required this.question,
    required this.options,
    required this.correctIndex,
  });

  factory QuizQuestion.fromRow(Map<String, dynamic> row) {
    final options = [
      (row['Option1'] ?? '').toString(),
      (row['Option2'] ?? '').toString(),
      (row['Option3'] ?? '').toString(),
      (row['Option4'] ?? '').toString(),
    ];
    final answerNum = int.tryParse('${row['Answer'] ?? ''}'.trim()) ?? 1;
    return QuizQuestion(
      question: (row['Question'] ?? '').toString(),
      options: options,
      correctIndex: (answerNum - 1).clamp(0, options.length - 1).toInt(),
    );
  }
}
