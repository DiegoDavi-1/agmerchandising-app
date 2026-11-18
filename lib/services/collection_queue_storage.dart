import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

class CollectionQueueStorage {
  static const _queueKey = 'pending_collections';
  static Future<void> _mutation = Future.value();

  static Future<void> _serialize(Future<void> Function() action) async {
    final previous = _mutation;
    final finished = Completer<void>();
    _mutation = finished.future;
    await previous;
    try {
      await action();
    } finally {
      finished.complete();
    }
  }

  static Future<List<Map<String, dynamic>>> getAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_queueKey);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  static Future<void> saveAll(List<Map<String, dynamic>> items) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = await prefs.setString(_queueKey, jsonEncode(items));
    if (!saved) {
      throw StateError('Nao foi possivel salvar a fila de atendimentos.');
    }
  }

  static Future<void> enqueue(Map<String, dynamic> item) =>
      _serialize(() async {
        final items = await getAll();
        final id = item['client_submission_id'];
        if (id != null &&
            items.any((existing) =>
                existing['client_submission_id'] == id &&
                existing['_queue_user_id'] == item['_queue_user_id'])) {
          return;
        }
        items.add(item);
        await saveAll(items);
      });

  static Future<void> removeFirstN(int count) => _serialize(() async {
        final items = await getAll();
        if (items.isEmpty) return;
        final remaining = items.length <= count
            ? <Map<String, dynamic>>[]
            : items.sublist(count);
        await saveAll(remaining);
      });

  static Future<int> count() async {
    final items = await getAll();
    return items.length;
  }
}
