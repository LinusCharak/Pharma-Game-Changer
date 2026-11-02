import 'dart:convert';

/// A single reminder entry loaded from Firebase.
///
/// Firebase stores each literature value as a JSON string:
///
/// ["Literature Name", "Tagline", "Image URL"]
///
/// Example:
///
/// ["ADDYZOA-14534",
///  "Some facts of Male infertility.",
///  "https://res.cloudinary.com/linus4763/image/upload/.../A5.jpg"]
class ReminderItem {
  final String tagKey;
  final String title;
  final String description;
  final String imageUrl;

  const ReminderItem({
    required this.tagKey,
    required this.title,
    required this.description,
    required this.imageUrl,
  });

  factory ReminderItem.fromRaw(String tagKey, dynamic raw) {
    dynamic decoded = raw;

    // Firebase stores the complete list as a JSON string.
    if (raw is String) {
      try {
        decoded = jsonDecode(raw);
      } catch (_) {
        decoded = const [];
      }
    }

    List<dynamic> values;

    if (decoded is List) {
      values = decoded;
    } else if (decoded is Map) {
      final entries = decoded.entries.toList()
        ..sort(
          (a, b) => a.key.toString().compareTo(b.key.toString()),
        );

      values = entries.map((e) => e.value).toList();
    } else {
      values = const [];
    }

    String getValue(int index) {
      if (values.length > index && values[index] != null) {
        return values[index].toString();
      }
      return '';
    }

    return ReminderItem(
      tagKey: tagKey,
      title: getValue(0),
      description: getValue(1),
      imageUrl: getValue(2),
    );
  }
}