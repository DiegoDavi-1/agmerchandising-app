import 'dart:async';

import 'package:flutter/material.dart';

import '../core/logging/app_logger_v2.dart';
import '../pages/dynamic_brand_collection_page.dart';
import '../services/photo_outbox.dart';
import '../services/api_service.dart';
import '../core/network/connectivity_service.dart';
import '../services/collection_sync_service.dart';

class AttendanceRecoveryGate extends StatefulWidget {
  const AttendanceRecoveryGate({super.key, required this.child});
  final Widget child;

  @override
  State<AttendanceRecoveryGate> createState() => _AttendanceRecoveryGateState();
}

class _AttendanceRecoveryGateState extends State<AttendanceRecoveryGate>
    with WidgetsBindingObserver {
  bool _loading = PhotoOutbox.isSupported;
  String? _error;
  StreamSubscription<ConnectivityStatus>? _connectivity;

  @override
  void initState() {
    super.initState();
    if (PhotoOutbox.isSupported) {
      WidgetsBinding.instance.addObserver(this);
      _recover();
      CollectionSyncService().initialize();
      _connectivity =
          ConnectivityService().onConnectivityChanged.listen((status) {
        if (status == ConnectivityStatus.online) {
          unawaited(ApiService.synchronizeClock());
        }
      });
    }
  }

  Future<void> _recover() async {
    try {
      final outbox = PhotoOutbox.instance;
      await outbox.recoverLostData();
      final route = await outbox.activeAttendance();
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = null;
      });
      outbox.start();
      if (route != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final storeId = route['store_id'] as int;
          Navigator.of(context).push(MaterialPageRoute<bool>(
            builder: (_) => DynamicBrandCollectionPage(
              brandId: route['brand_id'] as int,
              brandName: route['brand_name'] as String,
              storeId: storeId == 0 ? null : storeId,
            ),
          ));
        });
      }
    } catch (error, stack) {
      appLogger.error('Falha ao recuperar atendimento',
          error: error, stackTrace: stack);
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Nao foi possivel recuperar a foto pendente: $error';
        });
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(ApiService.synchronizeClock());
      PhotoOutbox.instance.start();
    } else {
      PhotoOutbox.instance.pause();
    }
  }

  @override
  void dispose() {
    unawaited(_connectivity?.cancel());
    if (PhotoOutbox.isSupported) {
      WidgetsBinding.instance.removeObserver(this);
      PhotoOutbox.instance.pause();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Column(children: [
      if (_error != null)
        MaterialBanner(
          content: Text(_error!),
          actions: [
            TextButton(
                onPressed: _recover, child: const Text('Tentar recuperar')),
          ],
        ),
      Expanded(child: widget.child),
    ]);
  }
}
