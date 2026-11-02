/// One entry from the demo_videos table (migrated from the old
/// "videodetailing-default-rtdb" Firebase project -- see
/// supabase/demo_videos_schema.sql).
class DemoVideo {
  final int id;
  final String title;
  final String thumbnailUrl;
  final String videoUrl;

  const DemoVideo({
    required this.id,
    required this.title,
    required this.thumbnailUrl,
    required this.videoUrl,
  });

  factory DemoVideo.fromMap(Map<String, dynamic> map) {
    return DemoVideo(
      id: (map['id'] as num).toInt(),
      title: map['title'] as String,
      thumbnailUrl: map['thumbnail_url'] as String,
      videoUrl: map['video_url'] as String,
    );
  }
}