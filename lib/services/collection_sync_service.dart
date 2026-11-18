import 'dart:async';
import '../core/network/connectivity_service.dart';
import '../services/api_service.dart';
import '../services/collection_queue_storage.dart';
import '../core/logging/app_logger_v2.dart';
import 'photo_outbox.dart';

class CollectionSyncService {
  static final CollectionSyncService _instance =
      CollectionSyncService._internal();
  factory CollectionSyncService() => _instance;
  CollectionSyncService._internal();

  StreamSubscription? _subscription;
  bool _isSyncing = false;

  void initialize() {
    _subscription ??=
        ConnectivityService().onConnectivityChanged.listen((status) {
      if (status == ConnectivityStatus.online) {
        syncPendingCollections(wifiOnly: true);
      }
    });

    // Tenta sincronizar no início
    syncPendingCollections(wifiOnly: true);
  }

  Future<void> syncPendingCollections({bool wifiOnly = true}) async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      if (wifiOnly) {
        final isWifi = await ConnectivityService().isWifi();
        if (!isWifi) {
          _isSyncing = false;
          return;
        }
      } else {
        final isOnline = await ConnectivityService().isOnline();
        if (!isOnline) {
          _isSyncing = false;
          return;
        }
      }

      final pending = await CollectionQueueStorage.getAll();
      if (pending.isEmpty) {
        _isSyncing = false;
        return;
      }
      final user = await ApiService.getUserData();
      final userId = int.tryParse('${user?['id']}');
      if (userId == null) return;

      const batchSize = 10;
      for (var i = 0; i < pending.length; i += batchSize) {
        final batch = pending.skip(i).take(batchSize).toList();
        if (batch.any(
            (item) => int.tryParse('${item['_queue_user_id']}') != userId)) {
          throw StateError(
              'A fila contem atendimento sem conta confirmada ou de outra conta. Nenhum item desse lote foi enviado.');
        }
        final normalized = await Future.wait(
          batch.map((item) => ApiService.normalizeCollectionItem(item)),
        );

        final result = await ApiService.saveCollectionsBatch(normalized);

        if (result['success'] == true && result['inserted'] == batch.length) {
          await CollectionQueueStorage.removeFirstN(batch.length);
          for (final item in batch) {
            final ids = item['_photo_job_ids'];
            if (ids is List) {
              await PhotoOutbox.instance
                  .completeSubmitted(List<String>.from(ids));
            }
          }
          appLogger
              .info('Coletas sincronizadas', data: {'count': batch.length});
        } else {
          throw StateError(
              'O servidor nao confirmou o lote completo de atendimentos.');
        }
      }
    } catch (e) {
      appLogger.error('Erro ao sincronizar coletas', error: e);
    } finally {
      _isSyncing = false;
    }
  }
}
