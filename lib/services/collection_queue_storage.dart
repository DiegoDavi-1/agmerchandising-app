import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class CollectionQueueStorage {
  static const _queueKey = 'pending_collections';

  static Future<List<Map<String, dynamic>>> getAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_queueKey);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  static Future<void> saveAll(List<Map<String, dynamic>> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_queueKey, jsonEncode(items));
  }

  static Future<void> enqueue(Map<String, dynamic> item) async {
    final items = await getAll();
    items.add(item);
    await saveAll(items);
  }

  static Future<void> removeFirstN(int count) async {
    final items = await getAll();
    if (items.isEmpty) return;
    final remaining = items.length <= count ? <Map<String, dynamic>>[] : items.sublist(count);
    await saveAll(remaining);
  }

  static Future<int> count() async {
    final items = await getAll();
    return items.length;
  }
}
