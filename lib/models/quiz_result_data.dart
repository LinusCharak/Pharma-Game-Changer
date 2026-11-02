import 'quiz_category.dart';
import 'user_profile.dart';

/// Everything describing one completed quiz attempt -- built ONCE in
/// QuizScreen the instant the quiz finishes, then used unchanged by the
/// Supabase upload, QuizResultScreen, and (in a later phase) PDF/email.
///
/// This is never recalculated after creation. That's what makes
/// "Retry Upload" safe: it re-sends this exact same object -- same
/// attempt_uuid, same score, same completedAt -- nothing is regenerated.
class QuizResultData {
  final String attemptUuid;

  /// Kept as the real object (not just its label) so QuizResultScreen
  /// can be opened/re-opened ("Retry This Topic") without needing to
  /// reconstruct a QuizCategory from a plain string.
  final QuizCategory category;

  final String username;
  final String userName;
  final String? designation;
  final String? hq;
  final String? zone;

  final String? asmName;
  final String? asmHq;
  final String? asmEmail;

  final String? rsmName;
  final String? rsmHq;
  final String? rsmEmail;

  final int totalQuestions;
  final int correctAnswers;

  /// Same rounded whole-percent value QuizResultScreen displays --
  /// computed once here so the UI and the stored row can never disagree.
  final int percentage;

  final int totalTimeSeconds;
  final DateTime completedAt;
  final String? appVersion;

  const QuizResultData({
    required this.attemptUuid,
    required this.category,
    required this.username,
    required this.userName,
    this.designation,
    this.hq,
    this.zone,
    this.asmName,
    this.asmHq,
    this.asmEmail,
    this.rsmName,
    this.rsmHq,
    this.rsmEmail,
    required this.totalQuestions,
    required this.correctAnswers,
    required this.percentage,
    required this.totalTimeSeconds,
    required this.completedAt,
    this.appVersion,
  });

  /// Builds the result straight from what QuizScreen already computed --
  /// nothing here is a second calculation of the score or duration.
  factory QuizResultData.fromQuiz({
    required String attemptUuid,
    required UserProfile profile,
    required QuizCategory category,
    required int correctAnswers,
    required int totalQuestions,
    required int totalTimeSeconds,
    required DateTime completedAt,
    String? appVersion,
  }) {
    final percentage =
        totalQuestions == 0 ? 0 : ((correctAnswers / totalQuestions) * 100).round();
    return QuizResultData(
      attemptUuid: attemptUuid,
      category: category,
      username: profile.username,
      userName: profile.fullName,
      designation: profile.designation,
      hq: profile.hq,
      zone: profile.zone,
      asmName: profile.asmName,
      asmHq: profile.asmHq,
      asmEmail: profile.asmEmail,
      rsmName: profile.rsmName,
      rsmHq: profile.rsmHq,
      rsmEmail: profile.rsmEmail,
      totalQuestions: totalQuestions,
      correctAnswers: correctAnswers,
      percentage: percentage,
      totalTimeSeconds: totalTimeSeconds,
      completedAt: completedAt,
      appVersion: appVersion,
    );
  }

  /// Maps to exactly the quiz_results columns (see
  /// supabase/quiz_results_schema.sql).
  Map<String, dynamic> toSupabaseRow() {
    return {
      'attempt_uuid': attemptUuid,
      'username': username,
      'user_name': userName,
      'designation': designation,
      'hq': hq,
      'zone': zone,
      'asm_name': asmName,
      'asm_hq': asmHq,
      'asm_email': asmEmail,
      'rsm_name': rsmName,
      'rsm_hq': rsmHq,
      'rsm_email': rsmEmail,
      'product_name': category.label,
      'total_questions': totalQuestions,
      'correct_answers': correctAnswers,
      'score_percent': percentage.toDouble(),
      'total_time_seconds': totalTimeSeconds,
      'completed_at': completedAt.toUtc().toIso8601String(),
      'app_version': appVersion,
    };
  }
}
