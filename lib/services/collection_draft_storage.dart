import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Rascunho do atendimento em andamento. Se o Android fechar o app enquanto a
/// câmera está aberta (comum em celular com pouca memória), o promotor reabre a
/// loja e continua de onde parou: as fotos já foram enviadas ao servidor, aqui
/// ficam só as URLs e os textos. Vale apenas para o mesmo dia.
class CollectionDraftStorage {
  CollectionDraftStorage._();

  static const _prefix = 'collection_draft_v1';

  static String key(Object? userId, int brandId, int? storeId) =>
      '$_prefix:${userId ?? 0}:$brandId:${storeId ?? 0}';

  static String today([DateTime? now]) {
    final d = now ?? DateTime.now();
    return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  static Future<Map<String, dynamic>?> load(String key, {DateTime? now}) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      if (decoded['day'] != today(now) || decoded['data'] is! Map) {
        await prefs.remove(key);
        return null;
      }
      return Map<String, dynamic>.from(decoded['data'] as Map);
    } catch (_) {
      await prefs.remove(key);
      return null;
    }
  }

  static Future<void> save(String key, Map<String, dynamic> data, {DateTime? now}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, jsonEncode({'day': today(now), 'data': data}));
    } catch (_) {}
  }

  static Future<void> clear(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }
}
