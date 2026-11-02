/// Fill these in from Supabase → Project Settings → API Keys on your project.
/// The publishable key (or the older "anon public" key on pre-2026 projects)
/// is safe to ship inside a client app — it's designed to be public. Row
/// Level Security policies on your tables are what actually control who can
/// read/write, so make sure:
///   - `quiz_catergories` and every per-topic question table (e.g.
///     "HYPONIDD-DM") have RLS enabled with a public SELECT policy
///     (read-only), and no INSERT/UPDATE/DELETE policy for anon.
class SupabaseConfig {
  static const String url = 'https://pjefycpryziesbnwftqo.supabase.co';

  /// Settings → API Keys → "Publishable and secret API keys" tab → the key
  /// starting with sb_publishable_...  (On an older project that only shows
  /// "Project API keys", use the "anon public" key instead — same slot.)
  static const String publishableKey = 'sb_publishable_bIyjK3mWjiCbCrzOASiFaQ_WTh_q71z';

  /// The categories table + column, exactly as they exist in Supabase today
  /// (kept as "quiz_catergories" / "Categories" to match your live schema).
  static const String categoriesTable = 'quiz_catergories';
  static const String categoriesColumn = 'Categories';

  /// Controls how many questions each quiz uses and how many seconds are
  /// allowed per question. A single row in Question_Numbers (Number, Time) —
  /// change either value in Supabase and the next quiz picks it up
  /// automatically, no app rebuild needed.
  static const String questionNumbersTable = 'Question_Numbers';
  static const String questionCountColumn = 'Number';
  static const String questionTimeColumn = 'Time';

  static bool get isConfigured =>
      !url.contains('YOUR-PROJECT-REF') && !publishableKey.contains('YOUR-PUBLISHABLE-OR-ANON-KEY');
}
