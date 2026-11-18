import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class CollectionDraftState {
  const CollectionDraftState({
    required this.data,
    this.submissionId,
    this.submissionRequest,
    this.submissionResult,
  });

  final Map<String, dynamic> data;
  final String? submissionId;
  final Map<String, dynamic>? submissionRequest;
  final Map<String, dynamic>? submissionResult;
}

/// Rascunho do atendimento em andamento. Se o Android fechar o app enquanto a
/// câmera está aberta (comum em celular com pouca memória), o promotor reabre a
/// loja e continua de onde parou, inclusive offline e depois de mudar a data.
class CollectionDraftStorage {
  CollectionDraftStorage._();

  static const _prefix = 'collection_draft_v1';
  static Future<void>? _mutation;

  static Future<void> _serialize(Future<void> Function() action) async {
    final previous = _mutation;
    final finished = Completer<void>();
    _mutation = finished.future;
    if (previous != null) await previous;
    try {
      await action();
    } finally {
      finished.complete();
      if (identical(_mutation, finished.future)) _mutation = null;
    }
  }

  static String key(Object? userId, int brandId, int? storeId) =>
      '$_prefix:${userId ?? 0}:$brandId:${storeId ?? 0}';

  static String today([DateTime? now]) {
    final d = now ?? DateTime.now();
    return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  static Future<Map<String, dynamic>?> load(String key, {DateTime? now}) async {
    return (await loadSession(key))?.data;
  }

  static Future<CollectionDraftState?> loadSession(String key) async {
    final pending = _mutation;
    if (pending != null) await pending;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null) return null;
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic> ||
        decoded['data'] is! Map<String, dynamic>) {
      throw const FormatException(
          'Rascunho invalido. Os dados foram preservados para recuperacao.');
    }
    return CollectionDraftState(
      data: Map<String, dynamic>.from(decoded['data'] as Map),
      submissionId: decoded['submission_id'] as String?,
      submissionRequest: decoded['submission_request'] == null
          ? null
          : Map<String, dynamic>.from(decoded['submission_request'] as Map),
      submissionResult: decoded['submission_result'] == null
          ? null
          : Map<String, dynamic>.from(decoded['submission_result'] as Map),
    );
  }

  static Future<void> save(String key, Map<String, dynamic> data,
          {DateTime? now,
          String? submissionId,
          Map<String, dynamic>? submissionRequest,
          Map<String, dynamic>? submissionResult}) =>
      _serialize(() async {
        final prefs = await SharedPreferences.getInstance();
        final written = await prefs.setString(
            key,
            jsonEncode({
              'day': today(now),
              'data': data,
              if (submissionId != null) 'submission_id': submissionId,
              if (submissionRequest != null)
                'submission_request': submissionRequest,
              if (submissionResult != null)
                'submission_result': submissionResult,
            }));
        if (!written) throw StateError('Nao foi possivel gravar o rascunho.');
      });

  static Future<void> clear(String key) => _serialize(() async {
        final prefs = await SharedPreferences.getInstance();
        if (!await prefs.remove(key)) {
          throw StateError('Nao foi possivel limpar o rascunho concluido.');
        }
      });
}
