import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/quiz_result_data.dart';

/// Saves exactly one row per completed quiz to quiz_results -- no
/// question-by-question data is ever stored. Separate from QuizService
/// deliberately: QuizService reads quiz content (categories/questions/
/// config); this writes the final result, a distinct concern.
///
/// Uploads are idempotent on attempt_uuid via Supabase's upsert, so a
/// retry after a lost success response (result saved server-side, but
/// the client never saw the confirmation) can never create a duplicate
/// row -- it just re-confirms the same one.
class QuizResultService {
  QuizResultService._();

  static final QuizResultService instance = QuizResultService._();

  SupabaseClient get _db => Supabase.instance.client;

  /// Standard UUID v4, generated locally with a cryptographically
  /// secure random source -- no extra package needed for just this.
  String generateAttemptUuid() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0F) | 0x40; // version 4
    bytes[8] = (bytes[8] & 0x3F) | 0x80; // variant 10
    String hex(int start, int end) => bytes
        .sublist(start, end)
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex(0, 4)}-${hex(4, 6)}-${hex(6, 8)}-${hex(8, 10)}-${hex(10, 16)}';
  }

  /// Upserts on attempt_uuid -- safe to call more than once with the
  /// same [result] (e.g. Retry Upload) without ever creating a second
  /// row for the same attempt.
  Future<void> uploadQuizResult(QuizResultData result) async {
    try {
      await _db
          .from('quiz_results')
          .upsert(result.toSupabaseRow(), onConflict: 'attempt_uuid');
    } catch (e) {
      debugPrint('Quiz result upload failed: $e');
      rethrow;
    }
  }
}
