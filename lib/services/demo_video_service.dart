import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/demo_video.dart';

/// Replaces the old Firebase_Database1 (videodetailing-default-rtdb)
/// reads from Demo_Detailing.
class DemoVideoService {
  SupabaseClient get _db => Supabase.instance.client;

  Future<List<DemoVideo>> fetchVideos() async {
    final rows = await _db
        .from('demo_videos')
        .select()
        .eq('is_active', true)
        .order('sort_order');

    return rows.map((r) => DemoVideo.fromMap(r)).toList();
  }
}
