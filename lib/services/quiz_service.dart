import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/quiz_category.dart';
import '../models/quiz_config.dart';
import '../models/quiz_question.dart';
import 'quiz_exceptions.dart';

/// The Architecture-A quiz service, talking to the real Supabase tables:
/// quiz_catergories (topic list), Question_Numbers (quiz settings), and
/// one table per topic (e.g. "HYPONIDD-DM") for the actual MCQs.
class QuizService {
  QuizService._();

  static final QuizService instance = QuizService._();

  SupabaseClient get _db => Supabase.instance.client;

  /// Reads quiz_catergories.Categories and wraps each non-empty value as
  /// a QuizCategory (label + matching product image resolved inside
  /// QuizCategory.fromCode itself).
  Future<List<QuizCategory>> fetchCategories() async {
    final rows = await _db.from('quiz_catergories').select('Categories');

    return rows
        .map((r) => r['Categories'] as String?)
        .where((code) => code != null && code.trim().isNotEmpty)
        .map((code) => QuizCategory.fromCode(code!.trim()))
        .toList();
  }

  /// Reads Question_Numbers (Number, Time) -- the live quiz settings.
  /// Never hard-codes a question count or timer; both come from Supabase.
  Future<QuizConfig> fetchQuizConfig() async {
    final rows = await _db.from('Question_Numbers').select('Number, Time');

    if (rows.isEmpty) {
      throw const QuizConfigException(
        'Quiz settings (Question_Numbers) are not configured yet.',
      );
    }

    final row = rows.first;
    final number = int.tryParse('${row['Number'] ?? ''}'.trim());
    final time = int.tryParse('${row['Time'] ?? ''}'.trim());

    if (number == null || number <= 0 || time == null || time <= 0) {
      throw const QuizConfigException(
        'Quiz settings (Question_Numbers.Number / .Time) are invalid.',
      );
    }

    return QuizConfig(questionCount: number, secondsPerQuestion: time);
  }

  /// Reads the per-topic table named exactly [tableCode] (e.g.
  /// "HYPONIDD-DM"), maps each row via QuizQuestion.fromRow, shuffles,
  /// and returns at most [limit] questions (all of them if there are
  /// fewer than [limit]).
  Future<List<QuizQuestion>> fetchQuestions(
    String tableCode, {
    required int limit,
  }) async {
    final List<Map<String, dynamic>> rows;
    try {
      rows = await _db
          .from(tableCode)
          .select('Question, Option1, Option2, Option3, Option4, Answer');
    } catch (e) {
      throw QuizQuestionsException(
        tableCode,
        "Couldn't load questions for \"$tableCode\": $e",
      );
    }

    final questions = rows.map((r) => QuizQuestion.fromRow(r)).toList();

    questions.shuffle();

    if (questions.length <= limit) return questions;
    return questions.sublist(0, limit);
  }
}