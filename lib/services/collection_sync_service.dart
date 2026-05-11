import 'dart:async';
import '../core/network/connectivity_service.dart';
import '../services/api_service.dart';
import '../services/collection_queue_storage.dart';
import '../core/logging/app_logger_v2.dart';

class CollectionSyncService {
  static final CollectionSyncService _instance = CollectionSyncService._internal();
  factory CollectionSyncService() => _instance;
  CollectionSyncService._internal();

  StreamSubscription? _subscription;
  bool _isSyncing = false;

  void initialize() {
    _subscription ??= ConnectivityService().onConnectivityChanged.listen((status) {
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

      const batchSize = 10;
      int sent = 0;

      for (var i = 0; i < pending.length; i += batchSize) {
        final batch = pending.skip(i).take(batchSize).toList();
        final normalized = await Future.wait(
          batch.map((item) => ApiService.normalizeCollectionItem(item)),
        );

        final result = await ApiService.saveCollectionsBatch(normalized);

        if (result['success'] == true) {
          sent += batch.length;
        } else {
          break;
        }
      }

      if (sent > 0) {
        await CollectionQueueStorage.removeFirstN(sent);
        appLogger.info('Coletas sincronizadas', data: {'count': sent});
      }
    } catch (e) {
      appLogger.error('Erro ao sincronizar coletas', error: e);
    } finally {
      _isSyncing = false;
    }
  }
}
