/// The live quiz settings read from Supabase's Question_Numbers table
/// (columns: Number, Time). Nothing here is ever hard-coded in the app —
/// change a value in Supabase and the next quiz picks it up automatically.
class QuizConfig {
  /// How many questions a quiz uses (Question_Numbers.Number).
  final int questionCount;

  /// Seconds allowed per question (Question_Numbers.Time).
  final int secondsPerQuestion;

  const QuizConfig({
    required this.questionCount,
    required this.secondsPerQuestion,
  });
}
