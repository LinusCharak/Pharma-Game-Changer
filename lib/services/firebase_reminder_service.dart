import 'package:firebase_database/firebase_database.dart';

import '../models/reminder_item.dart';

class FirebaseReminderService {
  FirebaseReminderService({
    String bucket = '',
    FirebaseDatabase? database,
  })  : _bucket = bucket,
        _db = database ?? FirebaseDatabase.instance;

  final String _bucket;
  final FirebaseDatabase _db;

  // Products are stored directly at the Firebase database root.
  DatabaseReference get _root =>
      _bucket.isEmpty ? _db.ref() : _db.ref(_bucket);

  Future<List<String>> getProductList() async {
    final snapshot = await _root.get();

    if (!snapshot.exists || snapshot.value == null) {
      return [];
    }

    final value = snapshot.value;

    if (value is! Map) {
      return [];
    }

    final map = Map<dynamic, dynamic>.from(value);

    final names = map.keys
        .map((key) => key.toString())
        .toList();

    names.sort(
      (a, b) => a.toLowerCase().compareTo(b.toLowerCase()),
    );

    return names;
  }

  Future<List<String>> getTagList(String product) async {
    final snapshot = await _root.child(product).get();

    if (!snapshot.exists || snapshot.value == null) {
      return [];
    }

    final value = snapshot.value;

    if (value is! Map) {
      return [];
    }

    final map = Map<dynamic, dynamic>.from(value);

    final tags = map.keys
        .map((key) => key.toString())
        .toList();

    tags.sort(
      (a, b) => a.toLowerCase().compareTo(b.toLowerCase()),
    );

    return tags;
  }

  Future<ReminderItem?> getValue(
    String product,
    String tag,
  ) async {
    final snapshot = await _root
        .child(product)
        .child(tag)
        .get();

    if (!snapshot.exists || snapshot.value == null) {
      return null;
    }

    return ReminderItem.fromRaw(tag, snapshot.value);
  }

  Future<List<ReminderItem>> getItemsForProduct(
    String product,
  ) async {
    final tags = await getTagList(product);
    final items = <ReminderItem>[];

    for (final tag in tags) {
      final item = await getValue(product, tag);

      if (item != null) {
        items.add(item);
      }
    }

    return items;
  }
}