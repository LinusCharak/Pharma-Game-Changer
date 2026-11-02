/// Thrown when Question_Numbers can't be read or doesn't contain usable
/// values. Kept distinct from [QuizQuestionsException] so the UI can show
/// "quiz configuration failed to load" rather than a generic error.
class QuizConfigException implements Exception {
  final String message;
  const QuizConfigException(this.message);

  @override
  String toString() => message;
}

/// Thrown when a topic's question table can't be read. Carries the table
/// name so the UI can name the specific topic that failed.
class QuizQuestionsException implements Exception {
  final String tableName;
  final String message;
  const QuizQuestionsException(this.tableName, this.message);

  @override
  String toString() => message;
}
